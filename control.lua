require 'utils'
local inspect = require 'inspect'

global.circuits = {}

local _dev_bootstrapped = false;
---@comment Build main UI
---@param event EventData.on_gui_opened
local function build_gui(event)
    logger.debug('build_gui', event)
    local player = game.get_player(event.player_index)

    if not player then
        logger.debug('build_gui', 'cant get player')
        do return end
    end

    local relative = player.gui.relative;

    -- NOTE: reset all states for dev
    -- if _ENV.IS_DEV and not _dev_bootstrapped then
    --     logger.debug('dev reset states')
    --     _dev_bootstrapped = true;
    --     global.players = {}
    --     global.players[event.player_index] = {}
    --     if relative.ccr_main then
    --         relative.ccr_main.destroy()
    --     end
    -- end

    if relative.ccr_main then
        do return end;
    end

    local frame = relative.add {
        type = "frame",
        name = "ccr_main",
        anchor = { gui = defines.relative_gui_type.train_gui, position = defines.relative_gui_position.right },
        direction = "vertical"
    }

    frame.style.maximal_height = 400
    frame.style.width = 350;

    frame.add { type = "frame", name = "header", style = "inner_frame", direction = "horizontal" }
    frame.header.add { type = "label", name = "title", caption = "Circuit Trains", style = "frame_title" }

    frame.add { type = "frame", name = "content", direction = "vertical", style = "deep_frame_in_shallow_frame" }
    frame.content.style.vertically_stretchable = true
    frame.content.style.horizontally_stretchable = true

    local table = frame.content.add { type = "scroll-pane", name = "table", style = "train_schedule_scroll_pane", direction = "vertical" }
    table.style.vertically_stretchable = true
    table.style.horizontally_squashable = true

    local controls = frame.add { type = "flow", name = "controls" }
    controls.style.top_margin = 5
    controls.add { type = "drop-down", name = "ccr_station_selector" }
    controls.ccr_station_selector.style.horizontally_stretchable = true;
    controls.add { type = "button", name = "ccr_add_station", caption = "+ Add station" }
end

---@param event EventData.on_gui_opened | EventData.on_gui_click | EventData.on_train_schedule_changed
local function update_station_table(event)
    logger.debug('update_station_table', event)
    if not event.player_index then
        logger.warn('update_station_table', 'cant get player index')
        do return end
    end

    local player = game.get_player(event.player_index)

    if not player then
        logger.warn('update_station_table', 'cant get player')
        do return end
    end

    local train = player.opened and player.opened.train or nil;

    if not train then
        logger.warn('update_station_table', 'cant get train')
        do return end
    end

    local table = player.gui.relative.ccr_main.content.table
    table.clear()

    for index, circuit in pairs(global.circuits) do
        local item = table.add { type = "frame", name = "item_" .. index, style = "train_schedule_station_frame" }
        item.style.width = 318

        local label = item.add { type = "flow" }
        label.style.horizontally_stretchable = true
        label.style.left_padding = 10
        label.add { type = "label", caption = circuit.station }

        item.add { type = "label", caption = get_station_count(player, circuit.station) }

        item.add { type = "button", name = "ccr_remove_station_" .. index, style = "train_schedule_delete_button", caption = "[color=white]x[/color]" }
    end
end

---@param event EventData.on_gui_opened | EventData.on_train_schedule_changed
local function update_station_selector(event)
    logger.debug('update_station_selector', event)

    if not event.player_index then
        logger.warn('update_station_table', 'cant get player index')
        do return end
    end

    local player = game.get_player(event.player_index)

    if not player then
        logger.warn('build_gui', 'cant get player')
        do return end
    end

    local train = nil

    if event.train then
        train = event.train
    elseif event.entity and event.entity.name == "locomotive" then
        train = player.opened.train
    else
        logger.warn('update_station_selector', 'cant get train')
        do return end
    end

    local selector = player.gui.relative.ccr_main.controls.ccr_station_selector

    selector.items = {}

    for _, record in pairs(train.schedule.records) do
        if not record.station or record.temporary then
            break
        end
        selector.add_item(record.station)
    end

    if #selector.items > 0 then
        selector.selected_index = 1
    end
