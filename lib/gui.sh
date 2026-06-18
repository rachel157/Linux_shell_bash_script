#!/usr/bin/env bash
# ============================================================================
# gui.sh - Thư viện giao diện whiptail cho Sysadmin Toolkit
# Cung cấp các hộp thoại: menu, input, password, msg, yes/no, textbox
# ============================================================================

# Kích thước mặc định
WT_HEIGHT=22
WT_WIDTH=75
WT_MENU_HEIGHT=14

# Menu chính của chương trình
gui_main_menu() {
    whiptail --title "SYSADMIN TOOLKIT" \
        --menu "Chọn chức năng:" \
        $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
        "1" "📁 Quản lý file" \
        "2" "⏰ Lập lịch tác vụ (Cron)" \
        "3" "🕒 Thiết lập thời gian hệ thống" \
        "4" "📦 Quản lý gói phần mềm" \
        "5" "📊 Bảng điều khiển hệ thống (realtime)" \
        "6" "🔐 Backup thông minh & Mã hóa GPG" \
        "7" "🚪 Thoát" \
        3>&1 1>&2 2>&3
}

# Menu chung cho các module con
# $1: tiêu đề, sau đó là các cặp "tag" "mô tả"
gui_menu() {
    local title="$1"
    shift
    whiptail --title "$title" \
        --menu "Lựa chọn:" \
        $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
        "$@" \
        3>&1 1>&2 2>&3
}

# Hộp nhập liệu
gui_input() {
    local prompt="$1"
    local default="$2"
    whiptail --title "Nhập thông tin" \
        --inputbox "$prompt" \
        10 65 "$default" \
        3>&1 1>&2 2>&3
}

# Hộp nhập mật khẩu (ẩn ký tự)
gui_password() {
    local prompt="$1"
    whiptail --title "Nhập mật khẩu" \
        --passwordbox "$prompt" \
        10 65 \
        3>&1 1>&2 2>&3
}

# Hộp thông báo
gui_msg() {
    local msg="$1"
    whiptail --title "Thông báo" \
        --msgbox "$msg" \
        15 65
}

# Hộp thoại Yes/No (trả về 0 nếu Yes, 1 nếu No)
gui_yesno() {
    local question="$1"
    whiptail --title "Xác nhận" \
        --yesno "$question" \
        10 65
}

# Hiển thị nội dung file văn bản trong scrollbox
gui_textbox() {
    local file="$1"
    local title="${2:-Kết quả}"
    whiptail --title "$title" \
        --textbox "$file" \
        20 75
}
