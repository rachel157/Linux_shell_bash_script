#!/usr/bin/env bash
# ============================================================================
# dashboard.sh - Màn hình giám sát hệ thống thời gian thực (TUI)
# Hiển thị CPU, RAM, Disk, Uptime, Top Process - cập nhật mỗi 2 giây
# Nhấn Q để thoát
# ============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

dashboard_tui() {
    # Bắt tín hiệu ngắt để khôi phục terminal
    trap 'tput cnorm; tput sgr0; clear; return' INT TERM
    tput civis  # Ẩn con trỏ
    clear

    while true; do
        tput cup 0 0  # Đưa cursor về góc trên trái (không dùng clear để tránh nháy màn hình)

        # Tiêu đề
        printf "${BOLD}${CYAN}=== BẢNG ĐIỀU KHIỂN HỆ THỐNG ===================${RESET}\n"
        printf "%-50s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
        printf "%-50s\n" "--------------------------------------------------"

        # Uptime
        uptime_info=$(uptime -p 2>/dev/null || uptime)
        printf "${BOLD}Uptime  :${RESET} %-40s\n" "$uptime_info"

        # CPU: tính % sử dụng từ top
        cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{printf "%.1f", 100 - $1}')
        printf "${BOLD}CPU     :${RESET} %-40s\n" "${cpu}%"

        # RAM
        mem_total=$(free -m | awk '/Mem:/{print $2}')
        mem_used=$(free -m  | awk '/Mem:/{print $3}')
        mem_perc=$((100 * mem_used / mem_total))
        printf "${BOLD}RAM     :${RESET} %-40s\n" "${mem_used} MB / ${mem_total} MB (${mem_perc}%)"

        # Disk
        disk_info=$(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')
        printf "${BOLD}Ổ đĩa  :${RESET} %-40s\n" "$disk_info"

        # Tiến trình ngốn CPU nhiều nhất
        top_proc=$(ps -eo pid,comm,%cpu --sort=-%cpu 2>/dev/null \
            | awk 'NR==2{printf "%s (PID %s) - %s%%", $2, $1, $3}')
        printf "${BOLD}Top CPU :${RESET} %-40s\n" "$top_proc"

        printf "%-50s\n" "--------------------------------------------------"
        printf "${YELLOW}[Q] Thoát  |  Tự động cập nhật mỗi 2 giây${RESET}       \n"

        # Chờ tối đa 2 giây, bắt phím Q để thoát ngay
        read -t 2 -n 1 key 2>/dev/null
        [[ "$key" =~ [qQ] ]] && break
    done

    tput cnorm; tput sgr0; clear
}
