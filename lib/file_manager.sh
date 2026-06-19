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
                # --- BƯỚC 1: Thư mục tìm kiếm (bắt buộc) ---
                default_dir=$(echo ~)
                sdir=$(gui_input "🔍 TÌM KIẾM FILE - Bước 1/6\n\nThư mục tìm kiếm (bắt buộc):\n(vd: /home/rachel, /var/log, / để tìm toàn hệ thống)" "$default_dir")
                [[ -z "$sdir" ]] && continue
                if [[ ! -d "$sdir" ]]; then
                    gui_msg "Lỗi: '$sdir' không phải thư mục hợp lệ."
                    continue
                fi

                # --- BƯỚC 2: Mẫu tên file (tùy chọn) ---
                pattern=$(gui_input "Bước 2/6 - Mẫu tên file\n(vd: *.log, report*, data?.csv)\nBỏ trống để bỏ qua:" "")

                # --- BƯỚC 3: Loại (file / thư mục / cả hai) ---
                ftype_choice=$(gui_menu "Bước 3/6 - Loại cần tìm" \
                    "both" "Cả file và thư mục" \
                    "f"    "Chỉ file thường" \
                    "d"    "Chỉ thư mục")
                [[ -z "$ftype_choice" ]] && ftype_choice="both"

                # --- BƯỚC 4: Kích thước (tùy chọn) ---
                sz=$(gui_input "Bước 4/6 - Kích thước\n(vd: +10M = lớn hơn 10MB, -1G = nhỏ hơn 1GB, +500k)\nBỏ trống để bỏ qua:" "")

                # --- BƯỚC 5: Ngày sửa đổi (tùy chọn) ---
                mtime=$(gui_input "Bước 5/6 - Ngày sửa đổi\n(vd: -7 = trong 7 ngày gần đây, +30 = cũ hơn 30 ngày)\nBỏ trống để bỏ qua:" "")

                # --- BƯỚC 6: Tìm theo nội dung bên trong file (tùy chọn) ---
                content=$(gui_input "Bước 6/6 - Từ khóa trong nội dung file\n(vd: ERROR, rachel, backup)\nBỏ trống để bỏ qua:" "")

                # --- Xây dựng lệnh find bằng MẢNG (không dùng eval) ---
                find_args=("$sdir")
                [[ "$ftype_choice" == "f" ]] && find_args+=("-type" "f")
                [[ "$ftype_choice" == "d" ]] && find_args+=("-type" "d")
                [[ -n "$pattern" ]]          && find_args+=("-name" "$pattern")
                [[ -n "$sz" ]]               && find_args+=("-size" "$sz")
                [[ -n "$mtime" ]]            && find_args+=("-mtime" "$mtime")
                [[ -n "$content" ]]          && find_args+=("-exec" "grep" "-l" "$content" "{}" ";")

                # Chuỗi chỉ dùng để hiển thị cho người dùng xem (không dùng để chạy)
                display_cmd="find ${find_args[*]}"

                if gui_yesno "Sẽ chạy lệnh:\n\n$display_cmd\n\nXác nhận tìm kiếm?"; then
                    # Chạy bằng mảng - an toàn, không cần eval
                    find "${find_args[@]}" > /tmp/find_result.txt 2>/tmp/find_err.txt

                    count=$(wc -l < /tmp/find_result.txt)
                    count=${count//[[:space:]]/}   # Xóa khoảng trắng thừa của wc
                    count=${count:-0}

                    if [[ "$count" -eq 0 ]]; then
                        if [[ -s /tmp/find_err.txt ]]; then
                            gui_msg "Không tìm thấy kết quả.\n\nLỗi truy cập:\n$(head -3 /tmp/find_err.txt)"
                        else
                            gui_msg "Không tìm thấy kết quả nào thỏa mãn các tiêu chí."
                        fi
                    else
                        sed -i "1i=== Tim thay $count ket qua ===" /tmp/find_result.txt
                        gui_textbox /tmp/find_result.txt "Kết quả tìm kiếm ($count mục)"
                    fi
                fi
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
