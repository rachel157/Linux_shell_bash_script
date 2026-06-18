#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <pthread.h> // Thư viện đa luồng bắt buộc 🧵

// Hàm xử lý việc NHẬN TIN NHẮN (Chạy song song ở luồng riêng)
void* receive_func(void* socket_desc) {
    int client_socket = *(int*)socket_desc; // Lấy biến socket đại diện ra từ tham số truyền vào
    char buffer[1024];

    while(1) {
        memset(buffer, 0, 1024); // Xóa bộ đệm [cite: 752]
        int valread = read(client_socket, buffer, 1024); // Kéo dữ liệu từ đường ống [cite: 755]
        if (valread <= 0) {
            printf("\nClient đã ngắt kết nối.\n");
            break;
        }
        printf("\nClient: %s", buffer);
        printf("Server: "); // Giữ lại dòng gợi ý nhập
        fflush(stdout); // Ép hệ thống hiển thị chữ ra màn hình ngay lập tức
    }
    close(client_socket);
    exit(0);
}

int main() {
    int server_fd, client_socket, *new_sock;
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    char message[1024];
    pthread_t recv_thread; // Biến quản lý luồng nhận

    server_fd = socket(AF_INET, SOCK_STREAM, 0); // Tạo socket [cite: 595]
    
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = inet_addr("127.0.0.1"); // Chạy Localhost [cite: 597]
    address.sin_port = htons(8080); // Cổng 8080 [cite: 597]
    
    bind(server_fd, (struct sockaddr *)&address, sizeof(address)); // Gắn địa chỉ [cite: 607]
    listen(server_fd, 3); // Lắng nghe [cite: 614]
    
    printf("Server đang chờ kết nối tại cổng 8080...\n");
    client_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen); // Chấp nhận [cite: 616]
    printf("Client đã kết nối thành công!\n");

    // TẠO LUỒNG MỚI CHUYÊN NHẬN DỮ LIỆU
    new_sock = malloc(1);
    *new_sock = client_socket; // Lưu biến socket vào ô nhớ cấp phát để truyền đi an toàn
    pthread_create(&recv_thread, NULL, receive_func, (void*)new_sock);

    // LUỒNG CHÍNH (MAIN THREAD) CHUYÊN GỬI DỮ LIỆU
    while(1) {
        printf("Server: ");
        fgets(message, 1024, stdin); // Nhập từ bàn phím [cite: 766]
        send(client_socket, message, strlen(message), 0); // Bắn tin nhắn đi [cite: 768]
    }

    close(server_fd);
    return 0;
}
