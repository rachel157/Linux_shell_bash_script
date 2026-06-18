#!/usr/bin/env bash
# ============================================================================
# time_setup.sh - Thiết lập thời gian hệ thống (GUI)
# ============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

time_setup_menu() {
    while true; do
        choice=$(gui_menu "🕒 THIẾT LẬP THỜI GIAN" \
            "1" "Xem ngày giờ và múi giờ" \
            "2" "Đặt ngày giờ thủ công (root)" \
            "3" "Bật/tắt đồng bộ NTP (root)" \
            "4" "Đổi múi giờ (root)" \
            "5" "Quay lại")

        case $choice in
            1)
                info="Ngày giờ hiện tại: $(date)\n"
                tz=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null)
                info+="Múi giờ: ${tz:-Không xác định}"
                gui_msg "$info"
                ;;
            2)
                if ! check_root; then gui_msg "Cần quyền root"; continue; fi
                newdt=$(gui_input "Nhập ngày giờ mới (YYYY-MM-DD HH:MM:SS):" "")
                [[ -z "$newdt" ]] && continue
                date -s "$newdt" && gui_msg "Đã đặt thời gian" || gui_msg "Đặt thời gian thất bại"
                ;;
            3)
                if ! check_root; then gui_msg "Cần quyền root"; continue; fi
                if gui_yesno "Bật NTP?"; then
                    timedatectl set-ntp true 2>/dev/null || ntpdate pool.ntp.org
                    gui_msg "Đã bật NTP"
                else
                    timedatectl set-ntp false 2>/dev/null && gui_msg "Đã tắt NTP" || gui_msg "Tắt NTP thất bại"
                fi
                ;;
            4)
                if ! check_root; then gui_msg "Cần quyền root"; continue; fi
                tzlist=$(timedatectl list-timezones 2>/dev/null)
                # Tạo menu chọn timezone
                tzchoice=$(whiptail --title "Chọn múi giờ" --menu "Danh sách múi giờ:" 20 70 12 $(echo "$tzlist" | awk '{print $1 " " $1}') 3>&1 1>&2 2>&3)
                if [[ -n "$tzchoice" ]]; then
                    timedatectl set-timezone "$tzchoice" && gui_msg "Đã đổi múi giờ sang $tzchoice" || gui_msg "Đổi múi giờ thất bại"
                fi
                ;;
            5) break ;;
        esac
    done
}
