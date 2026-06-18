#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <pthread.h> 

// Luồng phụ song song: CHUYÊN ĐỢI VÀ NHẬN TIN từ Client qua mạng LAN
void* receive_func(void* socket_desc) {
    int client_socket = *(int*)socket_desc;
    char buffer[1024];

    while(1) {
        memset(buffer, 0, 1024);
        int valread = read(client_socket, buffer, 1024); // Đợi Client mạng LAN bắn gói tin sang
        if (valread <= 0) {
            printf("\nClient trong mạng LAN đã ngắt kết nối.\n");
            break;
        }
        printf("\nClient gửi: %s", buffer);
        printf("Server (Bạn): "); 
        fflush(stdout); // Ép hiển thị chữ ngay lập tức, chống nghẽn giao diện
    }
    close(client_socket);
    free(socket_desc);
    exit(0);
}

int main() {
    int server_fd, client_socket, *new_sock;
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    char message[1024];
    pthread_t recv_thread;

    // 1. Tạo điểm cuối socket IPv4 - TCP
    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    
    // 2. Định cấu hình LẮNG NGHE MẠNG LAN
    address.sin_family = AF_INET;
    address.sin_port = htons(8888);
    address.sin_addr.s_addr = INADDR_ANY; // Chấp nhận kết nối xuyên qua card mạng Wi-Fi/LAN
    
    // 3. Buộc địa chỉ vào socket
    bind(server_fd, (struct sockaddr *)&address, sizeof(address));
    
    // 4. Chờ hàng đợi kết nối
    listen(server_fd, 3);
    
    printf("Server đang mở cổng 8080, sẵn sàng chờ Máy Client mạng LAN kết nối...\n");
    
    // 5. Chấp nhận yêu cầu "gõ cửa" từ Client mạng LAN
    client_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen);
    printf("Kết nối LAN thành công! Đã bắt tay với Client.\n");

    // Khởi tạo luồng phụ nhận dữ liệu độc lập
    new_sock = malloc(sizeof(int));
    *new_sock = client_socket;
    pthread_create(&recv_thread, NULL, receive_func, (void*)new_sock);

    // Luồng chính: CHUYÊN ĐỢI NHẬP VÀ GỬI TIN LIÊN TỤC
    while(1) {
        printf("Server (Bạn): ");
        fgets(message, 1024, stdin);
        send(client_socket, message, strlen(message), 0); // Đẩy dữ liệu qua đường truyền LAN
    }

    close(server_fd);
    return 0;
}

