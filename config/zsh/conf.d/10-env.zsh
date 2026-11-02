typeset -U path PATH
path=($HOME/.local/bin $path)

export EDITOR=nvim VISUAL=nvim
export PAGER=less LESS='-R -F -i -M'
export MANPAGER='nvim +Man!'
