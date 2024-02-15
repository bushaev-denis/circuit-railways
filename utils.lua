require('types')
local json_encode = require('json')

---@type {players: GlobalPlayer[]}
global = global or {}

_ENV.IS_DEV = true

local function removeUserdata(data)
    if type(data) == 'table' then
        for i, v in pairs(data) do
            data[i] = removeUserdata(v)
        end
    end
    if type(data) == 'userdata' then
        return nil
    end
    return data
end

local function loggerFormatter(...)
    local args = table.pack(...)
    args.n = nil
    return json_encode(removeUserdata(args))
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
        if not _ENV.IS_DEV then do return end end
        print(loggerColor("gray", "DEBUG:"), loggerFormatter(...))
    end,
    info = function(...)
        if not _ENV.IS_DEV then do return end end
        print(loggerColor("blue", "INFO:"), loggerFormatter(...))
    end,
    warn = function(...)
        if not _ENV.IS_DEV then do return end end
        print(loggerColor("yellow", "WARN:"), loggerFormatter(...))
    end,
    error = function(...)
        print(loggerColor("red", "ERROR:"), loggerFormatter(...))
    end
}

---@param player LuaPlayer
---@param id uint
function get_train_by_id(player, id)
    for _, loco in pairs(player.surface.find_entities_filtered { name = "locomotive" }) do
        if loco.train.id == id then return loco.train end;
    end

    return nil;
end

---@param player LuaPlayer
---@param name string
function get_stations(player, name)
    local stops = {}
    for _, stop in pairs(player.surface.find_entities_filtered { type = "train-stop" }) do
        if stop.backer_name == name then
            table.insert(stops, stop)
        end
    end
    return stops
end

---@param player LuaPlayer
---@param name string
function get_station_count(player, name)
    return #(get_stations(player, name) or {})
end
