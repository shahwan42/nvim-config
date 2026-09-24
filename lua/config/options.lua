-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.lazyvim_php_lsp = "intelephense"

-- LazyVim leaves `clipboard` empty over SSH, so plain `y` never reaches the host.
-- Sync yanks to "+ and copy via OSC 52 (works through ssh, et, and herdr --remote).
-- Paste reads the local register: OSC 52 reads are blocked or hang in most terminals.
if vim.env.SSH_CONNECTION or vim.env.SSH_TTY then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function paste()
    return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
  end
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste, ["*"] = paste },
  }
end
vim.opt.clipboard = "unnamedplus"
