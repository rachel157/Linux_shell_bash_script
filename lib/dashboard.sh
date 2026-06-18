#!/usr/bin/env bash
# ============================================================================
# dashboard.sh - Màn hình giám sát hệ thống thời gian thực (TUI)
# Hiển thị CPU, RAM, Disk cập nhật mỗi giây, dùng tput thuần bash
# Nhấn Ctrl+C để thoát
# ============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

dashboard_tui() {
    # Bắt tín hiệu ngắt (Ctrl+C) để khôi phục terminal
    trap 'tput cnorm; tput sgr0; clear; exit' INT TERM
    tput civis  # Ẩn con trỏ

    while true; do
        tput cup 0 0  # Đưa con trỏ về góc trên trái
        clear
        echo -e "${BOLD}${CYAN}=== BẢNG ĐIỀU KHIỂN HỆ THỐNG (cập nhật 1s) ===${RESET}"
        echo "----------------------------------------"

        # CPU: tính % sử dụng từ top (lấy idle và trừ cho 100)
        cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        printf "CPU: %s%%\n" "$cpu"

        # RAM: dùng free -m
        mem_total=$(free -m | awk '/Mem:/{print $2}')
        mem_used=$(free -m | awk '/Mem:/{print $3}')
        mem_perc=$((100 * mem_used / mem_total))
        printf "RAM: %s MB / %s MB (%s%%)\n" "$mem_used" "$mem_total" "$mem_perc"

        # Disk: kiểm tra phân vùng /
        disk_info=$(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')
        echo "Ổ đĩa (/): $disk_info"

        echo -e "\n${YELLOW}Nhấn Ctrl+C để thoát${RESET}"
        sleep 1
    done
}
