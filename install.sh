#!/bin/bash
set -e

# ─────────────────────────
# 📌 設定變數
# ─────────────────────────
SETUP_SRC="$(pwd)"  # 假設執行時已在 rime-cangJie5_advanced 目錄
FCITX5_BIN="/usr/bin/fcitx5"

# ─────────────────────────
# 🧠 系統偵測
# ─────────────────────────
detect_system() {
    OS="$(. /etc/os-release; echo $ID)"
    DE="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"
    SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"

    echo "🔍 偵測系統資訊："
    echo "- 發行版本：$OS"
    echo "- 桌面環境：$DE"
    echo "- 顯示協議：$SESSION_TYPE"
}

# ─────────────────────────
# 🔧 備份
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
# 系統判斷
if [[ "$OS" == "linuxmint" ]] || [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
    CMD="sudo apt install -y"
elif [[ "$OS" == arch* ]]; then
    CMD="sudo pacman -S --noconfirm"
elif [[ "$OS" == fedora* ]] || [[ "$OS" == nobara* ]]; then
    CMD="sudo dnf install -y --refresh"
else
    echo "❌ 不支援系統"
    exit 1
fi

$CMD fcitx5 fcitx5-rime fcitx5-configtool git python3 python3-pip

}

# ─────────────────────────
# 🛠️ 部署 Rime schema
# ─────────────────────────
deploy_rime_scheme() {
    echo "🛠️ 選擇並部署 Rime 方案"
    echo "請選擇要安裝的輸入法方案（可多選，以空格分隔）："
    echo "1) 倉頡"
    echo "2) 傳統速成"
    echo "3) 進階速成"
    echo "4) 粵語拼音"
    echo "5) 混打"
    echo "6) 全部"
    read -rp "你的選擇：" input_choices

    declare -A SCHEMAS=(
        [1]="cangjie5"
        [2]="ms_quick"
        [3]="cangjie5_advanced"
        [4]="jyut6ping3"
        [5]="quick5"
    )

    schema_list=()
    if [[ " $input_choices " =~ "6" ]]; then
        schema_list=(cangjie5 ms_quick cangjie5_advanced jyut6ping3 quick5)
    else
        for choice in $input_choices; do
            [[ -n "${SCHEMAS[$choice]}" ]] && schema_list+=("${SCHEMAS[$choice]}")
        done
    fi

    echo "✅ 將部署以下 Rime schema："
    printf ' - %s\n' "${schema_list[@]}"

    FCITX5_RIME="$HOME/.local/share/fcitx5/rime"
    mkdir -p "$FCITX5_RIME"
    backup_path "$FCITX5_RIME"

    echo "📂 複製 Rime 所需檔案"
    cp -r "$SETUP_SRC"/*.yaml "$FCITX5_RIME/" 2>/dev/null || true
    cp -r "$SETUP_SRC"/opencc "$FCITX5_RIME/" 2>/dev/null || true
    cp -r "$SETUP_SRC"/symbols*.yaml "$FCITX5_RIME/" 2>/dev/null || true
    cp -r "$SETUP_SRC"/essay*.txt "$FCITX5_RIME/" 2>/dev/null || true
    cp -r "$SETUP_SRC"/default.yaml "$FCITX5_RIME/" 2>/dev/null || true

    DEFAULT_YAML="$FCITX5_RIME/default.yaml"
    backup_path "$DEFAULT_YAML"
    sed -i 's/^\s*-\s*schema:.*$/#&/' "$DEFAULT_YAML"
    for schema in "${schema_list[@]}"; do
        if grep -q "$schema" "$DEFAULT_YAML"; then
            sed -i "s|#\s*-\s*schema: $schema|  - schema: $schema|" "$DEFAULT_YAML"
        else
            echo "  - schema: $schema" >> "$DEFAULT_YAML"
        fi
    done

    # 複製 fcitx5 config
    echo "📂 複製 fcitx5 設定"
    backup_path "$HOME/.config/fcitx5"
    backup_path "$HOME/.local/share/fcitx5"
    cp -r "$SETUP_SRC/Setup/.config/fcitx5" "$HOME/.config/"
    cp -r "$SETUP_SRC/Setup/.local/share/fcitx5" "$HOME/.local/share/"

    # 如果選擇 all users
    read -rp "安裝範圍：(1) 此用戶 (2) 所有用戶？[1/2] " scope
    if [[ "$scope" == "2" ]]; then
        sudo mkdir -p /etc/skel/.config /etc/skel/.local/share
        sudo cp -r "$HOME/.config/fcitx5" /etc/skel/.config/
        sudo cp -r "$HOME/.local/share/fcitx5" /etc/skel/.local/share/
    fi
}

# ─────────────────────────
# 🧩 GNOME Kimpanel (Wayland)
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
# 🔤 PingFang 字體
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
# 🔄 Autostart
# ─────────────────────────
setup_autostart() {
    echo "🚀 設定 Fcitx5 自動啟動"
    if [[ ! -f "$HOME/.config/autostart/fcitx5.desktop" ]]; then
        mkdir -p "$HOME/.config/autostart"
        ln -sf "$FCITX5_BIN" "$HOME/.config/autostart/fcitx5.desktop"
    fi
}

# ─────────────────────────
# 🖥️ X11 / Wayland 環境變數
# ─────────────────────────
setup_env_vars() {
    echo "⚙️ 設定環境變數"
    if [[ "$SESSION_TYPE" == "x11" ]]; then
        ENV_FILE="$HOME/.pam_environment"
    else
        ENV_FILE="/etc/environment"
    fi
    echo "GTK_IM_MODULE DEFAULT=fcitx" | sudo tee -a "$ENV_FILE"
    echo "QT_IM_MODULE DEFAULT=fcitx" | sudo tee -a "$ENV_FILE"
    echo "XMODIFIERS DEFAULT=@im=fcitx" | sudo tee -a "$ENV_FILE"
    echo "SDL_IM_MODULE DEFAULT=fcitx" | sudo tee -a "$ENV_FILE"
}

# ─────────────────────────
# 🎛️ 主流程
# ─────────────────────────
main() {
    clear
    echo "🎉 Fcitx5 全自動安裝器"
    read -rp "是否繼續安裝？[Y/N] " && [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0

    detect_system
    install_packages
    deploy_rime_scheme
    install_kimpanel
    handle_kde_virtual_keyboard
    setup_autostart
    setup_env_vars
    install_pingfang_font

    echo "✅ 完成，請登出或重新啟動系統"
}

main

