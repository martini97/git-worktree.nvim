---@alias vlog.Level number | string

---@class vlog.LevelConfig
---@field hl? string
---@field level string
---@field order number

---@class vlog.Config
---@field name string
---@field use_console boolean
---@field use_file boolean
---@field outfile string
---@field highlights boolean
---@field level vlog.Level
---@field float_precision number
---@field levels vlog.LevelConfig[]

---@class vlog.Logger
---@field private use_console boolean
---@field private use_file boolean
---@field private highlights boolean
---@field outfile string
---@field private float_precision number
---@field private levels vlog.LevelConfig[]
---@field private levels_by_order table<number, vlog.LevelConfig>
---@field private levels_by_level table<string, vlog.LevelConfig>
---@field private stringify fun(self: vlog.Logger, val: unknown): string
---@field private map_stringify fun(self: vlog.Logger, ...: unknown): string[]
---@field private make_string fun(self: vlog.Logger, ...: unknown): string
---@field private output_to_console fun(self: vlog.Logger, level: vlog.Level, message: string)
---@field private output_to_file fun(self: vlog.Logger, level: vlog.Level, message: string)
---@field name string
---@field level vlog.Level
---@field new fun(self: vlog.Logger, config: vlog.Config): vlog.Logger
---@field get_level_from_env fun(self: vlog.Logger, envvar: vlog.Level): vlog.Level
---@field get_level fun(self: vlog.Logger, level?: vlog.Level): vlog.LevelConfig
---@field set_level fun(self: vlog.Logger, level: vlog.Level)
---@field log fun(self: vlog.Logger, ...: unknown)
---@field fmt_log fun(self: vlog.Logger, level: vlog.Level, fmt: string, ...: unknown)
---@field var_log fun(self: vlog.Logger, level: vlog.Level, value: unknown, message: string, ...: unknown): unknown
---@field [string] fun(self: vlog.Logger, msg?: string, ...: unknown)

---@type vlog.Config
local default_config = {
    name = 'git-worktree',
    use_console = true,
    use_file = true,
    highlights = true,
    outfile = '',
    level = vim.log.levels.INFO,
    float_precision = 0.01,
    levels = {
        { order = vim.log.levels.TRACE, level = 'TRACE', hl = 'Comment' },
        { order = vim.log.levels.DEBUG, level = 'DEBUG', hl = 'Comment' },
        { order = vim.log.levels.INFO, level = 'INFO', hl = 'None' },
        { order = vim.log.levels.WARN, level = 'WARN', hl = 'WarningMsg' },
        { order = vim.log.levels.ERROR, level = 'ERROR', hl = 'ErrorMsg' },
        { order = vim.log.levels.OFF, level = 'OFF', hl = 'None' },
    },
}

local log_dir = vim.fn.stdpath('log') --[[@as string]]

---@param value number
---@param precision? number
---@return number
local function round(value, precision)
    precision = precision or 1
    if precision == 1 then
        return value
    end
    value = value / precision
    return (value > 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)) * precision
end

---@generic T
---@param items T[]
---@param by string
---@param key_tx? fun(key: string): string
---@return table<string, T>
local function fold_by(items, by, key_tx)
    return vim.iter(items):fold({}, function(acc, curr)
        local key = key_tx and key_tx(curr[by]) or curr[by]
        acc[key] = curr
        return acc
    end)
end

---Returns first non-nil non-empty string
---@param ... string?
---@return string?
local function if_empty_str(...)
    return vim.iter({ ... }):find(function(s)
        return s and s ~= ''
    end)
end

---@class vlog.Logger
local Logger = {}
Logger.__index = Logger

