return {
  -- ファジーファインダ（fzf / rg / fd を利用）
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "ファイル" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "grep" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<cr>", desc = "カーソル下の単語を grep" },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "バッファ" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>", desc = "最近のファイル" },
      { "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "ヘルプ" },
      { "<leader>fd", "<cmd>FzfLua diagnostics_document<cr>", desc = "診断" },
      { "<leader><leader>", "<cmd>FzfLua resume<cr>", desc = "前回の検索を再開" },
    },
    opts = {},
  },

  -- 括弧の自動補完（旧 vimrc の {} [] () マッピングの置き換え）
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },

  -- 単語ハイライト（旧設定を踏襲: <Space>m / <Space>M）
  {
    "t9md/vim-quickhl",
    keys = {
      { "<Space>m", "<Plug>(quickhl-manual-this)", mode = { "n", "x" }, desc = "単語をハイライト" },
      { "<Space>M", "<Plug>(quickhl-manual-reset)", mode = { "n", "x" }, desc = "ハイライトを解除" },
    },
  },

  -- 構文解析によるハイライト（main ブランチ。パーサのビルドに tree-sitter CLI が必要 → mise で導入）
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    cond = vim.fn.has("nvim-0.12") == 1,
    build = ":TSUpdate",
    config = function()
      local parsers = {
        "bash", "c", "css", "diff", "dockerfile", "go", "gomod", "html", "javascript", "json",
        "lua", "markdown", "markdown_inline", "python", "query", "toml", "tsx", "typescript",
        "vim", "vimdoc", "yaml",
      }
      require("nvim-treesitter").install(parsers)
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
        callback = function(ev)
          if pcall(vim.treesitter.start, ev.buf) then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
