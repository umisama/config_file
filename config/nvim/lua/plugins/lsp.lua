return {
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    cmd = { "Mason", "LspInstall" },
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "neovim/nvim-lspconfig", -- 各サーバの既定設定（vim.lsp.config）を提供
    },
    opts = {
      -- 常に入れておくサーバ。その他は :Mason か :LspInstall で追加
      ensure_installed = { "lua_ls" },
    },
  },
}
