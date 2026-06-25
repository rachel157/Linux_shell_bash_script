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
            "3" "Xóa job (chọn từ menu)" \
            "4" "Xem log tác vụ" \
            "5" "🗑️  Dọn dẹp log tác vụ" \
            "6" "Quay lại")

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
                full_cmd="( $cmd ) >> $CRON_LOG 2>&1"
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

                # Xây dựng danh sách tham số cho whiptail checklist
                local menu_args=()
                local line_idx=0
                while IFS= read -r line; do
                    line_idx=$((line_idx + 1))
                    # Mỗi mục gồm: tag (số dòng) | mô tả (nội dung job) | trạng thái OFF
                    menu_args+=("$line_idx" "$line" "OFF")
                done < /tmp/crontab_del.txt

                # Hiển thị Checklist cho người dùng chọn
                selected=$(whiptail --title "Xóa Cronjob" \
                    --checklist "Dùng PHÍM CÁCH để chọn job muốn xóa, rồi bấm Enter:" \
                    20 85 10 \
                    "${menu_args[@]}" \
                    3>&1 1>&2 2>&3)

                [[ -z "$selected" ]] && continue

                # Xóa các dòng đã chọn (xóa từ dưới lên để không lệch số thứ tự)
                for lineno in $(echo "$selected" | tr -d '"' | tr ' ' '\n' | sort -rn); do
                    sed -i "${lineno}d" /tmp/crontab_del.txt
                done

                crontab /tmp/crontab_del.txt
                gui_msg "✅ Đã xóa job thành công!"
                ;;
            4)
                if [[ -f "$CRON_LOG" ]]; then
                    gui_textbox "$CRON_LOG" "Log tác vụ"
                else
                    gui_msg "Chưa có file log."
                fi
                ;;
            5)
                if [[ ! -f "$CRON_LOG" ]]; then
                    gui_msg "Chưa có file log để dọn dẹp."
                    continue
                fi

                # Hiển thị dung lượng file log hiện tại trước khi xóa
                log_size=$(du -sh "$CRON_LOG" 2>/dev/null | cut -f1)
                if gui_yesno "File log hiện đang chiếm $log_size dung lượng.\n\nBạn có chắc muốn xóa toàn bộ nội dung log không?\n(Hành động này không thể hoàn tác!)"; then
                    > "$CRON_LOG"
                    gui_msg "✅ Đã dọn dẹp log thành công!"
                fi
                ;;
            6) break ;;
        esac
    done
}
