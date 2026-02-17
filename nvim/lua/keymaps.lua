-- Don't yank to default register when changing something
vim.keymap.set("n", "c", [["xc]], { noremap = true })
vim.keymap.set("x", "c", [["xc]], { noremap = true })
-- Clear search highlight
vim.keymap.set("n", "<Leader><Space>", ":noh<CR>")
-- Toggle wrap mode
vim.keymap.set("n", "<Leader>wr", "", {
  silent = true,
  desc = "toggle wrap mode",
  callback = function()
    vim.cmd [[
			set wrap!
		]]
  end,
})
-- fast save
vim.keymap.set("n", "<Leader><Leader>", ":w<CR>", { noremap = true })
-- disable arrow keys in escape mode
vim.keymap.set("", "<Up>", "<nop>")
vim.keymap.set("", "<Down>", "<nop>")
vim.keymap.set("", "<Left>", "<nop>")
vim.keymap.set("", "<Right>", "<nop>")
-- Disable arrow keys in insert mode
vim.keymap.set("i", "<Up>", "<nop>")
vim.keymap.set("i", "<Down>", "<nop>")
vim.keymap.set("i", "<Left>", "<nop>")
vim.keymap.set("i", "<Right>", "<nop>")
-- Disable ex mode shortcut
vim.keymap.set("n", "Q", "<nop>")

-- [,* ] Search and replace the word under the cursor.
-- current line
vim.keymap.set("n", "<Leader>*", [[:s/\<<C-r><C-w>\>//g<Left><Left>]], { silent = false })
-- all occurrences
vim.keymap.set("n", "<Leader>**", [[:%s/\<<C-r><C-w>\>//g<Left><Left>]], { silent = false })

-- w!! to save with sudo
vim.keymap.set(
  "c",
  "w!!",
  [[execute 'silent! write !sudo tee % >/dev/null' <bar> edit!]],
  { noremap = true }
)

-- replace word with text in register "0
vim.keymap.set("n", "<Leader>pr", [[viw"0p]], { noremap = true })
-- Switch CWD to the directory of the open buffer
vim.keymap.set("", "<Leader>cd", ":cd %:p:h<CR>:pwd<CR>", {})
-- Close quickfix window (,qq)
vim.keymap.set("", "<Leader>qq", ":cclose<CR>", {})
-- List contents of all registers
vim.keymap.set("n", '""', ":registers<CR>")
-- add semicolon at end of line
vim.keymap.set("", "<Leader>;", "g_a;<Esc>", {})
-- remain in visual mode after code shift
vim.keymap.set("v", "<", "<gv", { noremap = true })
vim.keymap.set("v", ">", ">gv", { noremap = true })

-- buffers
vim.keymap.set("n", "<C-K>", [[:bnext<CR>]], { silent = false })
vim.keymap.set("n", "<C-J>", [[:bprevious<CR>]], { silent = false })
-- vim.keymap.set("n", "<C-C>", [[:bdelete<CR>]], { silent = false })
