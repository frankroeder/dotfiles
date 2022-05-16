local keymap  = require 'utils'.keymap

-- Center search result (zz) and open fold (zv)
keymap("n", "n", "nzzzv", { noremap = true })
keymap("n", "N", "Nzzzv", { noremap = true })
-- Don't yank to default register when changing something
keymap("n", "c", [["xc]], { noremap = true })
keymap("x", "c", [["xc]], { noremap = true })
-- Clear search ighlight
keymap("n", "<Leader><Space>", ":noh<CR>")
-- Toggle wrap mode
keymap("n", "<Leader>wr", ":set wrap!<CR>", { noremap = true })
-- Fast save
keymap("n", "<Leader><Leader>", ":w<CR>", { noremap = true })
-- Disable Arrow keys in Escape mode
keymap("", "<Up>", "<nop>")
keymap("", "<Down>", "<nop>")
keymap("", "<Left>", "<nop>")
keymap("", "<Right>", "<nop>")
-- Disable Arrow keys in Insert mode
keymap("i", "<Up>", "<nop>")
keymap("i", "<Down>", "<nop>")
keymap("i", "<Left>", "<nop>")
keymap("i", "<Right>", "<nop>")
-- Disable ex mode shortcut
keymap("n", "Q", "<nop>")
-- [,* ] Search and replace the word under the cursor.
-- current line
keymap("n", "<Leader>*", [[:s/\<<C-r><C-w>\>//g<Left><Left>]], { silent = false })
-- all occurrences
keymap("n", "<Leader>**", [[:%s/\<<C-r><C-w>\>//g<Left><Left>]], { silent = false })
-- w!! to save with sudo
keymap("c", "w!!", [[execute 'silent! write !sudo tee % >/dev/null' <bar> edit!]], { noremap = true })
-- replace word with text in register "0
keymap("n", "<Leader>pr", [[viw"0p]], { noremap = true })
-- Switch CWD to the directory of the open buffer
keymap("", "<Leader>cd", ":cd %:p:h<CR>:pwd<CR>", {})
-- Close quickfix window (,qq)
keymap("", "<Leader>qq", ":cclose<CR>", {})
-- List contents of all registers
keymap("n", '""', ":registers<CR>")
-- add semicolon at end of line
keymap("", '<Leader>;', "g_a;<Esc>", {})
-- tmux style shortcuts
keymap("n", '<C-W>%', ":split<CR>", { noremap = true })
keymap("n", '<C-W>"', ":vsplit<CR>", { noremap = true })
-- remain in visual mode after code shift
keymap("v", '<', "<gv", { noremap = true })
keymap("v", '>', ">gv", { noremap = true })
-- Join lines and restore cursor location
keymap("n", 'J', "mjJ`j", { noremap = true })
