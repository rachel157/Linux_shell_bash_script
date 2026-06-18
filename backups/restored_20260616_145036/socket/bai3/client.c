#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>      // Thư viện hệ thống POSIX (close)
#include <arpa/inet.h>   // Thư viện xử lý Socket
#include <pthread.h>     // Thư viện Đa luồng (Multithreading)
#include <stdint.h>      // Hỗ trợ kiểu dữ liệu uint64_t

#define PORT 8888
#define BUFFER_SIZE 1024

// Biến toàn cục lưu thư mục tải xuống của Client
char save_directory[256]; 

// Cấu trúc gói tin Header
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
        // 1. Nhận gói Header (Dùng MSG_WAITALL)
        int valread = recv(sock, &header, sizeof(FileHeader), MSG_WAITALL);
        if (valread <= 0) {
            printf("\n[HỆ THỐNG] Server đã đóng cửa.\n");
            exit(0); 
        }

        // 2. Ghép thư mục tải xuống với tên file
        char full_save_path[512];
        snprintf(full_save_path, sizeof(full_save_path), "%s%s", save_directory, header.filename);

        printf("\n\n[ĐANG NHẬN] Có file gửi tới: %s (%lu bytes).\n", header.filename, header.filesize);
        printf("-> Đang lưu tại: %s\n", full_save_path);

        // 3. Mở file để ghi nhị phân
        FILE *write_file = fopen(full_save_path, "wb");
        if (write_file == NULL) {
            perror("\n[LỖI] Không thể tạo file (Có thể sai thư mục tải xuống)");
            
            // Hút bỏ dữ liệu để tránh dính TCP
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
            uint64_t bytes_left = header.filesize - total_received;
            int chunk_size = (bytes_left < sizeof(buffer)) ? bytes_left : sizeof(buffer);

            int bytes = recv(sock, buffer, chunk_size, 0);
            if (bytes <= 0) break; 

            fwrite(buffer, 1, bytes, write_file);
            total_received += bytes;
        }

        fclose(write_file);
        printf("[THÀNH CÔNG] Đã tải xong: %s\n", full_save_path);
        
        printf("\nNhập đường dẫn file bạn muốn gửi đi (hoặc Ctrl+C để thoát): "); 
        fflush(stdout); 
    }
    return NULL;
}

/* ==============================================================================
 * LUỒNG CHÍNH: KẾT NỐI MẠNG, ĐỌC FILE TỪ Ổ CỨNG VÀ GỬI ĐI
 * ============================================================================== */
int main() {
    // --- BƯỚC 1: CẤU HÌNH THƯ MỤC TẢI XUỐNG ---
    printf("Nhập thư mục mặc định để lưu file nhận về (VD: /home/user/Downloads/ hoặc ./ ): ");
    if (fgets(save_directory, sizeof(save_directory), stdin) != NULL) {
        save_directory[strcspn(save_directory, "\n")] = 0; 
    }
    
    if (strlen(save_directory) == 0) {
        strcpy(save_directory, "./");
    } 
    else if (save_directory[strlen(save_directory) - 1] != '/') {
        strcat(save_directory, "/");
    }
    printf("[HỆ THỐNG] Các file nhận được sẽ lưu tại: %s\n\n", save_directory);


    // --- BƯỚC 2: THIẾT LẬP KẾT NỐI TỚI SERVER ---
    int client_fd;
    struct sockaddr_in serv_addr;

    client_fd = socket(AF_INET, SOCK_STREAM, 0);
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT);
    
    // NHẬP IP CỦA MÁY SERVER VÀO ĐÂY
    inet_pton(AF_INET, "192.168.4.101", &serv_addr.sin_addr);

    printf("Đang gõ cửa Server...\n");
    if (connect(client_fd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        perror("Kết nối thất bại (Server chưa bật hoặc sai IP)");
        return -1;
    }
    printf("-> Đã kết nối thành công với Server!\n");


    // --- BƯỚC 3: PHÂN THÂN RA LÀM 2 LUỒNG SONG SONG ---
    pthread_t recv_thread;
    pthread_create(&recv_thread, NULL, receive_file_thread, (void*)&client_fd);


    // --- BƯỚC 4: VÒNG LẬP GỬI FILE ---
    char filepath[256];
    char buffer[BUFFER_SIZE];

    while(1) {
        printf("\nNhập đường dẫn file bạn muốn gửi đi (hoặc Ctrl+C để thoát): ");
        if (fgets(filepath, sizeof(filepath), stdin) == NULL) break;
        
        filepath[strcspn(filepath, "\n")] = 0; // Xóa phím Enter
        if (strlen(filepath) == 0) continue;

        // Đọc ổ cứng
        FILE *read_file = fopen(filepath, "rb");
        if (read_file == NULL) {
            printf("[LỖI] Không tìm thấy file '%s'.\n", filepath);
            continue;
        }

        // Đo dung lượng
        fseek(read_file, 0, SEEK_END);
        uint64_t file_size = ftell(read_file);
        fseek(read_file, 0, SEEK_SET);

        // --- ĐOẠN NÂNG CẤP TRÍCH XUẤT TÊN FILE ---
        char *real_filename = strrchr(filepath, '/');
        if (real_filename != NULL) {
            real_filename++; 
        } else {
            real_filename = filepath; 
        }

        // Đóng gói Header
        FileHeader header;
        memset(&header, 0, sizeof(header));
        strncpy(header.filename, real_filename, sizeof(header.filename) - 1);
        header.filesize = file_size;

        // Bắn Header
        send(client_fd, &header, sizeof(FileHeader), 0);
        printf("[ĐANG GỬI] Bắt đầu đẩy file %s lên mạng...\n", header.filename);

        // Bơm dữ liệu file
        int bytes_read;
        while ((bytes_read = fread(buffer, 1, sizeof(buffer), read_file)) > 0) {
            send(client_fd, buffer, bytes_read, 0);
        }

        fclose(read_file);
        printf("[THÀNH CÔNG] Đã gửi file hoàn tất!\n");
    }

    close(client_fd);
    return 0;
}
