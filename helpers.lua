---@param points LuaEntity[]
function sort_station_coordinates_clockwise(points)
    local center = { x = 0, y = 0 }

    for _, point in pairs(points) do
        logger.debug('point', { x = point.position.x, y = point.position.y })
        center.x = center.x + point.position.x
        center.y = center.y + point.position.y
    end
    center.x = center.x / #points
    center.y = center.y / #points
    logger.debug('center', center)

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

        local det = (a.x - center.x) * (b.y - center.y) - (b.x - center.x) * (a.y - center.y);
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
