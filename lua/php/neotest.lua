local M = {}

local function bridge()
  return vim.fn.stdpath("config") .. "/lua/php/phpunit_bridge.php"
end

function M.adapter()
  local adapter = require("neotest-phpunit")({
    phpunit_cmd = bridge,
    root_ignore_files = { "tests/Pest.php" },
    filter_dirs = { ".git", ".cache", ".phpunit.cache", "node_modules", "storage", "vendor" },
    env = {},
    dap = {
      type = "php",
      request = "launch",
      name = "Debug PHPUnit (Sail)",
      port = 9003,
      pathMappings = { ["/var/www/html"] = "${workspaceFolder}" },
    },
  })

  local build_spec = adapter.build_spec
  adapter.build_spec = function(args)
    local spec = build_spec(args)
    if spec and args.strategy == "dap" and spec.strategy then
      spec.strategy.program = bridge()
      spec.strategy.runtimeArgs = {}
      spec.strategy.pathMappings = { ["/var/www/html"] = "${workspaceFolder}" }
      spec.strategy.env = vim.tbl_extend("force", spec.strategy.env or {}, { XDEBUG_TRIGGER = "1" })
      spec.env = vim.tbl_extend("force", spec.env or {}, { XDEBUG_TRIGGER = "1" })
    end
    return spec
  end

  return adapter
end

return M
