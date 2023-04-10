vim.api.nvim_create_augroup("detect_filetype", { clear = true })
local augroup = {
  { { "BufReadPost", "BufNewFile" }, "Brewfile", "set filetype=ruby" },
  { { "BufReadPost", "BufNewFile" }, "*gitconfig", "set filetype=gitconfig" },
  { { "BufReadPost", "BufNewFile" }, "*.cls", "set filetype=tex" },
  { { "BufReadPost", "BufNewFile" }, "*.config", "set filetype=config" },
  { { "BufNewFile", "BufRead" }, "*.Dockerfile", "set filetype=dockerfile" },
}
for _, autocmd in ipairs(augroup) do
  vim.api.nvim_create_autocmd(autocmd[1], {
    pattern = autocmd[2],
    command = autocmd[3],
    group = "detect_filetype",
  })
end
