#!/bin/sh
# tmux ステータスバー用のシステム情報（byobu の status 表示の代わり）
case $1 in
  load)
    read -r l1 l5 l15 _ </proc/loadavg
    printf '%s %s %s' "$l1" "$l5" "$l15"
    ;;
  mem)
    awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2}
         END {printf "%.1f/%.1fG", (t-a)/1048576, t/1048576}' /proc/meminfo
    ;;
esac
