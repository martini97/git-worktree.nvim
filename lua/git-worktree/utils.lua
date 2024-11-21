local M = {}
local vim = vim

--- Execute CMD and return it's output as an array of lines.
--- If the command exits with an error then returns nil.
---@param ... string
---@returns string[]?
function M.system_lines(...)
  local cmd = { ... }
  local result = vim.system(cmd, { text = true }):wait()
  local lines = vim.split(result.stdout, "\n", { trimempty = true, plain = true })
  if result.code ~= 0 then
    return nil
  end
  return lines
end

---@param opts table
---@return string?
function M.input_co(opts)
  local co = assert(coroutine.running(), "must be called within a coroutine")
  local cb = vim.schedule_wrap(function(input)
    coroutine.resume(co, input)
  end)

  vim.ui.input(opts, cb)

  return coroutine.yield()
end

---@generic T
---@param items T[]
---@param opts table
---@return T?
function M.select_co(items, opts)
  local co = assert(coroutine.running(), "must be called within a coroutine")
  local cb = vim.schedule_wrap(function(input)
    coroutine.resume(co, input)
  end)

  vim.ui.select(items, opts, cb)

  return coroutine.yield()
end

---@param branch string
---@return string
function M.branch_to_path(branch)
  local path, _ = branch:gsub("/", "_")
  return path
end

---@param path? string
---@return string
function M.get_absolute_path(path)
  path = path or "."
  path = path == "." and vim.uv.cwd() or path
  return assert(vim.uv.fs_realpath(path), "could not get absolute path for " .. path)
end

return M
