-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.lazyvim_php_lsp = "intelephense"

-- Herdr forwards OSC 52 writes from remote panes to the local client.
-- Use it explicitly so regular yanks also reach the desktop clipboard over SSH.
vim.g.clipboard = "osc52"
vim.opt.clipboard = "unnamedplus"
