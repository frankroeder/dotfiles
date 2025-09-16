local uv_python_augroup = vim.api.nvim_create_augroup("UvPythonFiletype", { clear = true })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = uv_python_augroup,
  pattern = "*",
  callback = function()
    local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    if first_line == "#!/usr/bin/env -S uv run --script" then
    -- if first_line and first_line:match("^#!%s*(%S*/)?env%s+-S%s+uv%s+run%s+--script$") then
      vim.bo.filetype = "python"
    end
  end,
})
