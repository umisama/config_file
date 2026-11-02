local cmd = vim.api.nvim_create_user_command

-- :Grep word [path]  新しいタブで ripgrep 検索してロケーションリストを開く
cmd("Grep", function(opts)
  vim.cmd("tabnew")
  vim.cmd("silent lgrep! " .. opts.args)
  if #vim.fn.getloclist(0) == 0 then
    vim.cmd("tabclose")
    vim.notify("not found: " .. opts.args, vim.log.levels.WARN)
    return
  end
  vim.cmd("lopen")
end, { nargs = "+", complete = "file", desc = "ripgrep で検索" })

-- :GoRun [args]  現在のファイルを go run
cmd("GoRun", function(opts)
  vim.cmd("!go run " .. vim.fn.shellescape(vim.fn.expand("%")) .. " " .. opts.args)
end, { nargs = "*", desc = "go run %" })
