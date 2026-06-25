#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

int main() {
    int server_fd, new_socket;
    struct sockaddr_in address;
    int opt = 1;
    int addrlen = sizeof(address);

    // 1. Tao Socket
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("Loi tao socket");
        exit(EXIT_FAILURE);
    }
    
    // 2. Chống kẹt port khi chạy đi chạy lại nhiều lần
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(8080); // Lắng nghe ở cổng 8080

    // 3. Gắn Socket vào Port 8080
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("Loi Bind");
        exit(EXIT_FAILURE);
    }
    
    // 4. Bật chế độ lắng nghe (Giống y hệt lệnh nc -l)
    if (listen(server_fd, 3) < 0) {
        perror("Loi Listen");
        exit(EXIT_FAILURE);
    }
    
    printf("=== FAKE SERVER (Thay the nc) ===\n");
    printf("Dang lang nghe tren cong 8080...\n");
    
    // 5. Chờ khách (Hacker) tới kết nối
    if ((new_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen)) < 0) {
        perror("Loi Accept");
        exit(EXIT_FAILURE);
    }
    
    printf("=> Bieu hien Firewall THAT BAI: Co khach ket noi vao roi!\n");
    
    close(new_socket);
    close(server_fd);
    return 0;
}
