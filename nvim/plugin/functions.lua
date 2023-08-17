if vim.fn.has "mac" then
  -- Open Dictionary.app on mac systems
  function OpenDictionary(a)
    local word = ""
    if a ~= "" then
      word = a
    else
      word = vim.fn.shellescape(vim.fn.expand "<cword>")
    end
    os.execute("open dict://" .. word)
  end
  vim.api.nvim_create_user_command("Dict", [[lua OpenDictionary(<q-args>)]], {})
end
