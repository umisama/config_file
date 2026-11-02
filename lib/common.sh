# shellcheck shell=bash
# install.sh から source される共通関数

ASSUME_YES=${ASSUME_YES:-0}
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

is_wsl() { [[ -n ${WSL_DISTRO_NAME:-} || -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; }

# confirm "質問"  → yes なら 0。--yes 指定時は常に 0
confirm() {
  [[ $ASSUME_YES == 1 ]] && return 0
  local ans
  read -r -p "$1 [y/N] " ans </dev/tty || return 1
  [[ $ans =~ ^[Yy] ]]
}

# ask "質問" "既定値" → 入力値を stdout へ
ask() {
  local prompt=$1 default=${2:-} ans
  if [[ $ASSUME_YES == 1 ]]; then printf '%s' "$default"; return; fi
  read -r -p "$prompt${default:+ [$default]}: " ans </dev/tty
  printf '%s' "${ans:-$default}"
}

# link SRC DEST : DEST を SRC へのシンボリックリンクにする（冪等）
# 既存のファイル/別リンクは $BACKUP_DIR へ退避する
link() {
  local src=$1 dest=$2
  if [[ -L $dest && $(readlink "$dest") == "$src" ]]; then
    return 0
  fi
  if [[ -e $dest || -L $dest ]]; then
    local rel=${dest#"$HOME"/}
    mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
    mv "$dest" "$BACKUP_DIR/$rel"
    warn "既存の $dest を $BACKUP_DIR/$rel に退避しました"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  info "linked ${dest/#$HOME/\~} -> ${src/#$HOME/\~}"
}

# ini_set SECTION KEY VALUE : stdin の INI に値を設定して stdout へ（他の項目は保持）
ini_set() {
  awk -v sec="$1" -v key="$2" -v val="$3" '
    function emit() { print key "=" val; done = 1 }
    /^[ \t]*\[.*\][ \t]*$/ {
      if (insec && !done) emit()
      insec = ($0 == "[" sec "]")
      print; next
    }
    insec && $0 ~ "^[ \t]*" key "[ \t]*=" { if (!done) emit(); next }
    { print }
    END {
      if (!done) {
        if (!insec) { if (NR > 0) print ""; print "[" sec "]" }
        emit()
      }
    }'
}

# as_root CMD... : root ならそのまま、そうでなければ sudo で実行
as_root() {
  if ((EUID == 0)); then "$@"; else sudo "$@"; fi
}
