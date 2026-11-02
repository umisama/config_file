-- Neovim 設定（0.12 以上を想定。mise で導入）
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.clipboard")
require("config.keymaps")
require("config.commands")
require("config.lsp")
require("config.lazy")
