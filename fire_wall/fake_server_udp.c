#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

int main() {
    int sockfd;
    char buffer[1024];
    struct sockaddr_in servaddr, cliaddr;
    socklen_t len;
    int n;

    // 1. Tao Socket UDP (SOCK_DGRAM)
    if ((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        perror("Loi tao socket");
        exit(EXIT_FAILURE);
    }
    
    memset(&servaddr, 0, sizeof(servaddr));
    memset(&cliaddr, 0, sizeof(cliaddr));
    
    // Cau hinh mang: Chap nhan moi IP, Lang nghe o cong 9090
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = INADDR_ANY;
    servaddr.sin_port = htons(9090); 
    
    // 2. Gan Socket vao Port 9090
    if (bind(sockfd, (const struct sockaddr *)&servaddr, sizeof(servaddr)) < 0) {
        perror("Loi Bind");
        exit(EXIT_FAILURE);
    }
    
    printf("=== FAKE UDP SERVER ===\n");
    printf("Dang lang nghe tin nhan UDP tren cong 9090...\n");
    
    len = sizeof(cliaddr);
    
    // 3. Cho nhan du lieu (Ham nay se block (dung im) cho toi khi co goi tin UDP bay toi)
    n = recvfrom(sockfd, (char *)buffer, 1024, MSG_WAITALL, (struct sockaddr *)&cliaddr, &len);
    
    // Cat chuoi va in ra man hinh
    if (n >= 0) {
        buffer[n] = '\0';
        printf("=> Bieu hien Firewall THAT BAI: Nhan duoc tin nhan UDP la: %s\n", buffer);
    } else {
        perror("Loi nhan du lieu");
    }
    
    close(sockfd);
    return 0;
}
