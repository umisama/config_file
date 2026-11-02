local o = vim.opt

-- 表示
o.number = true
o.cursorline = true
o.signcolumn = "yes"
o.showtabline = 2
o.scrolloff = 4
o.splitright = true
o.splitbelow = true
o.mouse = "a"
o.termguicolors = true
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- 旧 vimrc のステータスライン:  [バッファ番号] フルパス [+][RO]   (行,列)
o.statusline = " [%n] %F %7(%m %r%) %= (%l,%c) "

-- インデント（旧設定を踏襲: タブ幅 2、タブ文字のまま）
o.tabstop = 2
o.shiftwidth = 2
o.expandtab = false

-- 検索
o.ignorecase = true
o.smartcase = true

-- バックアップ / swap / undo（すべて ~/.local/state/nvim 配下）
local state = vim.fn.stdpath("state")
o.backup = true
o.backupdir = state .. "/backup//"
vim.fn.mkdir(state .. "/backup", "p")
o.undofile = true

o.updatetime = 250
o.completeopt = { "menuone", "noselect", "popup" }

-- 検索は ripgrep（:grep / :Grep）
o.grepprg = "rg --vimgrep --smart-case"
o.grepformat = "%f:%l:%c:%m"

-- アクティブなウィンドウだけ cursorline（旧設定を踏襲）
local group = vim.api.nvim_create_augroup("user_options", { clear = true })
vim.api.nvim_create_autocmd("WinEnter", { group = group, callback = function() vim.wo.cursorline = true end })
vim.api.nvim_create_autocmd("WinLeave", { group = group, callback = function() vim.wo.cursorline = false end })
-- ヤンク範囲を一瞬ハイライト
vim.api.nvim_create_autocmd("TextYankPost", { group = group, callback = function() vim.hl.on_yank() end })
