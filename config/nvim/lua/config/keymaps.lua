local map = vim.keymap.set

-- GUI 風のコピー & ペースト（旧設定を踏襲。矩形選択は <C-q> を使う）
map("x", "<C-c>", '"+y', { desc = "クリップボードへコピー" })
map("n", "<C-v>", '"+p', { desc = "クリップボードから貼り付け" })
map("x", "<C-v>", '"+P', { desc = "選択範囲をクリップボードで置換" })
map("i", "<C-v>", "<C-r><C-o>+", { desc = "クリップボードから貼り付け" })
map("c", "<C-v>", "<C-r>+")

-- タブ移動
map("n", "t", "gt")
map("n", "T", "gT")
map("n", "<C-Tab>", "gt")
map("n", "<C-S-Tab>", "gT")

-- 挿入モードでのカーソル移動
map("i", "<C-h>", "<Left>")
map("i", "<C-j>", "<Down>")
map("i", "<C-k>", "<Up>")
map("i", "<C-l>", "<Right>")

-- マークへのジャンプ / 設定（F1-F4 ⇔ a-d）
for i, m in ipairs({ "a", "b", "c", "d" }) do
  map("n", "<F" .. i .. ">", "`" .. m, { desc = "マーク " .. m .. " へ" })
  map("n", "<C-F" .. i .. ">", "m" .. m, { desc = "マーク " .. m .. " を設定" })
end

-- 検索ハイライトを消す
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- 診断
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "診断を表示" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "診断を一覧" })
