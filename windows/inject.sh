#!/usr/bin/env bash
# windows/setup.ps1 から呼ばれる: Windows 側にあるこのリポジトリを WSL 内へコピー（注入）する
# usage: inject.sh SRC DEST   DEST が相対パスなら $HOME 基準。コピー先のパスを stdout に出力する
set -euo pipefail

src=$(cd "$1" && pwd -P)
dest=$2
[[ $dest == /* ]] || dest=$HOME/$dest
msg() { printf '    %s\n' "$*" >&2; }

# すでに WSL 内のリポジトリから実行している場合はコピーしない
if [[ -d $dest && $(cd "$dest" && pwd -P) == "$src" ]]; then
  msg "WSL 内のリポジトリをそのまま使います: $dest"
  printf '%s\n' "$dest"
  exit 0
fi

if [[ -e $dest || -L $dest ]]; then
  bk=$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)
  mkdir -p "$bk"
  mv "$dest" "$bk/"
  msg "既存の $dest を $bk/ に退避しました"
fi

mkdir -p "$(dirname "$dest")"
# /mnt/c 上のファイルは権限が 777 に見えるので引き継がず、改めて設定する
cp -R --no-preserve=mode,ownership "$src" "$dest"
chmod -R u=rwX,go=rX "$dest"
find "$dest" -path "$dest/.git" -prune -o -name '*.sh' -exec chmod +x {} +

# Windows 側の git 設定で改行が CRLF になっていた場合の保険（.ps1 / .cmd は除く）
grep -rlI --exclude-dir=.git --exclude='*.ps1' --exclude='*.cmd' $'\r' "$dest" \
  | xargs -r -d '\n' sed -i 's/\r$//' || true

msg "リポジトリを $dest にコピーしました"
printf '%s\n' "$dest"
