require 'utils'
require 'helpers'

---@comment Build main UI
---@param event EventData.on_gui_opened
local function build_gui(event)
    logger.debug('build_gui', 'start')
    local player = game.get_player(event.player_index)

    if not player then
        logger.error('build_gui', 'cant get player')
        do return end
    end

    if not player.gui.relative.ccr_main then
        local frame = player.gui.relative.add {
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

        local table_element = frame.content.add { type = "scroll-pane", name = "table", style = "train_schedule_scroll_pane", direction = "vertical" }
        table_element.style.vertically_stretchable = true
        table_element.style.horizontally_squashable = true

        local controls = frame.add { type = "flow", name = "controls" }
        controls.style.top_margin = 5
        controls.add { type = "drop-down", name = "ccr_station_selector" }
        controls.ccr_station_selector.style.horizontally_stretchable = true;
        controls.add { type = "button", name = "ccr_add_station", caption = { "ccr.add-station" } }
    end
end

---@param event EventData.on_gui_opened | EventData.on_gui_click | EventData.on_train_schedule_changed
local function update_station_table(event)
    logger.debug('update_station_table', 'start')

    if not event.player_index then
        do return end
    end

    local player = game.get_player(event.player_index)

    if not player then
        do return end
    end

    local table_element = player.gui.relative.ccr_main.content.table
    table_element.clear()

    ---@type LuaGuiElement | LuaTrain
    local train = nil
    if player.opened and player.opened_gui_type == defines.gui_type.entity and player.opened.train then
        train = player.opened.train
    end

    if not train then
        logger.info('update_station_table', 'cant get train')
        do return end
    end

    local circuit = get_circuit_by_train(train)

    if not circuit then
        logger.info('update_station_table', 'cant get circuit')
        do return end
    end

    logger.debug('update_station_table', 'rerender')

    for i = 1, #circuit.stations do
        ---@comment _{train_id}_{station_index}
        local prefix = string.format("_%d_%d", circuit.train, i)
        local item = table_element.add { type = "frame", name = "item" .. prefix, style = "train_schedule_station_frame" }
        item.style.width = 318

        local label = item.add { type = "flow" }
        label.style.horizontally_stretchable = true
        label.style.left_padding = 10
        label.add { type = "label", caption = circuit.stations[i] }

        item.add { type = "label", caption = #game.get_train_stops({ name = circuit.stations[i] }) }

        item.add {
            type = "button",
            name = "ccr_remove_station" .. prefix,
            style = "train_schedule_delete_button",
            caption = "[color=white]x[/color]"
        }
    end
end

---@param event EventData.on_gui_opened | EventData.on_train_schedule_changed
local function update_station_selector(event)
    logger.debug('update_station_selector', 'start')
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
        logger.info('update_station_selector', 'cant get train')
        do return end
    end

    if not train.schedule then
        logger.info('update_station_selector', 'cant get schedule')
        do return end
    end

    logger.debug('update_station_selector', 'rerender')
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
        logger.info('handle_add_station: cant get player')
        do return end
    end

    local train = player.opened.train;

    if not train then
        logger.info('handle_add_station: cant get train')
        do return end
    end

    local circuit = get_circuit_by_train(train)

    if not circuit then
        table.insert(global.circuits, { train = train.id, stations = {}, cache = nil, ignore_schedule_changed = false })
        circuit = global.circuits[#global.circuits]
    end

    local selector = event.element.parent.ccr_station_selector
    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local selected_station = selector.items[selector.selected_index]


    local already_added = false;

    for i = 1, #circuit.stations do
        if circuit.stations[i] == selected_station then
            already_added = true
            break
        end
    end

    if not already_added then
        table.insert(circuit.stations, selected_station)
    end

    update_station_table(event)
end

---@param event EventData.on_gui_click
local function handle_delete_station(event)
    logger.debug('handle_delete_station', event)
    local name = event.element.name;
    if not string.match(name, "^ccr_remove_station") then do return end end

    local event_train_id = tonumber(string.match(name, "_(%d+)_"))
    local event_station_index = tonumber(string.match(name, "(%d+)$"))

    if not event_train_id then
        logger.warn('handle_delete_station', 'cant find train index')
        do return end
    end

    if not event_station_index then
        logger.warn("handle_delete_station', 'cant find station index")
        do return end
    end

    local circuit = get_circuit_by_train(event_train_id)

    if not circuit then
        logger.warn("handle_delete_station', 'cant get circuit")
        do return end
    end

    table.remove(circuit.stations, event_station_index)
    circuit.cache = nil
    update_station_table(event)
end

---@param event EventData.on_train_schedule_changed
local function handle_schedule_changed(event)
    logger.debug('handle_schedule_changed', event)

    local train = event.train

    if not train or not train.schedule then
        logger.debug('handle_schedule_changed', 'cant get train')
        do return end
    end

    local circuit = get_circuit_by_train(train)

    if not circuit then
        logger.debug('handle_schedule_changed', 'cant get circuit')
        do return end
    end

    if circuit.ignore_schedule_changed then
        do return end
    end

    ---@type TrainScheduleRecord[]
    local schedule = {}

    for i = 1, #train.schedule.records do
        if not train.schedule.records[i].temporary then
            table.insert(schedule, train.schedule.records[i])
        end
    end

    for i = 1, #circuit.stations do
        local found = false

        for j = 1, #schedule do
            if schedule[j].station == circuit.stations[i] then
                found = true
                break;
            end
        end

        if not found then
            table.remove(circuit.stations, i)
        end
    end

    save_circuit_cache(circuit, schedule)
end

---@param event EventData.on_train_changed_state
local function handle_train_changed_state(event)
    logger.debug('handle_train_changed_state', 'start', event)

    local train = event.train
    local schedule = train.schedule
    local circuit = get_circuit_by_train(train);

    if not circuit then
        logger.debug('handle_train_changed_state', 'cant find circuit')
        do return end
    end

    if not schedule then
        logger.debug('handle_train_changed_state', 'cant get train schedule')
        do return end
    end

    if #schedule.records <= 0 then
        logger.debug('empty train schedule', train)
        do return end
    end

    if schedule.records[schedule.current].temporary then
        logger.debug('temporary station, skip', train)
        do return end
    end

    local next_station_index = schedule.current + 1 > #schedule.records and 1 or schedule.current + 1
    local current_station_in_circuit = false;
    local next_station_in_circuit = false;

    for i = 1, #circuit.stations do
        if circuit.stations[i] == schedule.records[schedule.current].station then
            logger.debug('current_station_in_circuit')
            current_station_in_circuit = true
        end

        if circuit.stations[i] == schedule.records[next_station_index].station then
            logger.debug('next_station_in_circuit')
            next_station_in_circuit = true
        end
    end

    if current_station_in_circuit then
        ---@type number | nil
        local next_station_not_in_cirtuit_index = nil

        for i = 1, #train.schedule.records do
            local found = false;

            for j = 1, #circuit.stations do
                if circuit.stations[j] == train.schedule.records[i].station then
                    found = true
                    break;
                end
            end

            if not found then
                next_station_not_in_cirtuit_index = i
                break;
            end
        end

        if next_station_not_in_cirtuit_index ~= nil then
            train.go_to_station(next_station_not_in_cirtuit_index)
        end
    end

    if current_station_in_circuit or not next_station_in_circuit then
        do return end
    end

    if train.state == defines.train_state.wait_station then
        calculate_new_schedule(circuit, train)
    end
end

script.on_init(function()
    logger.debug('on_init')
    global = {
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
end)

script.on_event(defines.events.on_train_changed_state, function(event)
    handle_train_changed_state(event)
end)
