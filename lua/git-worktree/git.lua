local utils = require("git-worktree.utils")
local config = require("git-worktree.config")

local vim = vim
local logger = require("git-worktree.vlog"):new({ level = config.get().loglevel })

local M = {}

---@class git-worktree.git.Worktree
---@field worktree string
---@field head string
---@field branch string

---Returns worktrees for the current dir
---@return git-worktree.git.Worktree[]
function M.worktree_list()
  ---@type git-worktree.git.Worktree[]
  local worktrees = {}
  local lines = assert(utils.system_lines("git", "worktree", "list", "--porcelain"), "failed to list git worktrees")

  for _, line in pairs(lines) do
    if #worktrees == 0 then
      table.insert(worktrees, {})
    end
    local wt = worktrees[#worktrees]
    if vim.startswith(line, "worktree") then
      wt.worktree = vim.trim(line:sub(10))
    elseif vim.startswith(line, "branch") then
      wt.branch = vim.trim(line:sub(19))
    elseif vim.startswith(line, "HEAD") then
      wt.head = vim.trim(line:sub(6))
    elseif line == "bare" then
      wt.branch = "bare"
      wt.head = "bare"
    elseif line == "" then
      table.insert(worktrees, {})
    end
  end

  return worktrees
end

---@param path? string
---@param branch? string
---@return git-worktree.git.Worktree?
function M.worktree_find(path, branch)
  local wts = M.worktree_list()
  return vim.iter(wts):find(function(wt)
    return (path and wt.path == path) or (branch and wt.branch == branch)
  end)
end

---Return root dir (bare repo)
---@return string?
function M.root()
  local lines = assert(
    utils.system_lines("git", "rev-parse", "--path-format=absolute", "--git-common-dir"),
    "failed to get root dir"
  )
  return lines[1]
end

---Return toplevel dir
---@return string?
function M.toplevel()
  local lines = assert(
    utils.system_lines("git", "rev-parse", "--path-format=absolute", "--show-toplevel"),
    "failed to get toplevel dir"
  )
  return lines[1]
end

---List git branches
---@param ... string extra args to pass branch command
---@return string[]
function M.branch_list(...)
  local lines = assert(utils.system_lines("git", "branch", "--format=%(refname:short)", ...), "failed to list branches")
  return lines
end

---Find branch by name
---@param branch string
---@param ... string extra args to pass branch command
---@return string?
function M.branch_find(branch, ...)
  return vim.iter(M.branch_list(...)):find(branch)
end

---Create worktree
---@param path string
---@param branch? string
---@param upstream? string
---@return vim.SystemCompleted
function M.worktree_create(path, branch, upstream)
  local cmd = { "git", "worktree", "add" }

  if branch == nil then
    table.insert(cmd, "-d")
    table.insert(cmd, path)
    logger:debug("worktree_create", { cmd = cmd })
    return vim.system(cmd, { text = true }):wait()
  end

  if not M.branch_find(branch) then
    table.insert(cmd, "-b")
    table.insert(cmd, branch)
    table.insert(cmd, path)
    if upstream and branch ~= upstream then
      table.insert(cmd, "--track")
      table.insert(cmd, upstream)
    end
    logger:debug("worktree_create", { cmd = cmd })
    return vim.system(cmd, { text = true }):wait()
  end

  table.insert(cmd, path)
  table.insert(cmd, branch)
  logger:debug("worktree_create", { cmd = cmd })
  return vim.system(cmd, { text = true }):wait()
end

return M
