local M = {}
local git = require("git-worktree.git")

---Completion for branch names
---@param arglead string
---@return string[]
function M.branch(arglead)
  local branches = git.branch_list()
  return vim.fn.matchfuzzy(branches, arglead)
end

return M
