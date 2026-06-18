#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>      // Thư viện hệ thống POSIX (close)
#include <arpa/inet.h>   // Thư viện xử lý Socket
#include <pthread.h>     // Thư viện Đa luồng (Multithreading)
#include <stdint.h>      // Hỗ trợ kiểu dữ liệu uint64_t

#define PORT 8888
#define BUFFER_SIZE 1024

// Biến toàn cục để cả luồng chính (main) và luồng phụ (receive) đều truy cập được
char save_directory[256]; 

// Cấu trúc gói tin Header (báo trước tên file và dung lượng)
typedef struct {
    char filename[256];
    uint64_t filesize;
} FileHeader;

/* ==============================================================================
 * LUỒNG PHỤ: CHUYÊN MÔN NGỒI CHỜ VÀ HỨNG FILE
 * ============================================================================== */
void* receive_file_thread(void* socket_ptr) {
    int sock = *(int*)socket_ptr;
    FileHeader header;
    char buffer[BUFFER_SIZE];

    while(1) {
        // 1. Nhận gói Header (Dùng MSG_WAITALL để ép Hệ điều hành đợi đủ 264 byte)
        int valread = recv(sock, &header, sizeof(FileHeader), MSG_WAITALL);
        if (valread <= 0) {
            printf("\n[HỆ THỐNG] Client đã ngắt kết nối mạng.\n");
            exit(0); // Tắt chương trình nếu đối tác mất mạng
        }

        // 2. Ghép thư mục tải xuống với tên file để tạo đường dẫn đầy đủ
        // Ví dụ: "/home/hung/Downloads/" + "anh.png" => "/home/hung/Downloads/anh.png"
        char full_save_path[512];
        snprintf(full_save_path, sizeof(full_save_path), "%s%s", save_directory, header.filename);

        printf("\n\n[ĐANG NHẬN] Có file gửi tới: %s (%lu bytes).\n", header.filename, header.filesize);
        printf("-> Đang lưu tại: %s\n", full_save_path);

        // 3. Mở file để ghi (Chế độ "wb" - Write Binary)
        FILE *write_file = fopen(full_save_path, "wb");
        if (write_file == NULL) {
            perror("\n[LỖI] Không thể tạo file (Có thể sai thư mục tải xuống)");
            // Kỹ thuật nâng cao: Kể cả khi không lưu được file, VẪN PHẢI HÚT BỎ DỮ LIỆU CŨ 
            // để làm sạch đường ống mạng, tránh lỗi dính gói tin (TCP Sticky).
            uint64_t dumped = 0;
            while(dumped < header.filesize) {
                uint64_t left = header.filesize - dumped;
                int chunk = (left < sizeof(buffer)) ? left : sizeof(buffer);
                int b = recv(sock, buffer, chunk, 0);
                if(b <= 0) break;
                dumped += b;
            }
            continue; 
        }

        // 4. Vòng lặp Hút dữ liệu thông minh
        uint64_t total_received = 0;
        while (total_received < header.filesize) {
            // Tính số lượng byte còn thiếu của file này
            uint64_t bytes_left = header.filesize - total_received;
            
            // Ép cái gáo múc nước (chunk_size) thu nhỏ lại nếu số nước cần múc bé hơn sức chứa của gáo.
            // Việc này tuyệt đối ngăn chặn múc lẹm sang file tiếp theo.
            int chunk_size = (bytes_left < sizeof(buffer)) ? bytes_left : sizeof(buffer);

            // Múc dữ liệu từ mạng lên (trả về số byte múc được thật sự)
            int bytes = recv(sock, buffer, chunk_size, 0);
            if (bytes <= 0) break; 

            // Đổ chính xác số lượng 'bytes' múc được vào ổ cứng
            fwrite(buffer, 1, bytes, write_file);
            total_received += bytes;
        }

        fclose(write_file);
        printf("[THÀNH CÔNG] Đã tải xong: %s\n", full_save_path);
        
        // In lại nhắc lệnh cho luồng chính để khỏi bị trôi mất giao diện
        printf("\nNhập đường dẫn file bạn muốn gửi đi (hoặc Ctrl+C để thoát): "); 
        fflush(stdout); 
    }
    return NULL;
}

/* ==============================================================================
 * LUỒNG CHÍNH: CÀI ĐẶT MẠNG, ĐỌC FILE TỪ Ổ CỨNG VÀ GỬI ĐI
 * ============================================================================== */
