#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#include <linux/ip.h>
#include <linux/inet.h>
#include <linux/tcp.h>       // Thư viện xử lý TCP header
#include <linux/udp.h>       // Thư viện xử lý UDP header
#include <linux/icmp.h>      // Thư viện xử lý ICMP header
#include <linux/list.h>      // Thư viện xử lý Danh sách liên kết của Kernel
#include <linux/slab.h>      // Thư viện cấp phát bộ nhớ động (kmalloc, kfree)
#include <linux/rwlock.h>    // Thư viện Khóa Đọc - Ghi (chống sập hệ thống)

// ------------------------------------------------------------------
// THÔNG TIN MODULE
// ------------------------------------------------------------------
MODULE_AUTHOR("Pham Viet Hung");
MODULE_DESCRIPTION("Netfilter Firewall - Ho tro Add/Del IP voi rwlock");
MODULE_LICENSE("GPL");

#define PROC_FILENAME "firewall_rules"

// Các biến toàn cục của hệ thống Tường lửa
static struct proc_dir_entry *proc_entry;  // Giao diện /proc để User-space gửi lệnh
static struct nf_hook_ops nfho;            // Cấu trúc chứa thông tin điểm neo (Hook)

// ------------------------------------------------------------------
// CẤU TRÚC DỮ LIỆU: DANH SÁCH LIÊN KẾT VÒNG KÉP
// ------------------------------------------------------------------
struct firewall_rule {
    __be32 ip_address;         // Địa chỉ IP dạng số nguyên (0 = Áp dụng cho mọi IP)
    u8 protocol;               // Giao thức (IPPROTO_TCP, IPPROTO_UDP, IPPROTO_ICMP, 0 = Tất cả)
    u16 port;                  // Cổng đích (0 = Tất cả các cổng)
    struct list_head list;     // Con trỏ tiêu chuẩn của Linux để móc nối các toa tàu
};

// Khởi tạo điểm neo ban đầu (Đầu kéo của đoàn tàu)
LIST_HEAD(rule_list);

// Bơm ổ khóa Đọc-Ghi vào hệ thống để bảo vệ rule_list
DEFINE_RWLOCK(rule_lock);

// ------------------------------------------------------------------
// 1. NGƯỜI ĐỌC: HÀM HOOK (LƯỚI LỌC GÓI TIN ĐI QUA CARD MẠNG)
// ------------------------------------------------------------------
static unsigned int hook_func(void *priv, struct sk_buff *skb, const struct nf_hook_state *state) {
    struct iphdr *iph;
    struct firewall_rule *rule;
    struct tcphdr *tcph;
    struct udphdr *udph;
    u16 dest_port = 0;

    // Kẻ gian có thể gửi gói tin rỗng, phải kiểm tra an toàn
    if (!skb) return NF_ACCEPT;
    iph = ip_hdr(skb);
    if (!iph) return NF_ACCEPT;

    // BẬT KHÓA ĐỌC: Cho phép hàng vạn gói tin cùng vào soi danh sách một lúc.
    // Ngăn chặn lệnh Thêm/Xóa làm thay đổi danh sách trong lúc đang đọc.
    read_lock(&rule_lock); 
    
    // Lặp qua từng toa tàu (rule) trong đoàn tàu (rule_list)
    list_for_each_entry(rule, &rule_list, list) {
        bool match_ip = (rule->ip_address == 0) || (iph->saddr == rule->ip_address);
        bool match_proto = (rule->protocol == 0) || (iph->protocol == rule->protocol);
        bool match_port = (rule->port == 0);

        if (match_ip && match_proto) {
            // Nếu luật yêu cầu kiểm tra port (rule->port != 0), bóc lớp vỏ Transport
            if (!match_port) {
                if (iph->protocol == IPPROTO_TCP) {
                    // Trích xuất TCP Header thủ công an toàn hơn dùng tcp_hdr() ở PRE_ROUTING
                    tcph = (struct tcphdr *)((__u8 *)iph + (iph->ihl * 4));
                    dest_port = ntohs(tcph->dest);
                    if (dest_port == rule->port) match_port = true;
                } else if (iph->protocol == IPPROTO_UDP) {
                    // Trích xuất UDP Header tương tự
                    udph = (struct udphdr *)((__u8 *)iph + (iph->ihl * 4));
                    dest_port = ntohs(udph->dest);
                    if (dest_port == rule->port) match_port = true;
                }
            }

            if (match_port) {
                // TÌM THẤY GÓI TIN VI PHẠM LUẬT:
                // Bắt buộc phải MỞ KHÓA trước khi return để tránh treo máy (Deadlock)
                read_unlock(&rule_lock); 
                
                printk(KERN_INFO "Firewall_Hung: DROP goi tin tu IP %pI4 (Proto: %d, Port: %d)\n", &iph->saddr, iph->protocol, dest_port);
                return NF_DROP; // Bóp nghẹt gói tin
            }
        }
    }
    
    // Không tìm thấy IP trong sổ đen, mở khóa và cho gói tin đi qua
    read_unlock(&rule_lock); 
    return NF_ACCEPT;
}

