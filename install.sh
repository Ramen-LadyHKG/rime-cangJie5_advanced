#!/bin/bash
set -e

ROOT_DIR="$(pwd)"
SETUP_DIR="$ROOT_DIR/Setup"

# ─────────────────────────
# 🖨️ UI helper
# ─────────────────────────
print_step()
{
	echo
	echo "────────────────────────────────────────"
	echo "$1"
	echo "────────────────────────────────────────"
}

# ─────────────────────────
# 🧠 系統偵測
# ─────────────────────────
detect_system()
{
	print_step "🔍 偵測系統環境"

	OS="$(. /etc/os-release; echo $ID)"
	DE="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"
	SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"

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
# 📦 套件
# ─────────────────────────
install_packages()
{
	print_step "📦 安裝 fcitx5 / rime 套件"

	case "$OS" in
		fedora) CMD="sudo dnf install -y --refresh" ;;
		arch*) CMD="sudo pacman -S --noconfirm" ;;
		ubuntu*) CMD="sudo apt install -y" ;;
		*) echo "❌ 不支援系統"; exit 1 ;;
	esac

	$CMD fcitx5 fcitx5-rime fcitx5-configtool git
}

# ─────────────────────────
# 🛠️ 安裝 Rime Data
# ─────────────────────────
install_rime_data()
{
	print_step "🛠️ 安裝 Rime 詞庫與 Schema"

	sudo cp -v *.yaml /usr/share/rime-data/
	sudo cp -rv opencc /usr/share/rime-data/ || true
}

# ─────────────────────────
# ⌨️ 選擇輸入法
# ─────────────────────────
select_input_methods()
{
	print_step "⌨️ 選擇要啟用嘅輸入法"

	echo "可選輸入法（可多選，用空格分隔）："
	echo "1) 倉頡五代"
	echo "2) 倉頡五代（進階）"
	echo "3) 速成"
	echo "4) 粵拼"

	read -rp "請輸入編號: " choices

	RIME_CFG="$HOME/.local/share/fcitx5/rime"
	mkdir -p "$RIME_CFG"
	backup_path "$RIME_CFG/default.custom.yaml"

	{
		echo "patch:"
		echo "  schema_list:"
		for c in $choices; do
			case "$c" in
				1) echo "    - schema: cangjie5" ;;
				2) echo "    - schema: cangjie5_advanced" ;;
				3) echo "    - schema: ms_quick" ;;
				4) echo "    - schema: jyut6ping3" ;;
			esac
		done
	} > "$RIME_CFG/default.custom.yaml"

	echo "✅ 已設定輸入法列表"
}

# ─────────────────────────
# 🎨 Deploy fcitx5 config
# ─────────────────────────
deploy_fcitx5_configs()
{
	print_step "🎨 部署 fcitx5 設定與主題"

	read -rp "安裝範圍：(1) 此用戶 (2) 所有用戶？[1/2] " scope

	USER_CFG="$HOME/.config/fcitx5"
	USER_SHARE="$HOME/.local/share/fcitx5"

	backup_path "$USER_CFG"
	backup_path "$USER_SHARE"

	cp -r "$SETUP_DIR/.config/fcitx5" "$HOME/.config/"
	cp -r "$SETUP_DIR/.local/share/fcitx5" "$HOME/.local/share/"

	if [[ "$scope" == "2" ]]; then
		sudo mkdir -p /etc/skel/.config /etc/skel/.local/share
		sudo cp -r "$HOME/.config/fcitx5" /etc/skel/.config/
		sudo cp -r "$HOME/.local/share/fcitx5" /etc/skel/.local/share/
	fi
}

# ─────────────────────────
# 🔤 PingFang 字體
# ─────────────────────────
install_pingfang_font()
{
	print_step "🔤 安裝 PingFang 字體"

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
	echo "🎉 Fcitx5 + Rime（倉頡／粵拼）安裝器"

	detect_system
	read -rp "是否繼續？[Y/N] " && [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0

	install_packages
	install_rime_data
	select_input_methods
	deploy_fcitx5_configs
	install_pingfang_font

	print_step "✅ 安裝完成"
	echo "請重新登入或重啟系統"
}

main

