require('types')
local inspect = require('libs.inspect')

---@type {circuits: Circuit[]}
global = global or { circuits = {} }

local function appendMetatable(data)
    if type(data) == 'table' then
        for i, v in pairs(data) do
            data[i] = appendMetatable(v)
        end
    end
    if type(data) == 'userdata' then
        return getmetatable(data)
    end
    return data
end

local function loggerFormatter(...)
    local args = table.pack(...)
    args.n = nil
    return inspect(appendMetatable(args))
end

---@param color "gray"|"blue"|"yellow"|"red"
local function loggerColor(color, msg)
    local colors = {
        gray = "90",
        blue = "94",
        yellow = "93",
        red = "31",
    }

    return "\27[31;" .. colors[color] .. "m " .. msg .. " \27[0m"
end

logger = {
    debug = function(...)
        print(loggerColor("gray", "DEBUG:"), loggerFormatter(...))
    end,
    info = function(...)
        print(loggerColor("blue", "INFO:"), loggerFormatter(...))
    end,
    warn = function(...)
        print(loggerColor("yellow", "WARN:"), loggerFormatter(...))
    end,
    error = function(...)
        print(loggerColor("red", "ERROR:"), loggerFormatter(...))
    end
}
