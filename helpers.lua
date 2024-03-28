---@param train LuaGuiElement | LuaTrain | number
function get_circuit_by_train(train)
    local train_id = type(train) == "number" and train or train.id

    for i = 1, #global.circuits do
        if global.circuits[i].train == train_id then
            return global.circuits[i]
        end
    end

    return nil
end

local function deepequal(o1, o2, ignore_mt)
    -- same object
    if o1 == o2 then return true end

    local o1Type = type(o1)
    local o2Type = type(o2)
    --- different type
    if o1Type ~= o2Type then return false end
    --- same type but not table, already compared above
    if o1Type ~= 'table' then return false end

    -- use metatable method
    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    -- iterate over o1
    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil or deepequal(value1, value2, ignore_mt) == false then
            return false
        end
    end

    --- check keys in o2 but missing from o1
    for key2, _ in pairs(o2) do
        if o1[key2] == nil then return false end
    end
    return true
end

---@param circuit Circuit
---@param schedule TrainScheduleRecord[]
function save_circuit_cache(circuit, schedule)
    if not circuit.cache then
        do return end
    end

    local circuit_records = {}

    for i = 1, #circuit.cache.records do
        if not circuit.cache.records[i].temporary then
            table.insert(circuit_records, circuit.cache.records[i])
        end
    end

    --NOTE: update cache
    ---@type false | string
    local cache_updated = false;
    for i = 1, #schedule do
        local current_record = schedule[i]
        local cached_record = circuit_records[i]

        if not cached_record then
            cache_updated = 'new'
            break
        end

        if current_record.station ~= cached_record.station then
            cache_updated = 'positions'
            break
        end

        if current_record.temporary ~= cached_record.temporary then
            cache_updated = 'temporary'
            break
        end

        if not deepequal(current_record.wait_conditions, cached_record.wait_conditions) then
            cache_updated = 'wait_conditions'
            break
        end
    end

    if cache_updated ~= false then
        logger.debug('cache updated', cache_updated, schedule, circuit_records)
        circuit.cache = nil
    end
end

---@param circuit Circuit
---@param train LuaTrain
---@param stations LuaEntity[]
local function sort_stations_by_distance(circuit, train, stations)
    circuit.ignore_schedule_changed = true
    ---@type TrainSchedule
    local oldShedule = {
        current = train.schedule.current,
        records = {}
    }

    for i = 1, #train.schedule.records do
        local record = train.schedule.records[i]
        table.insert(oldShedule.records, {
            station = record.station,
            rail = record.rail,
            rail_direction = record.rail_direction,
            wait_conditions = record.wait_conditions,
            temporary = record.temporary
        })
    end

    ---@param station LuaEntity
    local function getDistanceToStop(station)
        train.schedule = {
            current = 1,
            records = {
                {
                    rail = station.connected_rail,
                    temporary = true,
                    wait_conditions = {}
                }
            }
        }

        return train.path.total_distance
    end

    table.sort(stations, function(_a, _b)
        local a = getDistanceToStop(_a)
        local b = getDistanceToStop(_b)
        return a > b
    end)

    train.schedule = oldShedule;
    circuit.ignore_schedule_changed = false
    return stations
end

---@param circuit Circuit
---@param train LuaTrain
function calculate_new_schedule(circuit, train)
    if circuit.cache then
        train.schedule = circuit.cache
        do return end
    end

    ---@type LuaEntity[]
    local all_stations = {}

    for j = 1, #circuit.stations do
        local station_entities = game.get_train_stops({ name = circuit.stations[j] })
        for k = 1, #station_entities do
            table.insert(all_stations, station_entities[k])
        end
    end

    local sorted_stations = sort_stations_by_distance(
        circuit,
        train,
        all_stations
    )

    ---@type TrainSchedule
    local newSchedule = train.schedule

    for i = 1, #sorted_stations do
        ---@type WaitCondition | nil
        local station_wait_condition = nil;

        for j = 1, #train.schedule.records do
            if train.schedule.records[j].station == sorted_stations[i].backer_name then
                station_wait_condition = train.schedule.records[j].wait_conditions
            end
        end

        table.insert(newSchedule.records,
            train.schedule.current + 1,
            {
                rail = sorted_stations[i].connected_rail,
                temporary = true,
                wait_conditions = station_wait_condition
            }
        )
    end

    train.schedule = newSchedule
    circuit.cache = newSchedule
end
