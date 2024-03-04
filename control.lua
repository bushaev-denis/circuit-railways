require 'utils'
require 'helpers'

---@comment Build main UI
---@param event EventData.on_gui_opened
local function build_gui(event)
    local player = game.get_player(event.player_index)

    if not player then
        logger.error('build_gui', 'cant get player')
        do return end
    end

    local relative = player.gui.relative

    if relative.ccr_main then
        relative.ccr_main.destroy()
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
    frame.header.add { type = "label", name = "title", caption = { "ccr.title" }, style = "frame_title" }

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
    controls.add { type = "button", name = "ccr_add_station", caption = { "ccr.add-station" } }
end

---@param event EventData.on_gui_opened | EventData.on_gui_click | EventData.on_train_schedule_changed
local function update_station_table(event)
    if not event.player_index then
        do return end
    end

    local player = game.get_player(event.player_index)

    if not player then
        do return end
    end

    local train = nil
    if player.opened and player.opened_gui_type == defines.gui_type.entity and player.opened.train then
        train = player.opened.train
    end

    if not train then
        logger.warn('update_station_table', 'cant get train')
        do return end
    end

    local table = player.gui.relative.ccr_main.content.table
    table.clear()

    for index = 1, #global.circuits do
        local circuit = global.circuits[index]
        if circuit.train == train.id then
            local item = table.add { type = "frame", name = string.format("item_%d", index), style = "train_schedule_station_frame" }
            item.style.width = 318

            local label = item.add { type = "flow" }
            label.style.horizontally_stretchable = true
            label.style.left_padding = 10
            label.add { type = "label", caption = circuit.station }

            item.add { type = "label", caption = circuit.station_count }

            item.add {
                type = "button",
                name = string.format("ccr_remove_station_%d", index),
                style = "train_schedule_delete_button",
                caption = "[color=white]x[/color]"
            }
        end
    end
end

---@param event EventData.on_gui_opened | EventData.on_train_schedule_changed
local function update_station_selector(event)
    if not event.player_index then
        do return end
    end

    local player = game.get_player(event.player_index)

    if not player then
        do return end
    end

    local train = nil

    if event.train then
        train = event.train
    elseif event.entity and event.entity.name == "locomotive" then
        train = player.opened.train
    end

    if not train then
        logger.warn('update_station_selector', 'cant get train')
        do return end
    end

    if not train.schedule then
        logger.warn('update_station_selector', 'cant get schedule')
        do return end
    end

    local selector = player.gui.relative.ccr_main.controls.ccr_station_selector
    selector.items = {}

    for i = 1, #train.schedule.records do
        local record = train.schedule.records[i]
        if record.station and not record.temporary then
            selector.add_item(record.station)
        end
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

    logger.debug('test')

    local selector = event.element.parent.ccr_station_selector
    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local selected_station = selector.items[selector.selected_index]

    local already_added = false
    for i = 1, #global.circuits do
        local circuit = global.circuits[i]
        if circuit.train == train.id and circuit.station == selected_station then
            already_added = true;
        end
    end

    if not already_added then
        table.insert(global.circuits,
            {
                train = train.id,
                station = selected_station,
                station_count = #game.get_train_stops({ name = selected_station })
            }
        )
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
    for circuit_index = 1, #global.circuits do
        local circuit = global.circuits[circuit_index]
        local station_present = false
        for ri = 1, #event.train.schedule.records do
            if circuit.station == event.train.schedule.records[ri].station then
                station_present = true
                break
            end
        end
        if not station_present and event.train.id == circuit.train then
            logger.debug('handle_schedule_changed', 'remove station', circuit.train, circuit.station)
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

    if not train.schedule then
        logger.debug('handle_train_changed_state', 'cant get train schedule')
        do return end
    end

    if #train.schedule.records <= 0 then
        logger.debug('empty train schedule', train)
        do return end
    end

    if not train.station then
        logger.debug('handle_train_changed_state', 'cant get train station')
        do return end
    end

    local next_station_index = get_next_station_index_in_schedule(train.schedule)

    if next_station_index == nil then
        logger.debug(
            string.format(
                'cant get next (target) station for train %d and current station %s',
                train.id,
                train.schedule.records[train.schedule.current].station
            )
        )
        do return end
    end

    for ci = 1, #global.circuits do
        local circuit = global.circuits[ci]
        if
            circuit.station ==
            train.station.backer_name
        then
            logger.debug('skip real station in circuit schedule', train.station.backer_name)
            train.go_to_station(next_station_index)
            do return end
        end


        if circuit.train == train.id then
            if circuit.cache == nil then
                circuit.cache = sort_station_coordinates_clockwise(
                    game.get_train_stops({ name = circuit.station }),
                    train.station.position
                )
            end

            local schedule = train.schedule;

            for si = 1, #circuit.cache do
                ---@diagnostic disable-next-line: need-check-nil
                table.insert(schedule.records,
                    train.schedule.current + 1,
                    {
                        rail = circuit.cache[si].connected_rail,
                        temporary = true,
                        wait_conditions = train.schedule.records[next_station_index].wait_conditions
                    }
                )
            end

            train.schedule = schedule
        end
    end
end

---@param event EventData.on_train_schedule_changed
local function remove_circut_cache(event)
    for i = 1, #global.circuits do
        if global.circuits[i].train == event.train.id then
            global.circuits[i].cache = nil
        end
    end
end

script.on_init(function()
    logger.debug('on_init')
    global = {
        VERSION = { 1, 0, 0 },
        circuits = {}
    }
end)

script.on_event(defines.events.on_gui_opened, function(event)
    build_gui(event)
    update_station_table(event)
    update_station_selector(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
    handle_add_station(event)
    handle_delete_station(event)
end)

script.on_event(defines.events.on_train_schedule_changed, function(event)
    handle_schedule_changed(event)
    update_station_table(event)
    update_station_selector(event)
    remove_circut_cache(event)
end)

script.on_event(defines.events.on_train_changed_state, function(event)
    handle_train_changed_state(event)
end)
