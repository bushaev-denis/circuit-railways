require('types')
local inspect = require('inspect')

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

---@param player LuaPlayer
---@param id uint
function get_train_by_id(player, id)
    for _, loco in pairs(player.surface.find_entities_filtered { name = "locomotive" }) do
        if loco.train.id == id then return loco.train end;
    end

    return nil;
end

-- TODO: remplace with game.get_stops
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

---comment Returns the next station in schedule
---@param schedule TrainSchedule
---@param current_index int? change current index
---@param include_temp boolean? include temporary (skipped by default)
function get_next_station_index_in_schedule(schedule, current_index, include_temp)
    current_index = current_index or schedule.current
    include_temp = include_temp or false

    while true do
        if current_index + 1 > #schedule.records then
            current_index = 1
        else
            current_index = current_index + 1
        end

        if current_index <= #schedule.records then
            if not include_temp and not schedule.records[current_index].temporary then
                return current_index
            end
            if include_temp and schedule.records[current_index].temporary then
                return current_index
            end
        end
    end
end
