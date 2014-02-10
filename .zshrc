#####################################################################
#
#  Sample .zshrc file
#  initial setup file for only interactive zsh
#  This file is read after .zshenv file is read.
#
#####################################################################

# Set Shell variable
HISTSIZE=200 HISTFILE=~/.zhistory SAVEHIST=180
PROMPT='%m{%n}%% '
RPROMPT='[%~]'

# Set shell options
setopt auto_cd auto_remove_slash auto_name_dirs 
setopt extended_history hist_ignore_dups hist_ignore_space prompt_subst
setopt extended_glob list_types no_beep always_last_prompt
setopt cdable_vars sh_word_split auto_param_keys pushd_ignore_dups

# Alias and functions
alias copy='cp -ip' del='rm -i' move='mv -i'
alias fullreset='echo "\ec\ec"'
h () 		{history $* | less}
alias ja='LANG=ja_JP.eucJP XMODIFIERS=@im=kinput2'
alias ls='ls -F' la='ls -a' ll='ls -la'
mdcd ()		{mkdir -p "$@" && cd "$*[-1]"}
mdpu ()		{mkdir -p "$@" && pushd "$*[-1]"}
alias pu=pushd po=popd dirs='dirs -v'

# Suffix aliases
alias -s pdf=acroread dvi=xdvi 
alias -s {odt,ods,odp,doc,xls,ppt}=soffice
alias -s {tgz,lzh,zip,arc}=file-roller

# binding keys
bindkey -e

zstyle ':completion:*' format '%BCompleting %d%b'
zstyle ':completion:*' group-name ''
autoload -U compinit && compinit

# set color to terminal
nprom () {
    setopt prompt_subst
    local rbase=$'%{\e[33m%}[%%{\e[m%}' lf=$'\n'
    local pct=$'%0(?||%18(?||%{\e[31m%}))%#%{\e[m%}'
    RPROMPT="%9(~||$rbase)"
    case "$USER" in
      yatex)	PROMPT=$'%{\e[33m%}%U%m{%n}%%%{\e[m%}%u ' ;;
      java)	PROMPT=$'%{\e[36m%}%U%m{%n}%%%{\e[m%}%u ' ;;
      *)
    local pbase=$'%{\e[$[32+RANDOM%5]m%}%U%B%m{%n}%b'"$pct%u "
    PROMPT="%9(~|$rbase$lf|)$pbase"
    ;;
    esac
    [[ "$TERM" = "screen" ]] && RPROMPT="[%U%~%u]"
}
nprom

# golang
export GOROOT=/usr/local/go
export GOBIN=$GOROOT/bin
export GOPATH=/home/umisama/go
export PATH=$PATH:$GOBIN

byobu
