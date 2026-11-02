# 各ツールの初期化（入っているものだけ）
(( $+commands[mise] ))     && eval "$(mise activate zsh)"
(( $+commands[zoxide] ))   && eval "$(zoxide init zsh)"
(( $+commands[starship] )) && eval "$(starship init zsh)"

if (( $+commands[fzf] )); then
  source <(fzf --zsh)    # Ctrl-R: 履歴検索 / Ctrl-T: ファイル / Alt-C: cd
  if (( $+commands[fd] )); then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  fi
fi

[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
