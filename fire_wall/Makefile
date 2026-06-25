# Khai báo file module đầu ra chuẩn 2 chữ L
obj-m += firewall_mod.o

# === CẤU HÌNH ĐƯỜNG DẪN ===
# Thư mục gốc của Buildroot 
BR_DIR := /home/rachel/linux_img/buildroot-2024.02.2

# Tự động tìm thư mục Linux Kernel
KDIR := $(wildcard $(BR_DIR)/output/build/linux-[0-9]*)
PWD := $(shell pwd)

# Tiền tố của Trình biên dịch chéo
CROSS := $(BR_DIR)/output/host/bin/x86_64-buildroot-linux-gnu-

# === CÁC LỆNH BIÊN DỊCH ===
all: kernel_module app

# Ép Kernel dùng đúng Cross-Compiler
kernel_module:
	$(MAKE) -C $(KDIR) M=$(PWD) ARCH=x86_64 CROSS_COMPILE=$(CROSS) modules

# Dịch ứng dụng user-space bằng gcc của Buildroot
app:
	$(CROSS)gcc -o my_firewall daemon.c
	$(CROSS)gcc -o fake_server_tcp fake_server_tcp.c
	$(CROSS)gcc -o fake_server_udp fake_server_udp.c

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f my_firewall fake_server_tcp fake_server_udp