---@param config? vlog.Config
---@return vlog.Logger
function Logger:new(config)
    local instance = {}

    config = vim.tbl_deep_extend('force', default_config, config or {})
    local outfile = if_empty_str(config.outfile, default_config.outfile)
        or vim.fs.joinpath(log_dir, config.name .. '.log')

    instance.name = config.name
    instance.level = config.level
    instance.highlights = config.highlights
    instance.use_console = config.use_console
    instance.use_file = config.use_file
    instance.outfile = outfile
    instance.float_precision = config.float_precision
    instance.levels = config.levels
    instance.levels_by_level = fold_by(instance.levels, 'level', string.lower)
    instance.levels_by_order = fold_by(instance.levels, 'order')

    for _, level_cfg in ipairs(instance.levels) do
        local key = string.lower(level_cfg.level)
        instance[key] = function(self_, ...)
            self_:log(level_cfg.level, ...)
        end

        instance[string.format('fmt_%s', key)] = function(self_, fmt, ...)
            self_:fmt_log(level_cfg.level, fmt, ...)
        end

        instance[string.format('var_%s', key)] = function(self_, value, message, ...)
            self_:var_log(level_cfg.level, value, message, ...)
        end
    end

    setmetatable(instance, Logger)

    return instance
end

---Get log level from env var
---@param envvar vlog.Level
---@return vlog.Level
function Logger:get_level_from_env(envvar)
    envvar = envvar or 'LOGLEVEL'
    local val = string.upper(vim.env[envvar] or 'INFO')
    local lvl = vim.log.levels[val]
    return lvl or vim.log.levels.INFO
end

---@param level? vlog.Level
---@return vlog.LevelConfig
function Logger:get_level(level)
    level = level or self.level
    ---@type vlog.LevelConfig?
    local cfg
    if type(level) == 'number' then
        cfg = self.levels_by_order[level]
    elseif type(level) == 'string' then
        cfg = self.levels_by_level[string.lower(level)]
    end

    if not cfg then
        error(string.format('logger: invalid level: %s', level))
    end

    return cfg
end

---@param level vlog.Level
function Logger:set_level(level)
    self.level = self:get_level(level).level
end

---@param val unknown
---@return string
function Logger:stringify(val)
    if type(val) == 'number' then
        val = round(val, self.float_precision)
    elseif type(val) == 'table' then
        val = vim.inspect(val)
    end
    return tostring(val)
end

---@param ... unknown
---@return string[]
function Logger:map_stringify(...)
    return vim.iter({ ... })
        :map(function(x)
            return self:stringify(x)
        end)
        :totable()
end

---@private
---@param ... unknown
---@return string
function Logger:make_string(...)
    return table.concat(self:map_stringify(...), ' ')
end

---@private
---@param level vlog.Level
---@param message string
function Logger:output_to_console(level, message)
    if not self.use_console then
        return
    end

    local message_level = self:get_level(level)
    local runtime_level = self:get_level(self.level)

    if message_level.order < runtime_level.order then
        return
    end

    local entry = string.format('[%-6s%s]: %s', message_level.level, os.date('%H:%M:%S'), message)
    local lines = vim.split(entry, '\n')
    local chunks = vim.iter(lines)
        :enumerate()
        :map(function(idx, line)
            local eol = idx ~= #lines and '\n' or ''
            local text = string.format('[%s] %s%s', self.name, line, eol)
            return { text, message_level.hl }
        end)
        :totable()

    vim.api.nvim_echo(chunks, true, {})
end

---@private
---@param level vlog.Level
---@param message string
function Logger:output_to_file(level, message)
    if not self.use_file then
        return
    end

    local message_level = self:get_level(level)
    local fp = assert(io.open(self.outfile, 'a'), string.format('vlog: failed to oupen outfile: %s', self.outfile))
    local log_str = string.format('[%-6s%s]: %s\n', message_level.level, os.date(), message)
    fp:write(log_str)
    fp:close()
end

---@param level vlog.Level
---@param ... unknown
function Logger:log(level, ...)
    local message = self:make_string(...)

    self:output_to_console(level, message)
    self:output_to_file(level, message)
end

---@param level vlog.Level
---@param fmt string
---@param ... unknown
function Logger:fmt_log(level, fmt, ...)
    local args = self:map_stringify(...)
    local message = string.format(fmt, unpack(args))
    self:log(level, message)
end

---@generic T
---@param level vlog.Level
---@param value T
---@param message string
---@param ... unknown
---@return T
function Logger:var_log(level, value, message, ...)
    self:log(level, message, { value = value }, ...)
    return value
end

return Logger
