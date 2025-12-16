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
	OS="$(. /etc/os-release; echo $ID)"
	DE="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"
	SESSION_TYPE="${XDG_SESSION_TYPE:-}"

	if [[ -z "$SESSION_TYPE" ]]; then
		SESSION_TYPE="x11"
	fi

	echo "🔍 偵測系統資訊："
	echo "- OS：$OS"
	echo "- 桌面環境：$DE"
	echo "- 顯示協議：$SESSION_TYPE"
}

# ─────────────────────────
# ❓ 使用者確認
# ─────────────────────────
confirm_continue()
{
	read -rp "以上資訊是否正確？是否繼續安裝？[Y/N] " ans
	[[ "$ans" =~ ^[Yy]$ ]] || exit 0
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
		ubuntu*|debian*) CMD="sudo apt install -y" ;;
		*) echo "❌ 不支援系統"; exit 1 ;;
	esac

	$CMD fcitx5 fcitx5-rime fcitx5-configtool git
}

# ─────────────────────────
# 🛠️ Rime data
# ─────────────────────────
install_rime_data()
{
	print_step "🛠️ 安裝 Rime schema / 詞庫"
	sudo cp -v *.yaml /usr/share/rime-data/
	sudo cp -rv opencc /usr/share/rime-data/ || true
}

# ─────────────────────────
# ⌨️ 選擇輸入法
# ─────────────────────────
select_input_methods()
{
	print_step "⌨️ 選擇要啟用嘅輸入法"

	echo "可多選（用空格分隔）："
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
}

# ─────────────────────────
# 🌍 環境變數（X11 / Wayland）
# ─────────────────────────
setup_env_vars()
{
	print_step "🌍 設定輸入法環境變數"

	read -rp "套用到：(1) 此用戶 (2) 全系統？[1/2] " scope

	if [[ "$scope" == "2" ]]; then
		for v in GTK QT XMODIFIERS SDL; do
			echo "${v}_IM_MODULE DEFAULT=fcitx" | sudo tee -a /etc/environment
		done
	else
		for v in GTK QT XMODIFIERS SDL; do
			echo "${v}_IM_MODULE DEFAULT=fcitx" >> "$HOME/.pam_environment"
		done
	fi
}

# ─────────────────────────
# 🧩 GNOME Kimpanel
# ─────────────────────────
install_kimpanel()
{
	[[ "$DE" != *GNOME* || "$SESSION_TYPE" != "wayland" ]] && return

	print_step "🧩 安裝 GNOME Kimpanel"

	if ! command -v gext >/dev/null; then
		if command -v pipx >/dev/null; then
			pipx install gnome-extensions-cli
		elif command -v pip3 >/dev/null; then
			pip3 install --user gnome-extensions-cli
			export PATH="$HOME/.local/bin:$PATH"
		else
			echo "⚠️ 找不到 pip / pipx，跳過 Kimpanel"
			return
		fi
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

	print_step "🧱 KDE Wayland Virtual Keyboard 設定"

	kwinrc="$HOME/.config/kwinrc"
	mkdir -p "$(dirname "$kwinrc")"
	touch "$kwinrc"

	if grep -q "VirtualKeyboard" "$kwinrc"; then
		read -rp "已存在 VirtualKeyboard，改為 fcitx5-wayland？[Y/N] " ans
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
	print_step "🎨 部署 fcitx5 設定 / theme"

	USER_CFG="$HOME/.config/fcitx5"
	USER_SHARE="$HOME/.local/share/fcitx5"

	backup_path "$USER_CFG"
	backup_path "$USER_SHARE"

	cp -r "$SETUP_DIR/.config/fcitx5" "$HOME/.config/"
	cp -r "$SETUP_DIR/.local/share/fcitx5" "$HOME/.local/share/"
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
	echo "🎉 Fcitx5 + Rime（倉頡 / 粵拼）安裝器"

	detect_system
	confirm_continue

	install_packages
	install_rime_data
	select_input_methods
	setup_env_vars
	install_kimpanel
	handle_kde_virtual_keyboard
	deploy_fcitx5_configs
	install_pingfang_font

	print_step "✅ 安裝完成，請登出或重新啟動"
}

main

