#!/bin/bash
set -e

SETUP_SRC="rime-cangJie5_advanced/Setup"

# ─────────────────────────
# 🧠 系統偵測
# ─────────────────────────
detect_system()
{
	OS="$(. /etc/os-release; echo $ID)"
	DE="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"
	SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"

	echo "🔍 偵測系統資訊："
	echo "- 發行版本：$OS"
	echo "- 桌面環境：$DE"
	echo "- 顯示協議：$SESSION_TYPE"
}

# ─────────────────────────
# 🔧 Backup
# ─────────────────────────
backup_path()
{
	local target="$1"
	[[ ! -e "$target" ]] && return
	local bak="${target}.bak.$(date +%s)"
	cp -r "$target" "$bak"
	echo "🧷 已備份 $target → $bak"
}

# ─────────────────────────
# 📥 套件
# ─────────────────────────
install_packages()
{
	case "$OS" in
		fedora) CMD="sudo dnf install -y --refresh" ;;
		arch*) CMD="sudo pacman -S --noconfirm" ;;
		ubuntu*) CMD="sudo apt install -y" ;;
		*) echo "❌ 不支援系統"; exit 1 ;;
	esac

	$CMD fcitx5 fcitx5-rime fcitx5-configtool git
}

# ─────────────────────────
# 🛠️ Rime 方案
# ─────────────────────────
install_scheme()
{
	rm -rf /tmp/fcitx5_rime_setup
	git clone https://github.com/Ramen-LadyHKG/rime-cangJie5_advanced.git /tmp/fcitx5_rime_setup
	sudo cp -r /tmp/fcitx5_rime_setup/. /usr/share/rime-data/
}

# ─────────────────────────
# 🧩 GNOME Kimpanel
# ─────────────────────────
install_kimpanel()
{
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
handle_kde_virtual_keyboard()
{
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
# 🎨 Deploy fcitx5 config
# ─────────────────────────
deploy_fcitx5_configs()
{
	read -rp "安裝範圍：(1) 此用戶 (2) 所有用戶？[1/2] " scope

	USER_CFG="$HOME/.config/fcitx5"
	USER_SHARE="$HOME/.local/share/fcitx5"

	backup_path "$USER_CFG"
	backup_path "$USER_SHARE"

	cp -r "$SETUP_SRC/.config/fcitx5" "$HOME/.config/"
	cp -r "$SETUP_SRC/.local/share/fcitx5" "$HOME/.local/share/"

	if [[ "$scope" == "2" ]]; then
		if [[ -d "$USER_CFG" ]]; then
			sudo mkdir -p /etc/skel/.config /etc/skel/.local/share
			sudo cp -r "$USER_CFG" /etc/skel/.config/
			sudo cp -r "$USER_SHARE" /etc/skel/.local/share/
		fi
	fi
}

# ─────────────────────────
# 🔤 PingFang 字體
# ─────────────────────────
install_pingfang_font()
{
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
main()
{
	clear
	echo "🎉 Fcitx5 全自動安裝器"

	detect_system
	read -rp "是否繼續？[Y/N] " && [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0

	install_packages
	install_scheme
	install_kimpanel
	deploy_fcitx5_configs
	handle_kde_virtual_keyboard
	install_pingfang_font

	echo "✅ 完成，請登出或重新啟動"
}

main

