-- クリップボード
--  コピー: OSC 52（端末経由。WSL / SSH / tmux のどこでも動き、日本語も化けない）
--  貼り付け: WSL では PowerShell の Get-Clipboard、それ以外は最後にヤンクした内容
--           （端末からの貼り付けは Ctrl+Shift+V / 右クリックでも可）
local osc52 = require("vim.ui.clipboard.osc52")

local function paste_from_register()
  return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
end

local paste = paste_from_register
if vim.fn.has("wsl") == 1 then
  local ps = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
  if vim.fn.executable(ps) == 1 then
    paste = {
      ps, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command",
      '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; [Console]::Out.Write((Get-Clipboard -Raw).ToString().Replace("`r", ""))',
    }
  end
elseif not vim.env.SSH_TTY and (vim.env.WAYLAND_DISPLAY or vim.env.DISPLAY) then
  -- ネイティブ Ubuntu のデスクトップでは Neovim の自動検出（wl-copy / xclip 等）に任せる
  return
end

vim.g.clipboard = {
  name = "osc52+",
  copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
  paste = { ["+"] = paste, ["*"] = paste },
}
