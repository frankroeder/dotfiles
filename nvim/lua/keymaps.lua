local keymap  = require 'utils'.keymap

-- Center search result (zz) and open fold (zv)
keymap("n", "n", "nzzzv<CR>")
keymap("n", "N", "Nzzzv<CR>")
-- Don't yank to default register when changing something
keymap("n", "c", '"xc<CR>')
keymap("x", "c", '"xc<CR>')
-- Clear search ighlight
keymap("n", "<Leader><Space>", ":noh<CR>")
-- Toggle wrap mode
keymap("n", "<Leader>wr", ":set wrap!<CR>")
-- Fast save
keymap("n", "<Leader><Leader>", ":w<CR>")
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
-- " Disable ex mode shortcut
-- nmap Q <Nop>
keymap("n", "Q", "<nop>")
-- " [,* ] Search and replace the word under the cursor.
-- " current line
keymap("n", "<Leader>*", [[:s/\<<C-r><C-w>\>//g<Left><Left>]])
-- " all occurrences
keymap("n", "<Leader>**", [[:%s/\<<C-r><C-w>\>//g<Left><Left>]])
-- " w!! to save with sudo
keymap("c", "w!!", "execute 'silent! write !sudo tee % >/dev/null' <bar> edit!")
-- " replace word with text in register "0
keymap("n", "<Leader>pr", 'viw"0p')
-- " Switch CWD to the directory of the open buffer
-- map <Leader>cd :cd %:p:h<CR>:pwd<CR>
-- keymap("", "<Leader>cd", ":cd %:p:h<CR>:pwd<CR>")
-- " Close quickfix window (,qq)
keymap("", "<Leader>qq", ":cclose<CR>")
-- " List contents of all registers
-- nnoremap <silent> "" :registers<CR>
keymap("n", '""', ":registers<CR>")
-- " add semicolon at end of line
-- map <Leader>; g_a;<Esc>
keymap("", '<Leader>;', "g_a;<Esc>")
-- " tmux style shortcuts
keymap("n", '<C-W>%;', ":split<CR>")
keymap("n", '<C-W>";', ":vsplit<CR>")
-- " remain in visual mode after code shift
-- vnoremap < <gv
keymap("v", '<', "<gv")
keymap("v", '>', ">gv")
-- " Join lines and restore cursor location
keymap("n", 'J', "mjJ`j")
