-- LSP（Neovim 0.11 標準の vim.lsp.config / vim.lsp.enable）
-- サーバ本体は :Mason で入れる。mason-lspconfig が自動で enable する。
-- 既定キー: K ホバー / grn リネーム / gra コードアクション / grr 参照 / gri 実装 / gO シンボル / [d ]d 診断移動

vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = { border = "rounded" },
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
    },
  },
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("user_lsp", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then return end
    -- 組み込み補完（入力に合わせて自動表示。<C-y> 確定 / <C-n> <C-p> 選択）
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
    local map = function(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc }) end
    map("gd", vim.lsp.buf.definition, "定義へ")
    map("gD", vim.lsp.buf.declaration, "宣言へ")
    map("<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "フォーマット")
  end,
})
