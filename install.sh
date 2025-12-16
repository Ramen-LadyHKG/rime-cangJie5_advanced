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
    echo "🎉 Fcitx5 中文輸入法快速安裝器"
    echo "────────────────────────────────────────"
    echo "🔍 偵測系統資訊："
    echo "- 發行版本: $OS"
    echo "- 桌面環境: $DE"
    echo "- 顯示協議: $SESSION_TYPE"

    read -rp "是否繼續安裝？[Y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 0
}

# ─────────────────────────
# 🔧 備份函數
# ─────────────────────────
backup_path() {
    local target="$1"
    [[ ! -e "$target" ]] && return
    local bak="${target}.bak.$(date +%s)"
    cp -r "$target" "$bak"
    echo "🧷 已備份 $target → $bak"
}

# ─────────────────────────
# 📥 套件安裝
# ─────────────────────────
install_packages() {
    echo "📦 安裝必要套件..."
    case "$OS" in
        arch*|cachy*|endervous*) CMD="sudo pacman -S --noconfirm" ;;
        ubuntu*|debian*|linuxmint*) CMD="sudo apt install -y" ;;
        fedora*|nobara*) CMD="sudo dnf install -y --refresh" ;;
        *) echo "❌ 不支援系統"; exit 1 ;;
    esac
    $CMD fcitx5 fcitx5-rime fcitx5-configtool git python3 python3-pip
}

# ─────────────────────────
# 🔤 PingFang 字體
# ─────────────────────────
install_pingfang_font() {
    echo "🔤 安裝 PingFang 字體..."
    tmp="/tmp/pingfang"
    rm -rf "$tmp"
    git clone https://github.com/witt-bit/applePingFangFonts.git "$tmp"
    sudo mkdir -p /usr/share/fonts/pingFang
    sudo cp -rf "$tmp/pingFang/." /usr/share/fonts/pingFang/
    sudo fc-cache -fv
}

# ─────────────────────────
# 🛠️ 部署輸入法方案
# ─────────────────────────
select_and_deploy_scheme() {
    echo "請選擇要安裝的輸入法方案（可多選，以空格分隔）："
    echo "1) 倉頡"
    echo "2) 傳統速成"
    echo "3) 進階速成"
    echo "4) 粵語拼音"
    echo "5) 混打"
    echo "6) 全要"
    read -rp "你的選擇：" choices

    SCHEMAS=()
    for c in $choices; do
        case $c in
            1) SCHEMAS+=("cangjie5") ;;
            2) SCHEMAS+=("ms_quick") ;;
            3) SCHEMAS+=("cangjie5_advanced") ;;
            4) SCHEMAS+=("jyut6ping3") ;;
            5) SCHEMAS+=("cangjie5_advanced") ;;  # 混打視乎ladyhkg
            6) SCHEMAS=("cangjie5" "ms_quick" "cangjie5_advanced" "jyut6ping3" "quick5") ;;
        esac
    done

    echo "📝 部署輸入法設定..."
    USER_CFG="$HOME/.config/fcitx5"
    USER_SHARE="$HOME/.local/share/fcitx5"
    backup_path "$USER_CFG"
    backup_path "$USER_SHARE"
    mkdir -p "$USER_CFG" "$USER_SHARE"

    # Copy Setup 設定
    cp -r "$SETUP_SRC/.config/fcitx5/." "$USER_CFG/"
    cp -r "$SETUP_SRC/.local/share/fcitx5/." "$USER_SHARE/"

    # 修改 default.yaml 啟用選擇嘅 schema
    DEFAULT_YAML="$USER_SHARE/rime/default.yaml"
    [[ ! -f "$DEFAULT_YAML" ]] && touch "$DEFAULT_YAML"
    echo "schema_list:" > "$DEFAULT_YAML"
    for s in "${SCHEMAS[@]}"; do
        echo "  - schema: $s" >> "$DEFAULT_YAML"
    done
}

# ─────────────────────────
# 🧩 GNOME Kimpanel
# ─────────────────────────
install_kimpanel() {
    [[ "$DE" != *GNOME* || "$SESSION_TYPE" != "wayland" ]] && return
    echo "🧩 安裝 GNOME Kimpanel..."
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
# 🚀 自動啟動設定
# ─────────────────────────
setup_autostart() {
    echo "🚀 設定自動啟動 Fcitx5..."
    AUTOSTART="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART"
    ln -sf /usr/bin/fcitx5 "$AUTOSTART/fcitx5.desktop"
}

# ─────────────────────────
# 🎛️ 主流程
# ─────────────────────────
main() {
    clear
    detect_system
    install_packages
    select_and_deploy_scheme
    install_kimpanel
    handle_kde_virtual_keyboard
    setup_autostart
    install_pingfang_font

    # X11/Wayland 環境變數
    echo "🌐 設定環境變數..."
    if [[ "$SESSION_TYPE" == "x11" ]]; then
        ENV_FILE="$HOME/.pam_environment"
    else
        ENV_FILE="/etc/environment"
    fi
    echo "GTK_IM_MODULE DEFAULT=fcitx" | sudo tee -a "$ENV_FILE"
    echo "QT_IM_MODULE DEFAULT=fcitx" | sudo tee -a "$ENV_FILE"
    echo "XMODIFIERS DEFAULT=@im=fcitx" | sudo tee -a "$ENV_FILE"
    echo "SDL_IM_MODULE DEFAULT=fcitx" | sudo tee -a "$ENV_FILE"

    echo "✅ 安裝完成，請登出或重新啟動以生效"
}

main

