autoload -Uz compinit
() {
  local dump=$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION
  [[ -d ${dump:h} ]] || mkdir -p ${dump:h}
  # dump が24時間以内なら再検査を省略して起動を速くする
  local -a fresh=($dump(N.mh-24))
  if (( $#fresh )); then
    compinit -C -d $dump
  else
    compinit -d $dump
  fi
}

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path $XDG_CACHE_HOME/zsh/zcompcache
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
