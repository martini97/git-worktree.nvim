---@mod git-worktree.hooks hooks

local M = {}

local config = require("git-worktree.config")
local logger = require("git-worktree.vlog"):new({ level = config.get().loglevel })

---@enum git-worktree.hooks.Autocmds
M.type = {
  CREATE = "GitWorktreeCreate",
  DELETE = "GitWorktreeDelete",
  SWITCH = "GitWorktreeSwitch",
}

---@alias git-worktree.hooks.data.create { path: string, branch?: string, upstream?: string }
---@alias git-worktree.hooks.data.delete { path: string, branch: string }
---@alias git-worktree.hooks.data.switch { old_path: string, new_path: string }

---Emit hook event
---@param type git-worktree.hooks.Autocmds
---@param data table
---@overload fun(type: "GitWorktreeCreate", data: git-worktree.hooks.data.create)
---@overload fun(type: "GitWorktreeDelete", data: git-worktree.hooks.data.delete)
---@overload fun(type: "GitWorktreeSwitch", data: git-worktree.hooks.data.switch)
function M.emit(type, data)
  logger:debug("emitting hook", { pattern = type, data = data })
  vim.api.nvim_exec_autocmds("User", { pattern = type, data = data })
end

return M