int main() {
    // --- BƯỚC 1: CẤU HÌNH THƯ MỤC TẢI XUỐNG ---
    printf("Nhập thư mục mặc định để lưu file nhận về (VD: /home/user/Downloads/ hoặc ./ ): ");
    if (fgets(save_directory, sizeof(save_directory), stdin) != NULL) {
        save_directory[strcspn(save_directory, "\n")] = 0; // Chém bay ký tự Enter (\n)
    }
    
    // Xử lý thông minh: Nếu người dùng lười, chỉ gõ Enter không nhập gì -> Lưu luôn ở thư mục hiện tại (./)
    if (strlen(save_directory) == 0) {
        strcpy(save_directory, "./");
    } 
    // Nếu nhập thiếu dấu gạch chéo ở cuối (VD: /home/user), hệ thống sẽ tự thêm vào (thành /home/user/)
    else if (save_directory[strlen(save_directory) - 1] != '/') {
        strcat(save_directory, "/");
    }
    printf("[HỆ THỐNG] Các file nhận được sẽ lưu tại: %s\n\n", save_directory);


    // --- BƯỚC 2: THIẾT LẬP MẠNG SERVER CHUẨN ---
    int server_fd, new_socket;
    struct sockaddr_in address;
    int addrlen = sizeof(address);

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY; // Đón khách từ mọi Card mạng
    address.sin_port = htons(PORT);

    bind(server_fd, (struct sockaddr *)&address, sizeof(address));
    listen(server_fd, 3);

    printf("=== SERVER ĐANG CHỜ MÁY CLIENT KẾT NỐI (CỔNG %d)... ===\n", PORT);
    new_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen);
    printf("-> Bắt tay thành công với Client!\n");


    // --- BƯỚC 3: PHÂN THÂN RA LÀM 2 LUỒNG SONG SONG ---
    pthread_t recv_thread;
    pthread_create(&recv_thread, NULL, receive_file_thread, (void*)&new_socket);


    // --- BƯỚC 4: VÒNG LẬP GỬI FILE ---
    char filepath[256];
    char buffer[BUFFER_SIZE];

    while(1) {
        printf("\nNhập đường dẫn file bạn muốn gửi đi (hoặc Ctrl+C để thoát): ");
        if (fgets(filepath, sizeof(filepath), stdin) == NULL) break;
        
        filepath[strcspn(filepath, "\n")] = 0; // Xóa phím Enter
        if (strlen(filepath) == 0) continue;

        // Mở file bằng đường dẫn tuyệt đối mà bạn vừa nhập
        FILE *read_file = fopen(filepath, "rb");
        if (read_file == NULL) {
            printf("[LỖI] Không tìm thấy file '%s' trên ổ cứng của bạn.\n", filepath);
            continue;
        }

        // Thuật toán đo dung lượng (Tua xuống cuối file để đếm số byte)
        fseek(read_file, 0, SEEK_END);
        uint64_t file_size = ftell(read_file);
        fseek(read_file, 0, SEEK_SET);

        // --- ĐOẠN NÂNG CẤP TRÍCH XUẤT TÊN FILE ---
        // Giả sử filepath là "/home/hung/baocao.pdf", hàm strrchr sẽ tìm dấu '/' cuối cùng
        char *real_filename = strrchr(filepath, '/');
        if (real_filename != NULL) {
            real_filename++; // Tiến lên 1 bước để né dấu '/', lấy đúng chữ "baocao.pdf"
        } else {
            real_filename = filepath; // Nếu chỉ nhập "baocao.pdf" (file ở thư mục hiện tại)
        }

        // Đóng gói Header với tên file gốc đã được lọc sạch sẽ
        FileHeader header;
        memset(&header, 0, sizeof(header));
        strncpy(header.filename, real_filename, sizeof(header.filename) - 1);
        header.filesize = file_size;

        // Bắn Header sang máy kia
        send(new_socket, &header, sizeof(FileHeader), 0);
        printf("[ĐANG GỬI] Bắt đầu đẩy file %s lên mạng...\n", header.filename);

        // Vòng lặp bơm dữ liệu lên mạng
        int bytes_read;
        while ((bytes_read = fread(buffer, 1, sizeof(buffer), read_file)) > 0) {
            send(new_socket, buffer, bytes_read, 0);
        }

        fclose(read_file);
        printf("[THÀNH CÔNG] Đã gửi file hoàn tất!\n");
    }

    close(new_socket);
    close(server_fd);
    return 0;
}
