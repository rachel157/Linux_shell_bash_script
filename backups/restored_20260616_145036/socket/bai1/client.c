#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <pthread.h> // Thư viện đa luồng bắt buộc 🧵

// Hàm xử lý việc NHẬN TIN NHẮN (Chạy song song ở luồng riêng)
void* receive_func(void* socket_desc) {
    int sock = *(int*)socket_desc; // Lấy biến socket đại diện ra
    char buffer[1024];

    while(1) {
        memset(buffer, 0, 1024);
        int valread = read(sock, buffer, 1024);
        if (valread <= 0) {
            printf("\nServer đã ngắt kết nối.\n");
            break;
        }
        printf("\nServer: %s", buffer);
        printf("Client: ");
        fflush(stdout);
    }
    close(sock);
    exit(0);
}

int main() {
    int sock = 0, *new_sock;
    struct sockaddr_in serv_addr;
    char message[1024];
    pthread_t recv_thread;

    sock = socket(AF_INET, SOCK_STREAM, 0); // Tạo socket [cite: 625]
    
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(8080);
    inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr); // Cấu hình IP [cite: 625]
    
    connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)); // Kết nối [cite: 625]
    printf("Đã kết nối thành công tới Server!\n");

    // TẠO LUỒNG MỚI CHUYÊN NHẬN DỮ LIỆU
    new_sock = malloc(1);
    *new_sock = sock;
    pthread_create(&recv_thread, NULL, receive_func, (void*)new_sock);

    // LUỒNG CHÍNH (MAIN THREAD) CHUYÊN GỬI DỮ LIỆU
    while(1) {
        printf("Client: ");
        fgets(message, 1024, stdin);
        send(sock, message, strlen(message), 0); // Bắn tin nhắn liên tục 
    }

    return 0;
}
