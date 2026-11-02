#!/usr/bin/env bash
# dotfiles インストーラ（WSL2 / Ubuntu 専用）。何度実行しても同じ状態になる。
#
# 処理は 2 段階:
#   system : apt パッケージ、mise 本体、/etc/wsl.conf、ログインシェル（root 権限）
#   user   : 設定のリンク、mise のツール、git ユーザー情報、AI CLI（一般ユーザー）
# 普段は一般ユーザーで ./install.sh を実行すれば両方行う（system は sudo 経由）。
# Windows 側の windows/setup.ps1 からは、wsl -u root で --system-only、
# 続けて一般ユーザーで --user-only を実行する（sudo パスワード不要）。
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DOTFILES/lib/common.sh"

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

MODE=all
DO_PACKAGES=1
DO_AI=1
DO_VSCODE=1
TARGET_USER=${SUDO_USER:-${USER:-$(id -un)}}
# setup.ps1 に WSL の再起動が必要なことを伝える目印
RESTART_MARKER=/run/dotfiles-wsl-restart-required

usage() {
  cat <<EOF
Usage: $0 [options]
  -y, --yes          確認せずに進める（git の名前/メールは GIT_NAME / GIT_EMAIL から）
      --no-packages  パッケージ類は入れない（リンク・git 設定・wsl.conf のみ）
      --skip-ai      Claude Code / Codex CLI を入れない
      --skip-vscode  VS Code を入れない（ネイティブ Ubuntu のみ対象）
      --system-only  root 権限の作業だけ行う（root で実行するときに使う）
      --user-only    一般ユーザーの作業だけ行う（sudo を使わない）
      --for-user U   --system-only でログインシェルを変更する対象ユーザー
  -h, --help         このヘルプ
EOF
}

while (($#)); do
  case $1 in
    -y|--yes) ASSUME_YES=1 ;;
    --no-packages) DO_PACKAGES=0 ;;
    --skip-ai) DO_AI=0 ;;
    --skip-vscode) DO_VSCODE=0 ;;
    --system-only) MODE=system ;;
    --user-only) MODE=user ;;
    --for-user) TARGET_USER=${2:?--for-user にはユーザー名が必要です}; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "unknown option: $1" ;;
  esac
  shift
done

[[ $(uname -s) == Linux ]] || die "Linux (WSL2 / Ubuntu) 専用です"
if ((EUID == 0)) && [[ $MODE != system ]]; then
  die "root で実行するときは --system-only を指定してください（ユーザー設定は一般ユーザーで実行）"
fi

# ===========================================================================
# system: root 権限の作業
# ===========================================================================
install_apt_packages() {
  log "apt パッケージをインストール"
  local pkgs
  mapfile -t pkgs < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$DOTFILES/packages/apt.txt" | grep -v '^$')
  as_root apt-get update -qq
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}"
}

install_mise_package() {
  log "mise をインストール"
  if has mise; then
    info "導入済み"
    return 0
  fi
  local keyring=/etc/apt/keyrings/mise-archive-keyring.gpg
  as_root install -dm 755 /etc/apt/keyrings
  curl -fsSL https://mise.jdx.dev/gpg-key.pub | as_root gpg --dearmor --yes -o "$keyring"
  echo "deb [signed-by=$keyring arch=$(dpkg --print-architecture)] https://mise.jdx.dev/deb stable main" \
    | as_root tee /etc/apt/sources.list.d/mise.list >/dev/null
  as_root apt-get update -qq
  as_root apt-get install -y -qq mise
}

