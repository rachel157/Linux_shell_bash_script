#!/usr/bin/env bash
# ============================================================================
# scheduler.sh - Lập lịch tác vụ (GUI)
# ============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

scheduler_menu() {
    while true; do
        choice=$(gui_menu "⏰ LẬP LỊCH TÁC VỤ (CRON)" \
            "1" "Xem crontab hiện tại" \
            "2" "Thêm job mới" \
            "3" "Xóa job (theo số dòng)" \
            "4" "Xem log tác vụ" \
            "5" "Quay lại")

        case $choice in
            1)
                crontab -l > /tmp/crontab_display.txt 2>&1
                gui_textbox /tmp/crontab_display.txt "Crontab hiện tại"
                ;;
            2)
                schedule=$(gui_input "Nhập lịch cron (vd: '0 2 * * *'):" "")
                [[ -z "$schedule" ]] && continue
                cmd=$(gui_input "Nhập lệnh cần chạy:" "")
                [[ -z "$cmd" ]] && continue
                full_cmd="$cmd >> $CRON_LOG 2>&1"
                (crontab -l 2>/dev/null; echo "$schedule $full_cmd") | crontab - 2>/tmp/cron_err.txt
                if [[ $? -eq 0 ]]; then
                    gui_msg "Đã thêm job thành công"
                else
                    gui_textbox /tmp/cron_err.txt "Lỗi thêm job"
                fi
                ;;
            3)
                crontab -l > /tmp/crontab_del.txt 2>&1
                if [[ ! -s /tmp/crontab_del.txt ]]; then
                    gui_msg "Crontab trống, không có job để xóa."
                    continue
                fi
                # Hiển thị danh sách job có đánh số
                nl -ba /tmp/crontab_del.txt > /tmp/crontab_numbered.txt
                gui_textbox /tmp/crontab_numbered.txt "Chọn số dòng muốn xóa"
                lineno=$(gui_input "Nhập số dòng muốn xóa:" "")
                [[ -z "$lineno" ]] && continue
                sed -i "${lineno}d" /tmp/crontab_del.txt
                crontab /tmp/crontab_del.txt
                gui_msg "Đã xóa dòng $lineno (nếu tồn tại)"
                ;;
            4)
                if [[ -f "$CRON_LOG" ]]; then
                    gui_textbox "$CRON_LOG" "Log tác vụ"
                else
                    gui_msg "Chưa có file log."
                fi
                ;;
            5) break ;;
        esac
    done
}
