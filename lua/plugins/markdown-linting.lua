return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters = opts.linters or {}
      opts.linters["markdownlint-cli2"] = {
        args = { "--config", vim.fn.expand("~/.config/nvim/.markdownlint-cli2.jsonc"), "--" },
      }
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters.markdownlint_cli2 = {
        args = { "--config", vim.fn.expand("~/.config/nvim/.markdownlint-cli2.jsonc"), "--" },
      }
    end,
  },
}
