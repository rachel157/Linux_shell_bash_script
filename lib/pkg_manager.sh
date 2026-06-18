#!/usr/bin/env bash
# ============================================================================
# pkg_manager.sh - Quản lý gói (GUI)
# ============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

detect_pkg_manager() {
    if command -v apt &>/dev/null; then PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then PKG_MGR="dnf"
    elif command -v yum &>/dev/null; then PKG_MGR="yum"
    else
        gui_msg "Không tìm thấy apt/yum/dnf"
        return 1
    fi
    return 0
}

pkg_manager_menu() {
    if ! detect_pkg_manager; then return; fi

    while true; do
        choice=$(gui_menu "📦 QUẢN LÝ GÓI ($PKG_MGR)" \
            "1" "Cài đặt một gói" \
            "2" "Gỡ bỏ một gói" \
            "3" "Kiểm tra thông tin gói" \
            "4" "Cài hàng loạt từ file" \
            "5" "Quay lại")

        case $choice in
            1)
                pkg=$(gui_input "Tên gói cần cài:" "")
                [[ -z "$pkg" ]] && continue
                case $PKG_MGR in
                    apt) sudo apt update && sudo apt install -y "$pkg" 2>&1 | tee /tmp/pkg_result.txt ;;
                    dnf) sudo dnf install -y "$pkg" 2>&1 | tee /tmp/pkg_result.txt ;;
                    yum) sudo yum install -y "$pkg" 2>&1 | tee /tmp/pkg_result.txt ;;
                esac
                gui_textbox /tmp/pkg_result.txt "Kết quả cài đặt"
                ;;
            2)
                pkg=$(gui_input "Tên gói cần gỡ:" "")
                [[ -z "$pkg" ]] && continue
                case $PKG_MGR in
                    apt) sudo apt remove -y "$pkg" 2>&1 | tee /tmp/pkg_result.txt ;;
                    dnf) sudo dnf remove -y "$pkg" 2>&1 | tee /tmp/pkg_result.txt ;;
                    yum) sudo yum remove -y "$pkg" 2>&1 | tee /tmp/pkg_result.txt ;;
                esac
                gui_textbox /tmp/pkg_result.txt "Kết quả gỡ bỏ"
                ;;
            3)
                pkg=$(gui_input "Tên gói:" "")
                [[ -z "$pkg" ]] && continue
                case $PKG_MGR in
                    apt) dpkg -l "$pkg" 2>/dev/null || apt-cache show "$pkg" 2>/dev/null ;;
                    dnf) dnf info "$pkg" 2>/dev/null ;;
                    yum) yum info "$pkg" 2>/dev/null ;;
                esac > /tmp/pkg_info.txt
                gui_textbox /tmp/pkg_info.txt "Thông tin gói"
                ;;
            4)
                if [[ ! -f "$PKG_LIST" ]]; then
                    echo -e "htop\nvim\ncurl" > "$PKG_LIST"
                fi
                if gui_yesno "Cài các gói từ $PKG_LIST?"; then
                    while read -r pkg; do
                        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
                        case $PKG_MGR in
                            apt) sudo apt install -y "$pkg" ;;
                            dnf) sudo dnf install -y "$pkg" ;;
                            yum) sudo yum install -y "$pkg" ;;
                        esac
                    done < "$PKG_LIST" 2>&1 | tee /tmp/pkg_batch.txt
                    gui_textbox /tmp/pkg_batch.txt "Kết quả cài hàng loạt"
                fi
                ;;
            5) break ;;
        esac
    done
}
