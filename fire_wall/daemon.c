#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PROC_PATH "/proc/firewall_rules"

void print_usage(const char *prog_name) {
    printf("Cach su dung phan mem Tuong Lua:\n");
    printf("  %s list                        : Xem danh sach dang bi chan\n", prog_name);
    printf("  %s add|del all <IP>            : Them/Xoa chan toan bo voi IP\n", prog_name);
    printf("  %s add|del icmp <IP>           : Them/Xoa chan ping (ICMP) voi IP\n", prog_name);
    printf("  %s add|del tcp <IP> <PORT>     : Them/Xoa chan TCP port voi IP\n", prog_name);
    printf("  %s add|del udp <IP> <PORT>     : Them/Xoa chan UDP port voi IP\n", prog_name);
    printf("  * Luu y: <IP> co co the la 'any' hoac '0.0.0.0' de ap dung cho moi IP.\n");
}

int main(int argc, char *argv[]) {
    FILE *fp;
    char buffer[1024];
    char action[4];
    char proto[8];
    char ip[16];
    char port[8] = "0"; // Mặc định là 0 (Tất cả cổng) nếu không nhập port

    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    // LỆNH XEM DANH SÁCH (Đọc file /proc)
    if (strcmp(argv[1], "list") == 0) {
        fp = fopen(PROC_PATH, "r");
        if (!fp) {
            perror("Loi: Tuong lua chua duoc bat (Chua nap module)");
            return 1;
        }
        while (fgets(buffer, sizeof(buffer), fp) != NULL) {
            printf("%s", buffer);
        }
        fclose(fp);
        return 0;
    }

    // LỆNH THÊM HOẶC XÓA (Ghi vào file /proc)
    if (strcmp(argv[1], "add") == 0 || strcmp(argv[1], "del") == 0) {
        if (argc < 4) {
            printf("Loi: Thieu tham so (Giao thuc hoac IP).\n");
            print_usage(argv[0]);
            return 1;
        }
        
        strncpy(action, argv[1], sizeof(action) - 1);
        strncpy(proto, argv[2], sizeof(proto) - 1);
        strncpy(ip, argv[3], sizeof(ip) - 1);
        action[sizeof(action) - 1] = '\0';
        proto[sizeof(proto) - 1] = '\0';
        ip[sizeof(ip) - 1] = '\0';

        // Lấy port nếu có truyền vào
        if (argc >= 5) {
            strncpy(port, argv[4], sizeof(port) - 1);
            port[sizeof(port) - 1] = '\0';
        }

        fp = fopen(PROC_PATH, "w");
        if (!fp) {
            perror("Loi: Tuong lua chua duoc bat (Khong mo duoc /proc/firewall_rules)");
            return 1;
        }
        
        // Gộp hành động, giao thức, IP và cổng thành 1 chuỗi: "add tcp 10.0.2.2 80"
        snprintf(buffer, sizeof(buffer), "%s %s %s %s\n", action, proto, ip, port);
        fprintf(fp, "%s", buffer);
        fclose(fp);
        
        printf("Thuc thi lenh '%s %s %s %s' thanh cong.\n", action, proto, ip, port);
        return 0;
    }

    print_usage(argv[0]);
    return 1;
}
