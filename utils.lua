require('types')
local inspect = require('inspect')

---@type {circuits: Circuit[]}
global = global or { circuits = {} }

_ENV.IS_DEV = false

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

---@param points LuaEntity[]
---@param center {x: number, y: number}
function sort_station_coordinates_clockwise(points, center)
    local function sorter(_a, _b)
        local a = _a.position
        local b = _b.position
        if (a.x - center.x >= 0 and b.x - center.x < 0) then
            return true;
        end
        if (a.x - center.x < 0 and b.x - center.x >= 0) then
            return false;
        end
        if (a.x - center.x == 0 and b.x - center.x == 0) then
            if (a.y - center.y >= 0 or b.y - center.y >= 0) then
                return a.y > b.y;
            end
            return b.y > a.y;
        end

        det = (a.x - center.x) * (b.y - center.y) - (b.x - center.x) * (a.y - center.y);
        if (det < 0) then
            return true
        end
        if (det > 0) then
            return false
        end

        d1 = (a.x - center.x) * (a.x - center.x) + (a.y - center.y) * (a.y - center.y);
        d2 = (b.x - center.x) * (b.x - center.x) + (b.y - center.y) * (b.y - center.y);
        return d1 > d2;
    end

    table.sort(points, sorter)
    return points
end
