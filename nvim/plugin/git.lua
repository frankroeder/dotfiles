local keymap = require 'utils'.keymap

if vim.opt.diff:get() then
    keymap("n", "gdl", ":diffget LOCAL<CR>")
    keymap("n", "gdb", ":diffget BASE<CR>")
    keymap("n", "gdr", ":diffget REMOTE<CR>")
    keymap("n", "gq", ":wqa<CR>")
end
