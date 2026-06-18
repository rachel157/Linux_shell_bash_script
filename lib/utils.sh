#!/usr/bin/env bash
# ============================================================================
# utils.sh - Các hàm dùng chung và biến toàn cục cho Sysadmin Toolkit
# ============================================================================

# Ngăn lỗi ẩn, dừng nếu có lỗi pipe
set -o pipefail

# ----- Biến toàn cục -----
# Lấy đường dẫn tuyệt đối của thư mục chứa script chính (toolkit/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
BACKUP_DIR="${SCRIPT_DIR}/backups"
CRON_LOG="${LOG_DIR}/cron_jobs.log"
PKG_LIST="${SCRIPT_DIR}/packages.txt"

# Tạo thư mục logs và backups nếu chưa tồn tại
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Màu sắc cho giao diện TUI
BOLD="\033[1m"
RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"

# ----- Hàm tiện ích -----
# Dừng màn hình chờ người dùng nhấn Enter
press_enter() {
    echo -e "\n${CYAN}Nhấn Enter để tiếp tục...${RESET}"
    read -r
}

# Kiểm tra quyền root, trả về 0 nếu là root, 1 nếu không
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Lỗi: Cần quyền root để thực hiện thao tác này.${RESET}"
        return 1
    fi
    return 0
}
