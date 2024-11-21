local M = {}

local worktree = require("git-worktree.worktree")
local config = require("git-worktree.config")
local git = require("git-worktree.git")
local utils = require("git-worktree.utils")

local logger = require("git-worktree.vlog"):new({ level = config.get().loglevel })

---@param worktree_path string?
local function switch(worktree_path)
  local wt = git.worktree_find(worktree_path)
    or utils.select_co(git.worktree_list(), {
      prompt = "> worktree: ",
      format_item = function(w)
        return w.worktree
      end,
    })

  logger:debug("switching worktree", { worktree = wt })

  if not wt or not wt.worktree or wt.worktree == "" then
    logger:error("failed to find worktree directory, please check if it's created", { worktree = wt })
    return
  end

  worktree.switch(wt.worktree)
end

---@param branch? string
---@param path? string
---@param upstream? string
local function create(branch, path, upstream)
  assert(coroutine.running(), "must be called within a coroutine")

  branch = assert(branch or utils.input_co({
    prompt = "> branch: ",
    completion = "customlist,v:lua.require'git-worktree'.compl.branch",
  }), "no branch specified")
  path = assert(path or utils.input_co({
    prompt = "> path: ",
    default = utils.branch_to_path(branch),
    completion = "dir",
  }), "no path specified")
  upstream = upstream or utils.select_co(git.branch_list("--remote"), { prompt = "> upstream: " })

  logger:debug("creating worktree", { branch = branch, path = path, upstream = upstream })
  worktree.create(path, branch, upstream)
end

---Switch to worktree
---@param worktree_path string?
function M.switch(worktree_path)
  return coroutine.wrap(switch)(worktree_path)
end

---Create new worktree
---@param branch? string
---@param path? string
---@param upstream? string
function M.create(branch, path, upstream)
  return coroutine.wrap(create)(branch, path, upstream)
end

return M
