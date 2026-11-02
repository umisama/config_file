# --- history ---
HISTFILE=$XDG_STATE_HOME/zsh/history
[[ -d ${HISTFILE:h} ]] || mkdir -p ${HISTFILE:h}
HISTSIZE=100000
SAVEHIST=100000
setopt extended_history share_history
setopt hist_ignore_all_dups hist_ignore_space hist_reduce_blanks hist_verify

# --- 操作 ---
setopt auto_cd auto_pushd pushd_ignore_dups pushd_silent
setopt interactive_comments no_beep no_flow_control
bindkey -e
# Ctrl-W で / 区切りごとに消す
WORDCHARS=${WORDCHARS//\/}
