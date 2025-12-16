#!/bin/bash
set -e

SETUP_SRC="$(pwd)/Setup"

# ─────────────────────────
# 🧠 系統偵測
# ─────────────────────────
detect_system() {
    OS="$(. /etc/os-release; echo $ID)"
    DE="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"
    SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"

    echo "────────────────────────────────────────"
    echo "🎉 Fcitx5 全自動安裝器"
    echo "────────────────────────────────────────"
    echo "🔍 偵測系統資訊："
    echo "- 發行版本：$OS"
    echo "- 桌面環境：$DE"
    echo "- 顯示協議：$SESSION_TYPE"
    read -rp "是否繼續安裝？[Y/N] " && [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0
}

# ─────────────────────────
# 🔧 備份路徑
# ─────────────────────────
backup_path() {
    local target="$1"
    [[ ! -e "$target" ]] && return
    local bak="${target}.bak.$(date +%s)"
    cp -r "$target" "$bak"
    echo "🧷 已備份 $target → $bak"
}

# ─────────────────────────
# 📥 安裝套件
# ─────────────────────────
install_packages() {
    echo "📦 安裝必要套件"
    case "$OS" in
        arch*|cachyos|endevour*) CMD="sudo pacman -S --noconfirm" ;;
        fedora|nobara*) CMD="sudo dnf install -y --refresh" ;;
        ubuntu*|debian*|linuxmint*) CMD="sudo apt install -y" ;;
        *) echo "❌ 不支援系統 ($OS)"; exit 1 ;;
    esac

    $CMD fcitx5 fcitx5-rime fcitx5-configtool git python3 python3-pip
}

# ─────────────────────────
# 🛠️ 選擇輸入法方案
# ─────────────────────────
select_rime_scheme() {
    echo "請選擇要安裝的輸入法方案（可多選，以空格分隔）："
    echo "1) 倉頡"
    echo "2) 傳統速成"
    echo "3) 進階速成"
    echo "4) 粵語拼音"
    echo "5) 混打"
    read -rp "你的選擇：" input_choices

    SUGGESTED=()
    for choice in $input_choices; do
        case $choice in
            1) SUGGESTED+=("ladyhkg" "tableextra") ;;
            2) SUGGESTED+=("msquick" "tableextra") ;;
            3) SUGGESTED+=("jackchan" "ladyhkg" "tableextra") ;;
            4) SUGGESTED+=("jackchan" "ladyhkg" "tableextra") ;;
            5) SUGGESTED+=("ladyhkg" "jackchan") ;;
        esac
    done

    echo "推薦方案如下："
    echo "$(printf ' - %s\n' "${SUGGESTED[@]}" | sort -u)"
    read -rp "請選擇你想安裝的方案（輸入關鍵字，如 jackchan）：" FINAL_SCHEME
}

# ─────────────────────────
# 🛠️ 部署 Fcitx5 設定
# ─────────────────────────
deploy_fcitx5_configs() {
    echo "📂 部署 Fcitx5 設定與主題"
    read -rp "安裝範圍：(1) 此用戶 (2) 所有用戶？[1/2] " scope

    USER_CFG="$HOME/.config/fcitx5"
    USER_SHARE="$HOME/.local/share/fcitx5"

    backup_path "$USER_CFG"
    backup_path "$USER_SHARE"

    cp -r "$SETUP_SRC/.config/fcitx5/." "$USER_CFG/"
    cp -r "$SETUP_SRC/.local/share/fcitx5/." "$USER_SHARE/"

    # 如果安裝給所有用戶
    if [[ "$scope" == "2" ]]; then
        sudo mkdir -p /etc/skel/.config /etc/skel/.local/share
        sudo cp -r "$USER_CFG" /etc/skel/.config/
        sudo cp -r "$USER_SHARE" /etc/skel/.local/share/
    fi
}

# ─────────────────────────
# 🔄 設定自動啟動
# ─────────────────────────
setup_autostart() {
    echo "🔄 設定 Fcitx5 自動啟動"
    read -rp "安裝範圍：(1) 此用戶 (2) 所有用戶？[1/2] " scope

    if [[ "$scope" == "2" ]]; then
        AUTOSTART_DIR="/etc/xdg/autostart"
        sudo mkdir -p "$AUTOSTART_DIR"
        FILE="$AUTOSTART_DIR/fcitx5.desktop"
        [[ -f "$FILE" ]] && sudo cp "$FILE" "${FILE}.bak.$(date +%s)"
        sudo tee "$FILE" >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=/usr/bin/fcitx5
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF
    else
        AUTOSTART_DIR="$HOME/.config/autostart"
        mkdir -p "$AUTOSTART_DIR"
        FILE="$AUTOSTART_DIR/fcitx5.desktop"
        [[ -f "$FILE" ]] && cp "$FILE" "${FILE}.bak.$(date +%s)"
        tee "$FILE" >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=/usr/bin/fcitx5
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF
    fi
}

# ─────────────────────────
# 🧩 GNOME Kimpanel
# ─────────────────────────
install_kimpanel() {
    [[ "$DE" != *GNOME* || "$SESSION_TYPE" != "wayland" ]] && return

    echo "🧩 安裝 GNOME Kimpanel"
    if ! command -v gext >/dev/null; then
        pip3 install --user --upgrade gnome-extensions-cli
        export PATH="$HOME/.local/bin:$PATH"
    fi

    gext install 261 || true
    gext enable kimpanel@kde.org || true
}

# ─────────────────────────
# 🧱 KDE Wayland Virtual Keyboard
# ─────────────────────────
handle_kde_virtual_keyboard() {
    [[ "$DE" != *KDE* || "$SESSION_TYPE" != "wayland" ]] && return

    echo "🧱 設定 KDE Wayland 虛擬鍵盤"
    kwinrc="$HOME/.config/kwinrc"
    mkdir -p "$(dirname "$kwinrc")"
    touch "$kwinrc"

    if grep -q "VirtualKeyboard" "$kwinrc"; then
        read -rp "⚠️ 已設定 VirtualKeyboard，要改成 fcitx5-wayland？[Y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || return
    fi

    backup_path "$kwinrc"

    cat >> "$kwinrc" <<EOF

[Wayland]
VirtualKeyboard=fcitx5-wayland
EOF
}

# ─────────────────────────
# 🔤 安裝 PingFang 字體
# ─────────────────────────
install_pingfang_font() {
    echo "🔤 安裝 PingFang 字體"
    tmp="/tmp/pingfang"
    rm -rf "$tmp"
    git clone https://github.com/witt-bit/applePingFangFonts.git "$tmp"
    sudo mkdir -p /usr/share/fonts/pingFang
    sudo cp -rf "$tmp/pingFang/." /usr/share/fonts/pingFang/
    sudo fc-cache -fv
}

# ─────────────────────────
# 🎛️ 主流程
# ─────────────────────────
main() {
    clear
    detect_system
    install_packages
    select_rime_scheme
    deploy_fcitx5_configs
    setup_autostart
    install_kimpanel
    handle_kde_virtual_keyboard
    install_pingfang_font

    echo "✅ 完成安裝，請登出或重新啟動"
}

main