setup_wsl_conf() {
  log "/etc/wsl.conf を確認"
  local target=${WSL_CONF_PATH:-/etc/wsl.conf} current desired section line key val
  current=$([[ -r $target ]] && cat "$target" || true)
  desired=$current
  section=
  while IFS= read -r line; do
    line=${line%%#*}
    line=${line//[[:space:]]/}
    [[ -z $line ]] && continue
    if [[ $line =~ ^\[(.+)\]$ ]]; then
      section=${BASH_REMATCH[1]}
    else
      key=${line%%=*}
      val=${line#*=}
      desired=$(printf '%s\n' "$desired" | ini_set "$section" "$key" "$val")
    fi
  done <"$DOTFILES/wsl/wsl.conf"

  if [[ $desired == "$current" ]]; then
    info "変更なし"
    return 0
  fi
  diff -u --label "$target (現在)" --label "$target (変更後)" <(printf '%s\n' "$current") <(printf '%s\n' "$desired") || true
  if confirm "この内容で $target を更新しますか？"; then
    if [[ -w $target || ( ! -e $target && -w $(dirname "$target") ) ]]; then
      printf '%s\n' "$desired" >"$target"
    else
      printf '%s\n' "$desired" | as_root tee "$target" >/dev/null
    fi
    as_root touch "$RESTART_MARKER" 2>/dev/null || true
    warn "反映には WSL の再起動が必要です（windows/setup.ps1 なら最後に再起動を確認します）"
  fi
}

install_vscode_native() {
  log "VS Code"
  if has code; then
    info "導入済み"
    return 0
  fi
  local keyring=/etc/apt/keyrings/packages.microsoft.gpg
  as_root install -dm 755 /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | as_root gpg --dearmor --yes -o "$keyring"
  as_root tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: $keyring
EOF
  as_root apt-get update -qq
  as_root apt-get install -y -qq code
}

set_login_shell() {
  log "ログインシェル（$TARGET_USER）"
  local zsh_path current
  zsh_path=$(command -v zsh) || { warn "zsh が見つかりません"; return 0; }
  current=$(getent passwd "$TARGET_USER" | cut -d: -f7)
  if [[ $current == "$zsh_path" ]]; then
    info "既に zsh です"
  elif confirm "$TARGET_USER のログインシェルを $zsh_path に変更しますか？"; then
    as_root chsh -s "$zsh_path" "$TARGET_USER"
  fi
}

run_system() {
  if [[ $DO_PACKAGES == 1 ]]; then
    install_apt_packages
    install_mise_package
  fi
  if is_wsl; then setup_wsl_conf; fi
  if [[ $DO_PACKAGES == 1 ]]; then
    # WSL では VS Code は Windows 側（windows/setup.ps1）で入れる
    if ! is_wsl && [[ $DO_VSCODE == 1 ]]; then install_vscode_native; fi
    set_login_shell
  fi
}

# ===========================================================================
# user: 一般ユーザーの作業
# ===========================================================================
link_configs() {
  log "設定ファイルをリンク"
  link "$DOTFILES/home/.zshenv"           "$HOME/.zshenv"
  link "$DOTFILES/config/zsh"             "$XDG_CONFIG_HOME/zsh"
  link "$DOTFILES/config/nvim"            "$XDG_CONFIG_HOME/nvim"
  link "$DOTFILES/config/tmux"            "$XDG_CONFIG_HOME/tmux"
  link "$DOTFILES/config/mise"            "$XDG_CONFIG_HOME/mise"
  link "$DOTFILES/config/starship.toml"   "$XDG_CONFIG_HOME/starship.toml"
  # git はディレクトリごとではなくファイル単位（config.local をリポジトリに入れないため）
  link "$DOTFILES/config/git/config"      "$XDG_CONFIG_HOME/git/config"
  link "$DOTFILES/config/git/ignore"      "$XDG_CONFIG_HOME/git/ignore"

  # Ubuntu ではコマンド名が違うものを本来の名前で使えるようにする
  has fdfind && link "$(command -v fdfind)" "$HOME/.local/bin/fd"
  has batcat && link "$(command -v batcat)" "$HOME/.local/bin/bat"

  # 旧来の ~/.gitconfig があると XDG の設定より優先されるので退避する
  if [[ -e $HOME/.gitconfig || -L $HOME/.gitconfig ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$HOME/.gitconfig" "$BACKUP_DIR/.gitconfig"
    warn "~/.gitconfig を $BACKUP_DIR/.gitconfig に退避しました（設定は ~/.config/git/ に移行）"
  fi
  return 0
}

install_mise_tools() {
  log "mise でツールをインストール（config/mise/config.toml）"
  if ! has mise; then
    warn "mise がありません（system の作業が済んでいるか確認してください）"
    return 0
  fi
  mise trust --quiet "$DOTFILES/config/mise/config.toml" || true
  # --skip-ai のときは Codex を除外する
  local disable=
  [[ $DO_AI == 1 ]] || disable="npm:@openai/codex"
  # npm: バックエンド（Codex など）は node が先に必要
  MISE_DISABLE_TOOLS=$disable mise install node
  MISE_DISABLE_TOOLS=$disable mise install
}

setup_git_identity() {
  log "git のユーザー情報"
  local local_conf=$XDG_CONFIG_HOME/git/config.local
  local cur_name cur_email name email
  cur_name=$(git config --file "$local_conf" user.name 2>/dev/null || true)
  cur_email=$(git config --file "$local_conf" user.email 2>/dev/null || true)

  if [[ -n $cur_name && -n $cur_email ]]; then
    info "現在: $cur_name <$cur_email>"
    if [[ -z ${GIT_NAME:-}${GIT_EMAIL:-} ]] && { [[ $ASSUME_YES == 1 ]] || ! confirm "変更しますか？"; }; then
      return 0
    fi
  fi

  name=${GIT_NAME:-$(ask "  名前 (user.name)" "$cur_name")}
  email=${GIT_EMAIL:-$(ask "  メール (user.email)" "$cur_email")}
  if [[ -z $name || -z $email ]]; then
    warn "名前かメールが空なのでスキップしました（後で ./install.sh --no-packages で再設定できます）"
    return 0
  fi
  mkdir -p "$(dirname "$local_conf")"
  git config --file "$local_conf" user.name "$name"
  git config --file "$local_conf" user.email "$email"
  info "保存しました: $name <$email> → ${local_conf/#$HOME/\~}"
}

install_ai_clis() {
  log "Claude Code"
  if has claude || [[ -x $HOME/.local/bin/claude ]]; then
    info "導入済み（更新は claude 本体の自動更新に任せる）"
  else
    curl -fsSL https://claude.ai/install.sh | bash
  fi
  log "Codex CLI"
  if has mise && mise which codex >/dev/null 2>&1; then
    info "導入済み（mise 経由。更新は 'mise upgrade'）"
  else
    warn "codex が見つかりません。'mise install' の結果を確認してください"
  fi
}

reload_tmux() {
  # tmux はサーバー起動時にしか設定を読まないので、起動中なら読み直す
  if has tmux && tmux list-sessions >/dev/null 2>&1; then
    log "起動中の tmux に設定を再読み込み"
    tmux source-file "$XDG_CONFIG_HOME/tmux/tmux.conf" && info "反映しました" \
      || warn "再読み込みに失敗しました（tmux kill-server してから起動し直してください）"
  fi
  return 0
}

run_user() {
  link_configs
  [[ $DO_PACKAGES == 1 ]] && install_mise_tools
  setup_git_identity
  [[ $DO_PACKAGES == 1 && $DO_AI == 1 ]] && install_ai_clis
  if is_wsl && [[ $DO_PACKAGES == 1 && $DO_VSCODE == 1 ]] && ! has code; then
    info "VS Code は Windows 側で windows/setup.ps1 を実行すると入ります"
  fi
  reload_tmux
  return 0
}

# ===========================================================================
main() {
  case $MODE in
    system) run_system ;;
    user)   run_user ;;
    all)    run_system; run_user ;;
  esac
  log "完了（$MODE）"
  [[ $MODE == system ]] || info "新しいターミナルを開くか 'exec zsh -l' してください"
  [[ -d $BACKUP_DIR ]] && info "退避したファイル: $BACKUP_DIR"
  return 0
}

main
