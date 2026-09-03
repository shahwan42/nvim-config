local M = {}

local runtime = require("php.runtime")

local function notify_failure(result, fallback)
  local message = result.stderr and result.stderr ~= "" and result.stderr or fallback
  vim.notify(message, vim.log.levels.ERROR, { title = "PHPStan" })
end

local function filename(root, path)
  if path:sub(1, #runtime.container_root) == runtime.container_root then
    return runtime.to_host(path, root) or path
  end
  if vim.fs.is_absolute(path) then
    return path
  end
  return vim.fs.joinpath(root, path)
end

function M.run()
  local root = runtime.root(0)
  if not root then
    vim.notify("PHPStan: no composer project found", vim.log.levels.WARN)
    return
  end

  local phpstan = root .. "/vendor/bin/phpstan"
  local config = vim.uv.fs_stat(root .. "/phpstan.neon") and "phpstan.neon"
    or vim.uv.fs_stat(root .. "/phpstan.neon.dist") and "phpstan.neon.dist"
  if not vim.uv.fs_stat(phpstan) or not config then
    vim.notify("PHPStan requires vendor/bin/phpstan and phpstan.neon[.dist]", vim.log.levels.WARN)
    return
  end

  local cmd
  if runtime.is_sail(root) then
    cmd = {
      root .. "/vendor/bin/sail",
      "php",
      "vendor/bin/phpstan",
      "analyse",
      "--configuration=" .. config,
      "--error-format=json",
      "--no-progress",
    }
  else
    cmd = { phpstan, "analyse", "--configuration=" .. config, "--error-format=json", "--no-progress" }
  end

  vim.notify("Running project PHPStan…", vim.log.levels.INFO)
  vim.system(cmd, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      local ok, decoded = pcall(vim.json.decode, result.stdout or "")
      if not ok or type(decoded) ~= "table" or type(decoded.files) ~= "table" then
        notify_failure(result, result.stdout ~= "" and result.stdout or ("PHPStan exited with code " .. result.code))
        return
      end

      local items = {}
      for path, file in pairs(decoded.files) do
        for _, message in ipairs(file.messages or {}) do
          items[#items + 1] = {
            filename = filename(root, path),
            lnum = message.line or 1,
            col = 1,
            text = message.message or "PHPStan error",
            type = "E",
          }
        end
      end
      table.sort(items, function(a, b)
        return a.filename == b.filename and a.lnum < b.lnum or a.filename < b.filename
      end)
      vim.fn.setqflist({}, "r", { title = "PHPStan", items = items })

      if #items == 0 then
        vim.notify("PHPStan: no errors", vim.log.levels.INFO)
        return
      end
      local trouble_ok, trouble = pcall(require, "trouble")
      if trouble_ok then
        trouble.open({ mode = "quickfix", focus = false })
      else
        vim.cmd.copen()
      end
    end)
  end)
end

return M
