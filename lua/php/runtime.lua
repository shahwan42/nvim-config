local M = {}

M.container_root = "/var/www/html"

local function normalize(path)
  return path and vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/$", "") or nil
end

local function start_dir(path)
  if type(path) == "number" then
    path = vim.api.nvim_buf_get_name(path)
  end
  path = path ~= "" and path or vim.uv.cwd()
  local stat = path and vim.uv.fs_stat(path)
  return stat and stat.type == "directory" and normalize(path) or normalize(vim.fs.dirname(path))
end

---@param path? string|integer
---@return string?
function M.root(path)
  local dir = start_dir(path or 0)
  if not dir then
    return nil
  end

  for _, marker in ipairs({ "artisan", "composer.json", ".git" }) do
    local match = vim.fs.find(marker, { path = dir, upward = true })[1]
    if match then
      return normalize(vim.fs.dirname(match))
    end
  end
end

---@param root string?
function M.is_sail(root)
  return root ~= nil and vim.uv.fs_stat(root .. "/vendor/bin/sail") ~= nil
end

local function is_within(path, root)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

---@param path string
---@param root? string
---@return string?
function M.to_container(path, root)
  root = normalize(root or M.root(path))
  path = normalize(path)
  if not root or not path or not is_within(path, root) then
    return nil
  end
  local relative = path:sub(#root + 1)
  return M.container_root .. relative
end

---@param path string
---@param root string
---@return string?
function M.to_host(path, root)
  root = normalize(root)
  path = path:gsub("\\", "/"):gsub("/$", "")
  if not root or not is_within(path, M.container_root) then
    return nil
  end
  return normalize(root .. path:sub(#M.container_root + 1))
end

local function read(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local stat = vim.uv.fs_fstat(fd)
  local data = stat and vim.uv.fs_read(fd, stat.size) or nil
  vim.uv.fs_close(fd)
  return data
end

local function normalize_version(version)
  local major, minor, patch = version and version:match("(%d+)%.(%d+)%.?(%d*)")
  if not major then
    return nil
  end
  return table.concat({ major, minor, patch ~= "" and patch or "0" }, ".")
end

---@param root string
---@return string?
function M.php_version(root)
  local composer = read(root .. "/composer.json")
  if composer then
    local ok, decoded = pcall(vim.json.decode, composer)
    local constraint = ok
        and type(decoded) == "table"
        and ((decoded.config and decoded.config.platform and decoded.config.platform.php) or (decoded.require and decoded.require.php))
      or nil
    local version = type(constraint) == "string" and normalize_version(constraint) or nil
    if version then
      return version
    end
  end

  for _, name in ipairs({ "compose.yaml", "compose.yml", "docker-compose.yaml", "docker-compose.yml" }) do
    local compose = read(root .. "/" .. name)
    if compose then
      local version = normalize_version(compose:match("sail%-(%d+%.%d+)") or compose:match("runtimes/(%d+%.%d+)"))
      if version then
        return version
      end
    end
  end
end

---@param root string
---@return table<string, string>
function M.project_env(root)
  local values = {}
  local contents = read(root .. "/.env") or ""
  for line in contents:gmatch("[^\r\n]+") do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key and value then
      values[key] = value:gsub("^(['\"])(.*)%1$", "%2")
    end
  end
  return values
end

return M
