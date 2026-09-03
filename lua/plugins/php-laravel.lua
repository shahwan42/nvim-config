local runtime = require("php.runtime")

local function laravel(command)
  return function()
    require("laravel").commands.run(command)
  end
end

return {
  {
    "laravel/lsp",
    name = "laravel-lsp",
    lazy = true,
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "laravel-lsp" },
    opts = function(_, opts)
      local licence = vim.env.INTELEPHENSE_LICENCE_KEY
      local init_options = licence and licence ~= "" and { licenceKey = licence } or nil

      opts.servers.intelephense = {
        init_options = init_options,
        root_dir = function(bufnr, on_dir)
          local root = runtime.root(bufnr)
          if root then
            on_dir(root)
          end
        end,
        before_init = function(_, config)
          local version = config.root_dir and runtime.php_version(config.root_dir)
          if version then
            config.settings = config.settings or {}
            config.settings.intelephense = config.settings.intelephense or {}
            config.settings.intelephense.environment = config.settings.intelephense.environment or {}
            config.settings.intelephense.environment.phpVersion = version
          end
        end,
        on_attach = function(client)
          client.server_capabilities.documentFormattingProvider = false
          client.server_capabilities.documentRangeFormattingProvider = false
        end,
        settings = {
          intelephense = {
            format = { enable = false },
            files = {
              maxSize = 5000000,
              exclude = {
                "**/.git/**",
                "**/.svn/**",
                "**/.hg/**",
                "**/CVS/**",
                "**/.DS_Store/**",
                "**/node_modules/**",
                "**/bower_components/**",
                "**/vendor/**/{Tests,tests}/**",
                "**/.history/**",
                "**/vendor/**/vendor/**",
                "**/bootstrap/cache/**",
                "**/storage/framework/{cache,sessions,views}/**",
                "**/storage/logs/**",
                "**/public/build/**",
              },
            },
          },
        },
      }
      opts.servers.laravel_lsp = {
        mason = false,
        cmd = {
          "php",
          vim.fn.stdpath("data") .. "/lazy/laravel-lsp/builds/laravel-lsp",
        },
        filetypes = { "php", "blade" },
        root_dir = function(bufnr, on_dir)
          local root = vim.fs.root(bufnr, "artisan")
          if root then
            on_dir(root)
          end
        end,
        init_options = { phpEnvironment = "sail" },
      }
    end,
  },
  {
    "adalessa/laravel.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio",
    },
    ft = { "php", "blade" },
    event = { "BufEnter composer.json" },
    keys = {
      {
        "<leader>Al",
        function()
          require("laravel").pickers.laravel()
        end,
        desc = "Laravel Picker",
      },
      {
        "<leader>Aa",
        function()
          require("laravel").pickers.artisan()
        end,
        desc = "Artisan Picker",
      },
      {
        "<leader>Ar",
        function()
          require("laravel").pickers.routes()
        end,
        desc = "Laravel Routes",
      },
      {
        "<leader>Am",
        function()
          require("laravel").pickers.make()
        end,
        desc = "Laravel Make",
      },
      {
        "<leader>Ao",
        function()
          require("laravel").pickers.resources()
        end,
        desc = "Laravel Resources",
      },
      { "<leader>Ax", laravel("actions"), desc = "Laravel Code Actions" },
      { "<leader>Au", laravel("hub"), desc = "Artisan Hub" },
      { "<leader>Ap", laravel("command_center"), desc = "Laravel Command Center" },
      { "<leader>Ae", laravel("env:configure"), desc = "Configure Laravel Environment" },
      {
        "gf",
        function()
          local Laravel = require("laravel")
          if Laravel.app("gf").cursorOnResource() then
            return "<cmd>lua require('laravel').commands.run('gf')<cr>"
          end
          return "gf"
        end,
        expr = true,
        noremap = true,
        desc = "Laravel Resource",
      },
    },
    opts = {
      features = { pickers = { provider = "snacks" } },
      environments = { default = "sail" },
      eloquent_generate_doc_blocks = true,
      extensions = {
        completion = { enable = false },
        diagnostic = { enable = false },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      for _, parser in ipairs({ "blade", "html" }) do
        if not vim.tbl_contains(opts.ensure_installed, parser) then
          opts.ensure_installed[#opts.ensure_installed + 1] = parser
        end
      end
    end,
  },
}
