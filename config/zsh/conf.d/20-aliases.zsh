if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --git --group-directories-first --time-style=long-iso'
  alias la='eza -la --git --group-directories-first --time-style=long-iso'
  alias lt='eza --tree --level=2'
else
  alias ls='ls --color=auto'
  alias ll='ls -lh'
  alias la='ls -lha'
fi

alias vi=nvim vim=nvim
alias g=git
# byobu のように既存セッション main に入る（なければ作る）
alias tm='tmux new-session -A -s main'
alias grep='grep --color=auto'
alias ..='cd ..' ...='cd ../..'

# カレントディレクトリを HTTP 配信
alias httpserver='python3 -m http.server 8000'
