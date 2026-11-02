# zsh 設定のエントリポイント（ZDOTDIR=~/.config/zsh、~/.zshenv で設定）
: ${XDG_CONFIG_HOME:=$HOME/.config} ${XDG_CACHE_HOME:=$HOME/.cache}
: ${XDG_DATA_HOME:=$HOME/.local/share} ${XDG_STATE_HOME:=$HOME/.local/state}
export XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME

for _f in $ZDOTDIR/conf.d/*.zsh(N); do
  source $_f
done
unset _f

# マシン固有の設定（リポジトリ管理外）
[[ -r $HOME/.zshrc.local ]] && source $HOME/.zshrc.local

# byobu-enable 相当: ~/.zshrc.local で DOTFILES_TMUX_AUTOSTART=1 にするとログイン時に tmux に入る
# （VS Code のターミナルと tmux の中では起動しない。F6 でデタッチすると端末も閉じる）
if [[ ${DOTFILES_TMUX_AUTOSTART:-0} == 1 && -z $TMUX && -o interactive && -t 1 \
      && $TERM_PROGRAM != vscode ]] && (( $+commands[tmux] )); then
  exec tmux new-session -A -s main
fi
true
