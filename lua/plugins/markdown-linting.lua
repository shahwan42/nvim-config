return {
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters = opts.linters or {}
      opts.linters.markdownlint = {
        args = { "--disable", "MD013,MD041,MD033,MD045" },
      }
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      opts.formatters.markdownlint_cli2 = {
        args = { "--disable", "MD013,MD041,MD033,MD045" },
      }
    end,
  },
}
