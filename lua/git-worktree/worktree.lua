local git = require("git-worktree.git")
local config = require("git-worktree.config")
local utils = require("git-worktree.utils")
local hooks = require("git-worktree.hooks")

local vim = vim
local logger = require("git-worktree.vlog"):new({ level = config.get().loglevel })

local M = {}

local function change_dir(path)
  local old_path = utils.get_absolute_path(vim.uv.cwd())
  local new_path = utils.get_absolute_path(path)
  logger:debug("executing cd_fun", { old_path = old_path, new_path = new_path })
  config.get().cd_fun(old_path, new_path)
  return old_path, new_path
end

---@param path string
function M.switch(path)
  if vim.uv.cwd() == path then
    logger:debug("already in worktree, skipping")
    return
  end

  vim.schedule(function()
    local old_path, new_path = change_dir(path)
    hooks.emit(hooks.type.SWITCH, { old_path = old_path, new_path = new_path })
  end)
end

---@param path string
---@param branch? string
---@param upstream? string
function M.create(path, branch, upstream)
  if git.worktree_find(path, branch) then
    logger:error("path or branch already in use", { path = path, branch = branch })
    return
  end
  local res = git.worktree_create(path, branch, upstream)
  logger:debug("worktree_create result", { res = res })
  if res.code ~= 0 then
    logger:error("failed to create worktree", { code = res.code, stderr = res.stderr })
    return
  end

  vim.schedule(function()
    change_dir(path)
    hooks.emit(hooks.type.CREATE, { path = path, branch = branch, upstream = upstream })
  end)
end

return M
