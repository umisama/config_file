#!/usr/bin/env bash
# Claude Code / Codex のフックから呼ばれる通知スクリプト
# usage: ai-notify claude|codex   （フックの JSON を標準入力で受け取る）
#   WSL         : Windows のトースト通知
#   ネイティブ  : notify-send（あれば）
set -u
tool=${1:-ai}
input=$(cat)

# Codex の Stop フックは標準出力に JSON が必要（Claude は無視される）
[[ $tool == codex ]] && printf '{}\n'

# JSON から event / cwd / メッセージを取り出す（タブ区切り）
IFS=$'\t' read -r event cwd detail < <(/usr/bin/python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read() or "{}")
except Exception:
    d = {}
ev = d.get("hook_event_name", "")
if ev == "Stop":
    msg = (d.get("last_assistant_message") or "").strip().splitlines()
    detail = msg[0] if msg else ""
elif ev == "PermissionRequest":
    detail = (d.get("tool_input") or {}).get("description") or d.get("tool_name") or ""
else:
    detail = d.get("message") or ""
clean = lambda s: " ".join(str(s).split())[:120]
print(clean(ev), clean(d.get("cwd", "")), clean(detail), sep="\t")
' <<<"$input" 2>/dev/null)

case $tool in claude) name="Claude Code" ;; codex) name="Codex" ;; *) name=$tool ;; esac
project=${cwd:+ · ${cwd##*/}}
case ${event:-} in
  Stop) title="$name$project: 完了"; body=${detail:-作業が完了しました} ;;
  *)    title="$name$project: 確認待ち"; body=${detail:-確認が必要です} ;;
esac

notify_windows() {
  local ps=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
  local script=${BASH_SOURCE[0]}
  script=$(dirname "$(readlink -f "$script")")/toast.ps1
  [[ -x $ps && -r $script ]] || return 1
  # 文字列は環境変数（WSLENV）で渡し、スクリプトは -EncodedCommand で渡す（クォート問題を避ける）
  AI_NOTIFY_TITLE=$title AI_NOTIFY_BODY=$body \
  WSLENV=${WSLENV:+$WSLENV:}AI_NOTIFY_TITLE/u:AI_NOTIFY_BODY/u \
    "$ps" -NoProfile -NonInteractive -ExecutionPolicy Bypass \
      -EncodedCommand "$(iconv -f UTF-8 -t UTF-16LE "$script" | base64 -w0)" >/dev/null 2>&1
}

# 呼び出し元を待たせないようバックグラウンドで通知
(
  if [[ -n ${WSL_DISTRO_NAME:-} || -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
    cd /mnt/c 2>/dev/null; notify_windows
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send -a "$name" "$title" "$body"
  fi
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true
exit 0