// ------------------------------------------------------------------
// 2. NGƯỜI ĐỌC: ỨNG DỤNG XEM DANH SÁCH IP (/proc/firewall_rules)
// ------------------------------------------------------------------
static ssize_t my_proc_read(struct file *file, char __user *ubuf, size_t count, loff_t *ppos) {
    char buf[1024] = "Danh sach IP dang bi chan:\n";
    char temp[32];
    int len;
    struct firewall_rule *rule;

    if (*ppos > 0) return 0; // Đã trả về xong dữ liệu cho User-space

    // BẬT KHÓA ĐỌC để quét danh sách in ra màn hình
    read_lock(&rule_lock);
    list_for_each_entry(rule, &rule_list, list) {
        // Biến IP từ số nguyên thành chuỗi (vd: "10.0.2.2") và nối vào temp
        if (rule->protocol == 0) {
            snprintf(temp, sizeof(temp), "- %pI4 [ALL]\n", &rule->ip_address);
        } else if (rule->protocol == IPPROTO_ICMP) {
            snprintf(temp, sizeof(temp), "- %pI4 [ICMP]\n", &rule->ip_address);
        } else if (rule->protocol == IPPROTO_TCP) {
            snprintf(temp, sizeof(temp), "- %pI4 [TCP:%d]\n", &rule->ip_address, rule->port);
        } else if (rule->protocol == IPPROTO_UDP) {
            snprintf(temp, sizeof(temp), "- %pI4 [UDP:%d]\n", &rule->ip_address, rule->port);
        } else {
            snprintf(temp, sizeof(temp), "- %pI4 [PROTO:%d]\n", &rule->ip_address, rule->protocol);
        }
        
        if (strlen(buf) + strlen(temp) < sizeof(buf)) {
            strcat(buf, temp);
        }
    }
    // MỞ KHÓA NGAY LẬP TỨC TRƯỚC KHI GỌI copy_to_user
    // Lý do: copy_to_user có thể bắt CPU "ngủ" (Sleep), mà đã cầm khóa thì cấm ngủ.
    read_unlock(&rule_lock); 

    len = strlen(buf);
    // Gửi chuỗi danh sách từ Kernel-space ra User-space
    if (copy_to_user(ubuf, buf, len)) return -EFAULT;
    
    *ppos = len;
    return len;
}

// ------------------------------------------------------------------
// 3. NGƯỜI GHI: XỬ LÝ LỆNH THÊM VÀ XÓA IP (TỪ ỨNG DỤNG C)
// ------------------------------------------------------------------
static ssize_t my_proc_write(struct file *file, const char __user *ubuf, size_t count, loff_t *ppos) {
    char buf[64];      // Bộ đệm chứa lệnh (VD: "add tcp 10.0.2.2 80")
    char action[4];    // "add" hoặc "del"
    char proto_str[8]; // "all", "icmp", "tcp", "udp"
    char ip_str[16];   // "10.0.2.2"
    int port_num = 0;
    __be32 target_ip = 0;
    u8 target_proto = 0;
    u16 target_port = 0;
    struct firewall_rule *new_rule;
    struct firewall_rule *rule, *tmp;
    bool found = false;

    // Giới hạn độ dài chống tràn bộ đệm (Buffer Overflow)
    if (count > sizeof(buf) - 1) count = sizeof(buf) - 1;
    if (copy_from_user(buf, ubuf, count)) return -EFAULT;
    buf[count] = '\0';

    // Cắt chuỗi gửi vào thành 4 phần: action, proto_str, ip_str, port_num
    if (sscanf(buf, "%3s %7s %15s %d", action, proto_str, ip_str, &port_num) < 3) {
        printk(KERN_WARNING "Firewall_Hung: Sai cu phap! Dung: add|del all|icmp|tcp|udp <IP> [PORT]\n");
        return -EINVAL;
    }

    // Chuyển đổi IP dạng chuỗi sang mã nhị phân
    if (strcmp(ip_str, "any") == 0 || strcmp(ip_str, "0.0.0.0") == 0) {
        target_ip = 0; // Áp dụng cho mọi IP
    } else {
        in4_pton(ip_str, -1, (u8 *)&target_ip, -1, NULL);
    }

    // Xác định Giao thức
    if (strcmp(proto_str, "icmp") == 0) target_proto = IPPROTO_ICMP;
    else if (strcmp(proto_str, "tcp") == 0) target_proto = IPPROTO_TCP;
    else if (strcmp(proto_str, "udp") == 0) target_proto = IPPROTO_UDP;
    else target_proto = 0; // "all"

    target_port = (u16)port_num;

    // ==========================================
    // NHÁNH 1: XỬ LÝ LỆNH "ADD" (THÊM LUẬT)
    // ==========================================
    if (strcmp(action, "add") == 0) {
        // Xin hệ điều hành cấp RAM cho toa tàu mới (Làm TRƯỚC khi khóa)
        new_rule = kmalloc(sizeof(*new_rule), GFP_KERNEL);
        if (!new_rule) return -ENOMEM;
        new_rule->ip_address = target_ip;
        new_rule->protocol = target_proto;
        new_rule->port = target_port;

        // BẬT KHÓA GHI: Chặn đứng tất cả gói tin để tiến hành gắn nối bộ nhớ
        write_lock(&rule_lock);
        list_add_tail(&new_rule->list, &rule_list); // Móc toa tàu vào cuối danh sách
        write_unlock(&rule_lock); // GẮN XONG MỞ KHÓA NGAY

        printk(KERN_INFO "Firewall_Hung: Da them IP %pI4 (Proto: %d, Port: %d)\n", &target_ip, target_proto, target_port);
    } 
    // ==========================================
    // NHÁNH 2: XỬ LÝ LỆNH "DEL" (XÓA LUẬT)
    // ==========================================
    else if (strcmp(action, "del") == 0) {
        // BẬT KHÓA GHI: Chặn mọi thao tác đọc/ghi khác để gỡ toa tàu
        write_lock(&rule_lock); 
        
        // HÀM LẶP AN TOÀN (SAFE): Dùng con trỏ 'tmp' giữ sẵn toa phía sau. 
        list_for_each_entry_safe(rule, tmp, &rule_list, list) {
            // So sánh tất cả các trường để xóa đúng luật
            if (rule->ip_address == target_ip && rule->protocol == target_proto && rule->port == target_port) {
                list_del(&rule->list); // Gỡ khớp nối khỏi danh sách
                kfree(rule);           // Đốt cháy toa tàu, trả lại RAM cho Kernel
                found = true;
                break;                 // Đã xóa xong thì thoát vòng lặp cho nhanh
            }
        }
        write_unlock(&rule_lock); // XÓA XONG MỞ KHÓA NGAY

        // Báo cáo kết quả ra màn hình Kernel
        if (found) {
            printk(KERN_INFO "Firewall_Hung: Da xoa IP %pI4 (Proto: %d, Port: %d)\n", &target_ip, target_proto, target_port);
        } else {
            printk(KERN_INFO "Firewall_Hung: Khong tim thay IP %pI4 (Proto: %d, Port: %d)\n", &target_ip, target_proto, target_port);
        }
    }

    return count;
}

