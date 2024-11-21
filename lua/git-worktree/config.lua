local vim = vim
local M = {}

---@class git-worktree.Config
---@field loglevel integer log level (see `:h log_levels`)
---@field cd_fun fun(old_path: string, new_path: string) function to change directory when switching to worktree

---@type git-worktree.Config
M._defaults = {
  loglevel = vim.g.git_worktree_loglevel or vim.log.levels.WARN,
  cd_fun = function(_, new_path)
    vim.cmd.tabnew()
    vim.cmd.tcd(new_path)
    vim.cmd.edit(".")
  end,
}

---@type git-worktree.Config
M._config = {} ---@diagnostic disable-line: missing-fields

---@param config? git-worktree.Config
function M.setup(config)
  M._config = vim.tbl_deep_extend("force", M._defaults, M._config, config or {})
end

---@return git-worktree.Config
function M.get()
  return vim.tbl_isempty(M._config) and M._defaults or M._config
end

return M