end

---@param event EventData.on_gui_click
local function handle_add_station(event)
    logger.debug('handle_add_station', event)
    if event.element.name ~= "ccr_add_station" then do return end end

    local player = game.get_player(event.player_index)

    if not player then
        logger.warn('handle_add_station: cant get player')
        do return end
    end

    local train = player.opened.train;

    if not train then
        logger.warn('handle_add_station: cant get train')
        do return end
    end

    local selector = event.element.parent.ccr_station_selector
    local selected_station = selector.items[selector.selected_index]

    local already_added = false
    for _, circuit in pairs(global.circuits) do
        if circuit.train == train.id and circuit.station == selected_station then
            already_added = true;
        end
    end

    if not already_added then
        table.insert(global.circuits, { train = train.id, station = selected_station })
        update_station_table(event)
    end
end

---@param event EventData.on_gui_click
local function handle_delete_station(event)
    logger.debug('handle_delete_station', event)
    local regex = "^ccr_remove_station_";
    local name = event.element.name;
    if not string.match(name, regex) then do return end end

    local station_index = tonumber(string.match(name, regex .. "(%d+)$"))

    if station_index == nil then
        logger.warn("handle_delete_station', 'invalid station index")
        do return end
    end

    logger.debug('handle_delete_station', 'remove station', station_index)
    table.remove(global.circuits, station_index)
    update_station_table(event)
end

---@param event EventData.on_train_schedule_changed
local function handle_schedule_changed(event)
    logger.debug('handle_schedule_changed', event)
    for circuit_index, circuit in ipairs(global.circuits) do
        local station_present = false
        for _, record in ipairs(event.train.schedule.records) do
            if circuit.station == record.station then
                station_present = true
                break
            end
        end
        if not station_present then
            table.remove(global.circuits, circuit_index)
        end
    end
end

---@param event EventData.on_train_changed_state
local function handle_train_changed_state(event)
    if event.train.state ~= defines.train_state.wait_station then
        do return end
    end

    local train = event.train

    if not train.station then
        do return end
    end

    local locomotive = nil;

    for _, carriage in ipairs(train.carriages) do
        if carriage.name == "locomotive" then
            locomotive = carriage
            break;
        end
    end

    if not train.schedule then
        logger.warn('cant get train schedule')
        do return end
    end

    if not locomotive then
        logger.warn('cant get train locomotive')
        do return end
    end

    local all_stations = game.surfaces.nauvis.find_entities_filtered({ name = 'train-stop' })
    for _, circuit in ipairs(global.circuits) do
        if circuit.train == train.id then
            local all_circuit_station_entities = {}

            for i, station in ipairs(all_stations) do
                if train.station.backer_name == circuit.station and station.backer_name == circuit.station and station ~= train.station then
                    table.insert(all_circuit_station_entities, station)
                end
            end
            if #all_circuit_station_entities > 0 then
                sort_station_coordinates_clockwise(all_circuit_station_entities, train.station.position)
                for _, station in ipairs(all_circuit_station_entities) do
                    table.insert(train.schedule.records,
                        train.schedule.current + 1,
                        {
                            rail = station.connected_rail,
                            temporary = true,
                            wait_conditions = { { compare_type = "or", type = "time", ticks = 60 } }
                        }
                    )
                end
                train.schedule = schedule
                train.manual_mode = false
                print('done')
            end
        end
    end
end

script.on_init(function()
    logger.debug('on_init')
end)

script.on_event(defines.events.on_player_created, function(event)
    logger.debug('on_player_created')
end)

script.on_event(defines.events.on_gui_opened, function(event)
    logger.debug('on_gui_opened')
    build_gui(event)
    update_station_table(event)
    update_station_selector(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
    logger.debug('on_gui_click')
    handle_add_station(event)
    handle_delete_station(event)
end)

script.on_event(defines.events.on_train_schedule_changed, function(event)
    logger.debug('on_train_schedule_changed')
    handle_schedule_changed(event)
    update_station_table(event)
    update_station_selector(event)
end)

script.on_event(defines.events.on_train_changed_state, function(event)
    logger.debug('on_train_changed_state', event)
    handle_train_changed_state(event)
end)
