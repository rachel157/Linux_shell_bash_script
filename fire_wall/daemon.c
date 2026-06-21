#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PROC_PATH "/proc/firewall_rules"

void print_usage(const char *prog_name) {
    printf("Cach su dung phan mem Tuong Lua:\n");
    printf("  %s add <IP>   : Them IP vao danh sach chan\n", prog_name);
    printf("  %s del <IP>   : Xoa IP khoi danh sach chan\n", prog_name);
    printf("  %s list       : Xem danh sach dang bi chan\n", prog_name);
}

int main(int argc, char *argv[]) {
    FILE *fp;
    char buffer[1024];

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
        if (argc != 3) {
            printf("Loi: Thieu dia chi IP.\n");
            return 1;
        }

        fp = fopen(PROC_PATH, "w");
        if (!fp) {
            perror("Loi: Tuong lua chua duoc bat");
            return 1;
        }
        
        // Gộp hành động và IP thành 1 chuỗi: "add 10.0.2.2"
        snprintf(buffer, sizeof(buffer), "%s %s\n", argv[1], argv[2]);
        fprintf(fp, "%s", buffer);
        fclose(fp);
        
        printf("Thuc thi lenh '%s' voi IP '%s' thanh cong.\n", argv[1], argv[2]);
        return 0;
    }

    print_usage(argv[0]);
    return 1;
}
