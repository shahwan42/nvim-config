-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.lazyvim_php_lsp = "intelephense"

-- LazyVim leaves `clipboard` empty over SSH, so plain `y` never reaches the host.
-- Over SSH (ssh, et, herdr --remote) sync both ways through OSC 52:
--   yank  -> host clipboard (OSC 52 write)
--   paste <- host clipboard (OSC 52 read), falling back to nvim's own register
--            when the terminal does not answer within 500ms. After one miss,
--            reads stop for the session so `p` never stalls again.
-- Locally (Mac) nvim keeps its native provider (pbcopy/pbpaste).
if vim.env.SSH_CONNECTION or vim.env.SSH_TTY then
  local osc52 = require("vim.ui.clipboard.osc52")
  local reads_work = true

  local function local_reg()
    return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
  end

  local function paste(reg)
    local target = reg == "+" and "c" or "p"
    return function()
      if not reads_work then
        return local_reg()
      end
      local contents
      local id = vim.api.nvim_create_autocmd("TermResponse", {
        callback = function(ev)
          local encoded = ev.data.sequence:match("\027%]52;%w?;([A-Za-z0-9+/=]*)")
          if encoded then
            contents = vim.base64.decode(encoded)
            return true
          end
        end,
      })
      vim.api.nvim_ui_send(string.format("\027]52;%s;?\027\\", target))
      if not vim.wait(500, function() return contents ~= nil end) then
        pcall(vim.api.nvim_del_autocmd, id)
        reads_work = false
        return local_reg()
      end
      -- Our own last yank: keep its register type (linewise stays linewise).
      if contents == (vim.fn.getreg(""):gsub("\n$", "")) then
        return local_reg()
      end
      return vim.split(contents, "\n")
    end
  end

  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste("+"), ["*"] = paste("*") },
  }
end
vim.opt.clipboard = "unnamedplus"
