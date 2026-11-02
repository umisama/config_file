#!/bin/sh
# tmux の @broadcast に入ったコマンドを複数のペインに送る（byobu の Ctrl-F9 / Shift-F9 相当）
# usage: broadcast.sh windows SESSION_ID | panes WINDOW_ID
#   windows: セッション内の全ウィンドウ（各ウィンドウのアクティブペイン）
#   panes  : ウィンドウ内の全ペイン
cmd=$(tmux show -gv @broadcast)
[ -n "$cmd" ] || exit 0
case $1 in
  windows) targets=$(tmux list-windows -t "$2" -F '#{pane_id}') ;;
  panes)   targets=$(tmux list-panes -t "$2" -F '#{pane_id}') ;;
  *) exit 1 ;;
esac
for t in $targets; do
  tmux send-keys -t "$t" -l -- "$cmd"
  tmux send-keys -t "$t" Enter
done
tmux set -gu @broadcast
