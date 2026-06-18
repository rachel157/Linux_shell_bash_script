#!/usr/bin/env bash
# ============================================================================
# file_manager.sh - Quản lý file (giao diện whiptail)
# ============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

file_manager_menu() {
    while true; do
        choice=$(gui_menu "📁 QUẢN LÝ FILE" \
            "1" "Tạo file / thư mục" \
            "2" "Xóa file / thư mục" \
            "3" "Đổi tên file / thư mục" \
            "4" "Di chuyển file / thư mục" \
            "5" "Tìm kiếm file" \
            "6" "Đổi quyền (chmod)" \
            "7" "Đổi chủ sở hữu (chown - root)" \
            "8" "Nén (tar.gz / zip)" \
            "9" "Giải nén" \
            "10" "Quay lại")

        case $choice in
            1)
                ftype=$(gui_menu "Tạo mới" "f" "File" "d" "Thư mục")
                [[ -z "$ftype" ]] && continue
                fname=$(gui_input "Nhập đường dẫn/tên:" "")
                [[ -z "$fname" ]] && continue
                if [[ "$ftype" == "d" ]]; then
                    mkdir -p "$fname" && gui_msg "Đã tạo thư mục $fname" || gui_msg "Tạo thất bại"
                else
                    touch "$fname" && gui_msg "Đã tạo file $fname" || gui_msg "Tạo thất bại"
                fi
                ;;
            2)
                dtype=$(gui_menu "Xóa" "f" "File" "d" "Thư mục")
                [[ -z "$dtype" ]] && continue
                dname=$(gui_input "Nhập đường dẫn:" "")
                [[ -z "$dname" ]] && continue
                if gui_yesno "Bạn chắc chắn muốn xóa $dname?"; then
                    if [[ "$dtype" == "d" ]]; then
                        rm -rf "$dname" && gui_msg "Đã xóa thư mục" || gui_msg "Xóa thất bại"
                    else
                        rm -f "$dname" && gui_msg "Đã xóa file" || gui_msg "Xóa thất bại"
                    fi
                fi
                ;;
            3)
                old=$(gui_input "Tên cũ:" "")
                new=$(gui_input "Tên mới:" "")
                [[ -z "$old" || -z "$new" ]] && continue
                mv "$old" "$new" && gui_msg "Đã đổi tên" || gui_msg "Đổi tên thất bại"
                ;;
            4)
                src=$(gui_input "Nguồn:" "")
                dest=$(gui_input "Đích:" "")
                [[ -z "$src" || -z "$dest" ]] && continue
                mv "$src" "$dest" && gui_msg "Đã di chuyển" || gui_msg "Di chuyển thất bại"
                ;;
            5)
                stype=$(gui_menu "Tìm kiếm theo" \
                    "name" "Tên" \
                    "size" "Kích thước" \
                    "mtime" "Ngày sửa đổi")
                sdir=$(gui_input "Thư mục tìm kiếm:" ".")
                [[ -z "$sdir" ]] && continue
                case $stype in
                    name)
                        pattern=$(gui_input "Mẫu tên (vd: *.txt):" "")
                        [[ -z "$pattern" ]] && continue
                        find "$sdir" -name "$pattern" > /tmp/find_result.txt 2>&1
                        ;;
                    size)
                        sz=$(gui_input "Kích thước (vd: +10M):" "")
                        [[ -z "$sz" ]] && continue
                        find "$sdir" -size "$sz" > /tmp/find_result.txt 2>&1
                        ;;
                    mtime)
                        days=$(gui_input "Số ngày sửa đổi (vd: -7):" "")
                        [[ -z "$days" ]] && continue
                        find "$sdir" -mtime "$days" > /tmp/find_result.txt 2>&1
                        ;;
                esac
                gui_textbox /tmp/find_result.txt "Kết quả tìm kiếm"
                ;;
            6)
                target=$(gui_input "File/thư mục cần đổi quyền:" "")
                perm=$(gui_input "Quyền mới (vd: 755, u+x):" "")
                [[ -z "$target" || -z "$perm" ]] && continue
                chmod "$perm" "$target" && gui_msg "Đã đổi quyền" || gui_msg "Đổi quyền thất bại"
                ;;
            7)
                if ! check_root; then gui_msg "Cần quyền root"; continue; fi
                target=$(gui_input "File/thư mục:" "")
                own=$(gui_input "Chủ sở hữu[:nhóm] (vd: root:root):" "")
                [[ -z "$target" || -z "$own" ]] && continue
                chown "$own" "$target" && gui_msg "Đã đổi chủ" || gui_msg "Đổi chủ thất bại"
                ;;
            8)
                cmode=$(gui_menu "Nén dạng" "tar" "tar.gz" "zip" "zip")
                aname=$(gui_input "Tên file nén (không cần đuôi):" "")
                target=$(gui_input "File/thư mục cần nén:" "")
                [[ -z "$cmode" || -z "$aname" || -z "$target" ]] && continue
                if [[ "$cmode" == "tar" ]]; then
                    tar -czf "${aname}.tar.gz" "$target" && gui_msg "Đã nén thành ${aname}.tar.gz" || gui_msg "Nén thất bại"
                else
                    zip -r "${aname}.zip" "$target" && gui_msg "Đã nén thành ${aname}.zip" || gui_msg "Nén thất bại"
                fi
                ;;
            9)
                arch=$(gui_input "Đường dẫn file nén (.tar.gz hoặc .zip):" "")
                [[ -z "$arch" ]] && continue
                if [[ "$arch" == *.tar.gz || "$arch" == *.tgz ]]; then
                    tar -xzf "$arch" && gui_msg "Giải nén thành công" || gui_msg "Giải nén thất bại"
                elif [[ "$arch" == *.zip ]]; then
                    unzip "$arch" && gui_msg "Giải nén thành công" || gui_msg "Giải nén thất bại"
                else
                    gui_msg "Định dạng không hỗ trợ"
                fi
                ;;
            10) break ;;
        esac
    done
}