// Đăng ký các hàm Đọc/Ghi với hệ thống file ảo /proc
static const struct proc_ops proc_fops = {
    .proc_read = my_proc_read,
    .proc_write = my_proc_write,
};

// ------------------------------------------------------------------
// KHỞI TẠO VÀ DỌN DẸP MODULE
// ------------------------------------------------------------------
static int __init firewall_init(void) {
    // 1. Tạo file giao tiếp /proc/firewall_rules
    proc_entry = proc_create(PROC_FILENAME, 0666, NULL, &proc_fops);
    if (!proc_entry) {
        printk(KERN_ERR "Firewall_Hung: Khong the tao file /proc.\n");
        return -ENOMEM;
    }

    // 2. Thiết lập điểm gác cửa mạng (Hook)
    nfho.hook = hook_func;                  // Tên hàm xử lý
    nfho.hooknum = NF_INET_PRE_ROUTING;     // Vị trí gác: Ngay cổng vào (Chưa định tuyến)
    nfho.pf = PF_INET;                      // Giao thức: IPv4
    nfho.priority = NF_IP_PRI_FIRST;        // Độ ưu tiên: Cáo nhất (Chạy trước mọi Tường lửa khác)
    
    // Đăng ký Hook vào hệ thống (API cho Kernel >= 5.13 có chữ 's' và tham số đếm là 1)
    nf_register_net_hooks(&init_net, &nfho, 1); 
    
    printk(KERN_INFO "Firewall_Hung: He thong Tường lửa (co rwlock) da bat!\n");
    return 0;
}

static void __exit firewall_exit(void) {
    struct firewall_rule *rule, *tmp;

    // 1. Gỡ Hook khỏi cửa ngõ mạng
    nf_unregister_net_hooks(&init_net, &nfho, 1);
    
    // 2. Xóa file giao tiếp /proc
    proc_remove(proc_entry);

    // 3. Dọn dẹp Rác (Memory Leak)
    // BẮT BUỘC phải Bật khóa ghi để tiêu hủy toàn bộ danh sách trước khi sập nguồn
    write_lock(&rule_lock);
    list_for_each_entry_safe(rule, tmp, &rule_list, list) {
        list_del(&rule->list); 
        kfree(rule);           
    }
    write_unlock(&rule_lock);
    
    printk(KERN_INFO "Firewall_Hung: Da tat Tường lửa va don dep RAM an toan.\n");
}

// Báo cho Kernel biết đâu là hàm Khởi tạo và hàm Kết thúc
module_init(firewall_init);
module_exit(firewall_exit);
