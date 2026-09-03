local runtime = require("php.runtime")

return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= "phpcs" and tool ~= "php-cs-fixer"
      end, opts.ensure_installed or {})
      for _, tool in ipairs({ "blade-formatter", "php-debug-adapter" }) do
        if not vim.tbl_contains(opts.ensure_installed, tool) then
          opts.ensure_installed[#opts.ensure_installed + 1] = tool
        end
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = function(_, opts)
      opts.handlers = opts.handlers or {}
      opts.handlers.php = function() end
    end,
  },
  {
    "stevearc/conform.nvim",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "blade",
        callback = function(event)
          vim.b[event.buf].autoformat = false
        end,
        desc = "Keep Blade autoformat opt-in",
      })
    end,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.php = { "pint" }
      opts.formatters_by_ft.blade = { "blade-formatter" }
      opts.formatters = opts.formatters or {}
      opts.formatters.pint = {
        command = function(_, ctx)
          local root = runtime.root(ctx.filename)
          if not root then
            return "pint"
          end
          return runtime.is_sail(root) and root .. "/vendor/bin/sail" or root .. "/vendor/bin/pint"
        end,
        args = function(_, ctx)
          local root = runtime.root(ctx.filename)
          if runtime.is_sail(root) then
            return { "pint", "--quiet", assert(runtime.to_container(ctx.filename, root)) }
          end
          return { "--quiet", ctx.filename }
        end,
        cwd = function(_, ctx)
          return runtime.root(ctx.filename)
        end,
        condition = function(_, ctx)
          local root = runtime.root(ctx.filename)
          return root ~= nil and vim.uv.fs_stat(root .. "/vendor/bin/pint") ~= nil
        end,
        stdin = false,
      }
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.php = {}
    end,
  },
  {
    "nvim-neotest/neotest",
    dependencies = { "olimorris/neotest-phpunit" },
    keys = {
      {
        "<leader>tT",
        function()
          require("neotest").run.run({ suite = true })
        end,
        desc = "Run PHPUnit Suite",
      },
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      opts.adapters["neotest-pest"] = false
      opts.adapters["neotest-phpunit"] = false
      opts.adapters[#opts.adapters + 1] = require("php.neotest").adapter()
    end,
  },
  { "V13Axel/neotest-pest", enabled = false },
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")
      dap.configurations.php = {
        {
          type = "php",
          request = "launch",
          name = "Listen for Xdebug (Sail)",
          port = 9003,
          pathMappings = { ["/var/www/html"] = "${workspaceFolder}" },
        },
      }
    end,
  },
  {
    "folke/trouble.nvim",
    keys = {
      {
        "<leader>cq",
        function()
          require("php.phpstan").run()
        end,
        desc = "PHPStan Project",
      },
    },
    init = function()
      vim.api.nvim_create_user_command("PhpStan", function()
        require("lazy").load({ plugins = { "trouble.nvim" } })
        require("php.phpstan").run()
      end, { desc = "Run project-local PHPStan" })
    end,
  },
}
