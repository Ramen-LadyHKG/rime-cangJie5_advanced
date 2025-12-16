#!/bin/bash

set -e

# ─────────────────────────
# 🧠 系統偵測
# ─────────────────────────
detect_system()
{
	OS="$(. /etc/os-release; echo $ID)"
	DE="${XDG_CURRENT_DESKTOP:-$(echo $DESKTOP_SESSION)}"
	SESSION_TYPE="${XDG_SESSION_TYPE:-}"

	if [[ -z "$SESSION_TYPE" ]]; then
		SESSION_ID="$(loginctl | grep $(whoami) | head -n1 | awk '{print $1}')"
		if [[ -n "$SESSION_ID" ]]; then
			SESSION_TYPE="$(loginctl show-session "$SESSION_ID" -p Type 2>/dev/null | cut -d= -f2)"
		fi
	fi

	if [[ -z "$SESSION_TYPE" ]]; then
		echo "⚠️ 偵測不到顯示協議，預設為 x11"
		SESSION_TYPE="x11"
	fi

	echo "🔍 偵測系統資訊："
	echo "- 發行版本：$OS"
	echo "- 桌面環境：$DE"
	echo "- 顯示協議：$SESSION_TYPE"
}

# ─────────────────────────
# 🔧 備份原設定
# ─────────────────────────
backup_configs()
{
	BACKUP_DIR="$HOME/.fcitx5_backup_$(date +%s)"
	mkdir -p "$BACKUP_DIR"
	cp -r "$HOME/.config/fcitx5" "$BACKUP_DIR/" 2>/dev/null || true
	cp -r "$HOME/.local/share/fcitx5" "$BACKUP_DIR/" 2>/dev/null || true
	echo "✅ 已備份原設定至 $BACKUP_DIR"
}

# ─────────────────────────
# 📥 安裝所需套件
# ─────────────────────────
install_packages()
{
	case "$OS" in
		arch|manjaro|cachyos)
			PKG_RIME="fcitx5-rime fcitx5-configtool"
			PKG_TABLE="fcitx5-table-extra fcitx5-chinese-addons fcitx5-configtool"
			CMD="sudo pacman -S --noconfirm"
			;;
		ubuntu|debian|linuxmint|zorin|elementary)
			PKG_RIME="fcitx5-rime fcitx5-configtool"
			PKG_TABLE="fcitx5-table-extra fcitx5-chinese-addons fcitx5-configtool"
			CMD="sudo apt install -y"
			;;
		fedora)
			PKG_RIME="fcitx5-rime fcitx5-configtool"
			PKG_TABLE="fcitx5-table-extra fcitx5-chinese-addons fcitx5-configtool"
			CMD="sudo dnf install -y --refresh"
			;;
		opensuse*)
			PKG_RIME="fcitx5-rime fcitx5-configtool"
			PKG_TABLE="fcitx5-table-extra fcitx5-chinese-addons fcitx5-configtool"
			CMD="sudo zypper in -y"
			;;
		*)
			echo "❌ 不支援的發行版：$OS"
			exit 1
			;;
	esac
}

# ─────────────────────────
# 🛠️ 安裝輸入方案（可重複執行）
# ─────────────────────────
install_scheme()
{
	SCHEME_REPOS=()

	case "$1" in
		jackchan)
			SCHEME_REPOS+=("https://github.com/JACKCHAN000/Rime-Quick5-Setup.git")
			;;
		ladyhkg)
			SCHEME_REPOS+=("https://github.com/Ramen-LadyHKG/rime-cangJie5_advanced.git")
			;;
		msquick)
			SCHEME_REPOS+=("https://github.com/philipposkhos/rime-ms-quick")
			;;
		tableextra)
			$CMD $PKG_TABLE
			return
			;;
	esac

	$CMD $PKG_RIME

	# 每次都確保乾淨
	rm -rf /tmp/fcitx5_rime_setup
	mkdir -p /tmp/fcitx5_rime_setup
	cd /tmp/fcitx5_rime_setup

	for repo in "${SCHEME_REPOS[@]}"; do
		git clone "$repo"
		dirname="$(basename "$repo" .git)"
		sudo cp -r "$dirname/." /usr/share/rime-data/
	done
}

# ─────────────────────────
# 🚀 啟動與環境設定
# ─────────────────────────
configure_startup()
{
	: "${XDG_CONFIG_HOME:=$HOME/.config}"
	read -rp "你想安裝給 (1) 此用戶 還是 (2) 所有用戶？[1/2] " install_scope

	if [[ "$install_scope" == "2" ]]; then
		if [[ "$SESSION_TYPE" == "wayland" && "$DE" == *"GNOME"* ]]; then
			echo "🔗 GNOME Wayland 請手動裝 Kimpanel"
			sudo mkdir -p /etc/xdg/autostart
			sudo ln -sf "$(which fcitx5)" /etc/xdg/autostart/fcitx5.desktop
		elif [[ "$SESSION_TYPE" == "x11" ]]; then
			echo "GTK_IM_MODULE DEFAULT=fcitx" | sudo tee -a /etc/environment
			echo "QT_IM_MODULE DEFAULT=fcitx" | sudo tee -a /etc/environment
			echo "XMODIFIERS DEFAULT=@im=fcitx" | sudo tee -a /etc/environment
			echo "SDL_IM_MODULE DEFAULT=fcitx" | sudo tee -a /etc/environment
		fi
	else
		mkdir -p "$XDG_CONFIG_HOME/autostart"
		ln -sf "$(which fcitx5)" "$XDG_CONFIG_HOME/autostart/fcitx5.desktop"
	fi
}

# ─────────────────────────
# 🎛️ 主選單
# ─────────────────────────
main_menu()
{
	clear
	echo "────────────────────────────────────────"
	echo "🎉 歡迎使用 Fcitx5 中文輸入法快速安裝器"
	echo "────────────────────────────────────────"

	detect_system

	echo "⚠️  此工具會改寫輸入法設定"
	read -rp "是否繼續？ [Y/N] " confirm
	[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

	read -rp "以上資訊正確嗎？ [Y/N] " correct
	[[ "$correct" =~ ^[Yy]$ ]] || exit 0

	read -rp "將使用 $SESSION_TYPE 進行設定，是否繼續？ [Y/N] " proto
	[[ "$proto" =~ ^[Yy]$ ]] || exit 0

	echo "請選擇輸入法（可多選）："
	echo "1) 倉頡"
	echo "2) 傳統速成"
	echo "3) 進階速成"
	echo "4) 粵語拼音"
	echo "5) 混打"
	read -rp "你的選擇：" input_choices

	SUGGESTED=()
	for choice in $input_choices; do
		case "$choice" in
			1) SUGGESTED+=("ladyhkg" "tableextra") ;;
			2) SUGGESTED+=("msquick" "tableextra") ;;
			3|4) SUGGESTED+=("jackchan" "ladyhkg" "tableextra") ;;
			5) SUGGESTED+=("ladyhkg" "jackchan") ;;
		esac
	done

	echo "推薦方案："
	printf ' - %s\n' "${SUGGESTED[@]}" | sort -u

	read -rp "請輸入最終方案（如 ladyhkg）：" final_scheme

	backup_configs
	install_packages
	install_scheme "$final_scheme"
	configure_startup

	echo "✅ 安裝完成，請重新登入或執行 fcitx5-configtool"
}

main_menu

