#!/usr/bin/env bash
# ============================================================================
# backup.sh - Backup & Mã hóa GPG (GUI)
# ============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

GPG_PASS="${GPG_PASS:-}"
KEYFILE="${KEYFILE:-}"

# Xoay vòng backup: giữ lại $1 bản mới nhất, xóa các bản cũ hơn
# Tham số $1: số bản muốn giữ lại (mặc định 7)
rotate_backups() {
    local keep="${1:-7}"
    local backup_files
    mapfile -t backup_files < <(ls -t "${BACKUP_DIR}"/*.tar.gz.gpg 2>/dev/null)
    local total=${#backup_files[@]}

    if [[ $total -eq 0 ]]; then
        echo "Rotation: Không có file backup nào."
        return 0
    fi

    if [[ $total -le $keep ]]; then
        echo "Rotation: Đang có $total/$keep bản. Không cần xóa."
        return 0
    fi

    local to_delete=("${backup_files[@]:$keep}")
    echo "Rotation: Có $total bản, giữ lại $keep. Xóa ${#to_delete[@]} bản cũ..."
    for old_file in "${to_delete[@]}"; do
        rm -f "$old_file" && echo "Đã xóa: $old_file" || echo "Xóa thất bại: $old_file"
    done
}

create_backup() {
    local source_path="$1"
    local encrypt_mode="$2"

    if [[ ! -e "$source_path" ]]; then
        gui_msg "Lỗi: '$source_path' không tồn tại."
        return 1
    fi

    local base_name=$(basename "$source_path")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local archive="${BACKUP_DIR}/${base_name}_${timestamp}.tar.gz"
    local encrypted="${archive}.gpg"

    tar -czf "$archive" -C "$(dirname "$source_path")" "$base_name" 2>/tmp/tar_err.txt
    if [[ $? -ne 0 ]]; then
        gui_msg "Nén thất bại: $(cat /tmp/tar_err.txt)"
        rm -f "$archive"
        return 1
    fi

    if [[ "$encrypt_mode" == "key" ]]; then
        gpg --yes --batch --passphrase-file "$KEYFILE" -c "$archive" 2>/tmp/gpg_err.txt
    else
        gpg --yes --batch --passphrase "$GPG_PASS" -c "$archive" 2>/tmp/gpg_err.txt
    fi

    if [[ $? -ne 0 || ! -f "$encrypted" ]]; then
        gui_msg "Mã hóa thất bại: $(cat /tmp/gpg_err.txt)"
        rm -f "$archive"
        return 1
    fi
    rm -f "$archive"
    rotate_backups 7
    gui_msg "Backup thành công:\n$encrypted\n\n✅ Đã tự động giữ lại 7 bản mới nhất."
    return 0
}

restore_backup() {
    enc_file=$(gui_input "File backup mã hóa (.tar.gz.gpg):" "")
    [[ -z "$enc_file" || ! -f "$enc_file" ]] && { gui_msg "File không tồn tại"; return; }

    out_dir="${BACKUP_DIR}/restored_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$out_dir"

    mode="pass"
    if [[ -n "$KEYFILE" ]]; then
        if gui_yesno "Dùng keyfile để giải mã?"; then mode="key"; fi
    fi

    if [[ "$mode" == "key" ]]; then
        gpg --yes --batch --passphrase-file "$KEYFILE" -o "${out_dir}/backup.tar.gz" -d "$enc_file" 2>/tmp/gpg_err.txt
    else
        if [[ -z "$GPG_PASS" ]]; then
            GPG_PASS=$(gui_password "Nhập mật khẩu GPG:")
        fi
        gpg --yes --batch --passphrase "$GPG_PASS" -o "${out_dir}/backup.tar.gz" -d "$enc_file" 2>/tmp/gpg_err.txt
    fi

    if [[ $? -ne 0 ]]; then
        gui_msg "Giải mã thất bại:\n$(cat /tmp/gpg_err.txt)"
        rm -rf "$out_dir"
        return
    fi

    tar -xzf "${out_dir}/backup.tar.gz" -C "$out_dir" 2>/tmp/tar_err.txt
    if [[ $? -eq 0 ]]; then
        rm -f "${out_dir}/backup.tar.gz"
        gui_msg "Đã phục hồi vào:\n$out_dir"
    else
        gui_msg "Giải nén thất bại:\n$(cat /tmp/tar_err.txt)"
    fi
}

schedule_backup() {
    target=$(gui_input "File/thư mục cần backup định kỳ:" "")
    [[ -z "$target" || ! -e "$target" ]] && { gui_msg "Đường dẫn không tồn tại"; return; }

    cron_schedule=$(gui_input "Lịch cron (vd: 28 15 * * *):" "")
    [[ -z "$cron_schedule" ]] && return

    gui_yesno "Gửi backup sang máy đích qua SSH?" && send_ssh="y" || send_ssh="n"
    if [[ "$send_ssh" == "y" ]]; then
        ssh_dest=$(gui_input "Máy đích (user@host):" "")
        ssh_path=$(gui_input "Thư mục đích trên máy đích:" "")
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$ssh_dest" "mkdir -p '$ssh_path'" 2>/dev/null; then
            gui_msg "Không kết nối được SSH, sẽ không gửi qua SSH"
            send_ssh="n"
        fi
    fi

    script_path="$(readlink -f "${SCRIPT_DIR}/main.sh")"
    cron_cmd=""

    if [[ -n "$KEYFILE" && -f "$KEYFILE" ]]; then
        cron_cmd="bash '$script_path' --backup-dir '$target' --keyfile '$KEYFILE'"
    else
        if [[ -z "$GPG_PASS" ]]; then
            GPG_PASS=$(gui_password "Nhập mật khẩu GPG:")
        fi
        gui_msg "Cảnh báo: Passphrase lưu trong crontab!"
        cron_cmd="bash '$script_path' --backup-dir '$target' --passphrase '$GPG_PASS'"
    fi

    if [[ "$send_ssh" == "y" ]]; then
        cron_cmd="$cron_cmd --ssh-dest '$ssh_dest' --ssh-path '$ssh_path'"
    fi

    full_cron="$cron_schedule $cron_cmd >> $CRON_LOG 2>&1"
    (crontab -l 2>/dev/null; echo "$full_cron") | crontab - 2>/tmp/cron_err.txt
    if [[ $? -eq 0 ]]; then
        msg="Đã lên lịch backup định kỳ"
        [[ "$send_ssh" == "y" ]] && msg+="\nSẽ gửi đến $ssh_dest:$ssh_path"
        gui_msg "$msg"
    else
        gui_msg "Thêm cron job thất bại:\n$(cat /tmp/cron_err.txt)"
    fi
}

ssh_backup() {
    remote_host=$(gui_input "Máy đích (user@host):" "")
    remote_path=$(gui_input "Thư mục đích:" "")
    [[ -z "$remote_host" || -z "$remote_path" ]] && return

    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$remote_host" "mkdir -p '$remote_path'" 2>/dev/null; then
        gui_msg "Không kết nối được SSH"
        return
    fi

    choice=$(gui_menu "SSH Backup" "1" "Upload file có sẵn" "2" "Tạo mới & upload")
    case $choice in
        1)
            local_file=$(gui_input "File backup (.tar.gz.gpg):" "")
            [[ ! -f "$local_file" ]] && { gui_msg "File không tồn tại"; return; }
            scp "$local_file" "${remote_host}:${remote_path}/" 2>/tmp/scp_err.txt
            [[ $? -eq 0 ]] && gui_msg "Upload thành công" || gui_msg "Upload thất bại"
            ;;
        2)
            source_path=$(gui_input "File/thư mục cần backup:" "")
            [[ ! -e "$source_path" ]] && { gui_msg "Không tồn tại"; return; }
            mode="pass"
            [[ -n "$KEYFILE" ]] && mode="key"
            create_backup "$source_path" "$mode"
            newest=$(ls -t "${BACKUP_DIR}"/*.tar.gz.gpg 2>/dev/null | head -1)
            [[ -z "$newest" ]] && { gui_msg "Không tìm thấy backup vừa tạo"; return; }
            scp "$newest" "${remote_host}:${remote_path}/" 2>/tmp/scp_err.txt
            [[ $? -eq 0 ]] && gui_msg "Backup & upload thành công" || gui_msg "Upload thất bại"
            ;;
    esac
}

manage_backups() {
    while true; do
        choice=$(gui_menu "Quản lý backup" \
            "1" "Xem danh sách backup" \
            "2" "Xóa một backup thủ công" \
            "3" "🔄 Chạy Rotation ngay (xóa bản cũ)" \
            "4" "Quay lại")
        case $choice in
            1)
                ls -lh "${BACKUP_DIR}"/*.tar.gz.gpg 2>/dev/null > /tmp/backup_list.txt
                gui_textbox /tmp/backup_list.txt "Danh sách backup"
                ;;
            2)
                backups=("${BACKUP_DIR}"/*.tar.gz.gpg)
                if [[ ! -e "${backups[0]}" ]]; then
                    gui_msg "Không có backup nào"
                    continue
                fi
                # Tạo menu xóa
                menu_args=()
                for i in "${!backups[@]}"; do
                    menu_args+=("$((i+1))" "${backups[$i]}")
                done
                idx=$(whiptail --title "Xóa backup" --menu "Chọn backup:" 20 80 10 "${menu_args[@]}" 3>&1 1>&2 2>&3)
                if [[ -n "$idx" ]]; then
                    rm -f "${backups[$((idx-1))]}" && gui_msg "Đã xóa"
                fi
                ;;
            3)
                keep=$(gui_input "Giữ lại bao nhiêu bản backup gần nhất?" "7")
                [[ -z "$keep" || ! "$keep" =~ ^[0-9]+$ ]] && {
                    gui_msg "Số không hợp lệ. Vui lòng nhập số nguyên dương."
                    continue
                }
                rotate_backups "$keep" > /tmp/rotation_result.txt 2>&1
                gui_textbox /tmp/rotation_result.txt "Kết quả Rotation"
                ;;
            4) break ;;
        esac
    done
}

# Menu chính của backup (GUI)
backup_menu() {
    if [[ -z "$GPG_PASS" && -z "$KEYFILE" ]]; then
        auth_choice=$(gui_menu "Xác thực GPG" "1" "Mật khẩu" "2" "Keyfile")
        case $auth_choice in
            1) GPG_PASS=$(gui_password "Nhập mật khẩu GPG:") ;;
            2) KEYFILE=$(gui_input "Đường dẫn keyfile:" "")
               if [[ ! -f "$KEYFILE" ]]; then
                   gui_msg "Keyfile không tồn tại, dùng mật khẩu"
                   GPG_PASS=$(gui_password "Nhập mật khẩu GPG:")
                   KEYFILE=""
               fi
               ;;
        esac
    fi

    while true; do
        choice=$(gui_menu "🔐 BACKUP & MÃ HÓA GPG" \
            "1" "Tạo backup mã hóa" \
            "2" "Phục hồi backup" \
            "3" "Lên lịch backup tự động" \
            "4" "Backup lên máy từ xa qua SSH" \
            "5" "Quản lý backup" \
            "6" "Quay lại")

        case $choice in
            1)
                source_path=$(gui_input "File/thư mục cần backup:" "")
                [[ -z "$source_path" ]] && continue
                if [[ -n "$KEYFILE" ]]; then
                    create_backup "$source_path" "key"
                else
                    create_backup "$source_path" "pass"
                fi
                ;;
            2) restore_backup ;;
            3) schedule_backup ;;
            4) ssh_backup ;;
            5) manage_backups ;;
            6) break ;;
        esac
    done
}
