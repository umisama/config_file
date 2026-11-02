# WSL 専用設定。/etc/wsl.conf で appendWindowsPath=false にしているので
# 必要な Windows 側コマンドだけをここで通す
[[ -n $WSL_DISTRO_NAME ]] || return 0

() {
  local win=/mnt/c/Windows
  alias explorer="$win/explorer.exe"
  alias cmd="$win/System32/cmd.exe"
  alias powershell="$win/System32/WindowsPowerShell/v1.0/powershell.exe"
  alias clip="$win/System32/clip.exe"

  # %LOCALAPPDATA% は取得が遅いのでキャッシュする
  local cache=$XDG_CACHE_HOME/zsh/win-localappdata lad
  if [[ -s $cache ]]; then
    lad=$(<$cache)
  elif [[ -x $win/System32/cmd.exe ]]; then
    lad=$(cd /mnt/c && $win/System32/cmd.exe /d /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')
    [[ -n $lad && $lad != *%* ]] && lad=$(wslpath -u "$lad") && print -r -- $lad >| $cache
  fi
  if [[ -d $lad ]]; then
    # VS Code（code コマンド）と winget などの WindowsApps
    path+=("$lad/Programs/Microsoft VS Code/bin" "$lad/Microsoft/WindowsApps")
  fi
  [[ -d "/mnt/c/Program Files/Microsoft VS Code/bin" ]] && path+=("/mnt/c/Program Files/Microsoft VS Code/bin")
}

# Windows のエクスプローラ/既定アプリで開く（open . / open file.pdf / open URL）
open() {
  local target=${1:-.}
  [[ -e $target ]] && target=$(wslpath -w "$target")
  (cd /mnt/c && /mnt/c/Windows/explorer.exe "$target") || true
}
