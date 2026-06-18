#!/usr/bin/env bash
# ============================================================================
# main.sh - Sysadmin Toolkit (phiên bản GUI whiptail)
# ============================================================================
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/gui.sh"
source "${SCRIPT_DIR}/lib/file_manager.sh"
source "${SCRIPT_DIR}/lib/scheduler.sh"
source "${SCRIPT_DIR}/lib/time_setup.sh"
source "${SCRIPT_DIR}/lib/pkg_manager.sh"
source "${SCRIPT_DIR}/lib/dashboard.sh"
source "${SCRIPT_DIR}/lib/backup.sh"

# Xử lý tham số dòng lệnh cho backup tự động (giữ nguyên)
if [[ "$1" == "--backup-dir" && -n "$2" ]]; then
    SOURCE_DIR="$2"
    shift 2
    GPG_PASS=""
    KEYFILE=""
    SSH_DEST=""
    SSH_PATH=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --passphrase) GPG_PASS="$2"; shift 2 ;;
            --keyfile)    KEYFILE="$2"; shift 2 ;;
            --ssh-dest)   SSH_DEST="$2"; shift 2 ;;
            --ssh-path)   SSH_PATH="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$GPG_PASS" && -z "$KEYFILE" ]]; then
        echo "Lỗi: Thiếu mật khẩu hoặc keyfile GPG"
        exit 1
    fi

    timestamp=$(date +%Y%m%d_%H%M%S)
    ARCHIVE="${BACKUP_DIR}/backup_${timestamp}.tar.gz"
    ENCRYPTED="${ARCHIVE}.gpg"

    echo "Bắt đầu backup tự động cho $SOURCE_DIR"
    tar -czf "$ARCHIVE" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" || exit 1

    if [[ -n "$KEYFILE" && -f "$KEYFILE" ]]; then
        gpg --yes --batch --passphrase-file "$KEYFILE" -c "$ARCHIVE" && rm "$ARCHIVE"
    elif [[ -n "$GPG_PASS" ]]; then
        gpg --yes --batch --passphrase "$GPG_PASS" -c "$ARCHIVE" && rm "$ARCHIVE"
    else
        rm -f "$ARCHIVE"
        exit 1
    fi

    if [[ -f "$ENCRYPTED" ]]; then
        echo "Backup tự động hoàn tất: $ENCRYPTED"
        if [[ -n "$SSH_DEST" && -n "$SSH_PATH" ]]; then
            echo "Đang gửi sang $SSH_DEST..."
            if ssh -o BatchMode=yes -o ConnectTimeout=10 "$SSH_DEST" "mkdir -p '$SSH_PATH'" 2>/dev/null; then
                scp "$ENCRYPTED" "${SSH_DEST}:${SSH_PATH}/" && echo "Gửi thành công" || echo "Gửi thất bại"
            else
                echo "Không kết nối được SSH"
            fi
        fi
        exit 0
    else
        echo "Backup thất bại"
        exit 1
    fi
fi

# ----- Menu chính GUI -----
main_menu_gui() {
    while true; do
        choice=$(gui_main_menu)
        case $choice in
            1) file_manager_menu ;;
            2) scheduler_menu ;;
            3) time_setup_menu ;;
            4) pkg_manager_menu ;;
            5) dashboard_tui ;;        # chạy trực tiếp trên terminal
            6) backup_menu ;;
            7) gui_msg "Cảm ơn bạn đã sử dụng!"; exit 0 ;;
            "") exit 0 ;;              # Cancel
        esac
    done
}

main_menu_gui
