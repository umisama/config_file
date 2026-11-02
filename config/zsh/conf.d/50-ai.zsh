# Claude Code / Codex
# Claude: Shift+Tab の切替に Bypass Permissions を加える（起動時は通常の確認ありモード）
(( $+commands[claude] )) && alias claude='claude --allow-dangerously-skip-permissions'
# 最初から確認なし・全権限で起動したいとき
alias claude-yolo='command claude --dangerously-skip-permissions'
alias codex-yolo='codex --dangerously-bypass-approvals-and-sandbox'
