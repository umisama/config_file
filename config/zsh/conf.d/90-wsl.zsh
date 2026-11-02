# WSL 専用設定
[[ -n $WSL_DISTRO_NAME ]] || return 0

# Windows のエクスプローラ/既定アプリで開く（open . / open file.pdf / open URL）
# ※ Ubuntu 標準の /usr/bin/open（xdg-open）より優先される。標準のものは command open で使える
open() {
  local target=${1:-.}
  [[ -e $target ]] && target=$(wslpath -w "$target")
  (cd /mnt/c && /mnt/c/Windows/explorer.exe "$target") || true
}
