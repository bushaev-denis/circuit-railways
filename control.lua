require 'utils'

local _dev_bootstrapped = false;
---@comment Build main UI
---@param event EventData.on_gui_opened
local function build_gui(event)
    logger.debug('build_gui', event)
    local player = game.get_player(event.player_index)

    if not player then
        print('build_gui: cant get player')
        do return end
    end

    local relative = player.gui.relative;

    -- NOTE: reset all states for dev
    if _ENV.IS_DEV and not _dev_bootstrapped then
        print('DEV: reset states')
        _dev_bootstrapped = true;
        global.players = {}
        global.players[event.player_index] = {}
        if relative.ccr_main then
            relative.ccr_main.destroy()
        end
    end

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
    local player = game.get_player(event.player_index)

    if not player then
        logger.warn('update_station_table', 'cant get player')
        do return end
    end

    local gplayer = global.players[event.player_index]

    if not gplayer then
        logger.warn('update_station_table', 'cant get global player')
        do return end
    end

    if not gplayer.circuits then
        gplayer.circuits = {}
    end

    local train = player.opened.train;

    if not train then
        logger.warn('update_station_table', 'cant get train')
        do return end
    end

    local table = player.gui.relative.ccr_main.content.table
    table.clear()

    -- add
    for index, circuit in pairs(gplayer.circuits) do
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

---@param event EventData.on_gui_opened | EventData.on_gui_click | EventData.on_train_schedule_changed
local function update_station_selector(event)
    logger.debug('update_station_selector', event)
    local player = game.get_player(event.player_index)

    if not player then
        logger.warn('build_gui', 'cant get player')
        do return end
    end

    local train = player.opened.train

    if not train then
        logger.warn('update_station_selector', 'cant get train')
        do return end;
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

local function handle_add_station(event)
    logger.debug('handle_add_station', event)
    if event.element.name ~= "ccr_add_station" then do return end end

    local player = game.get_player(event.player_index)

    if not player then
        logger.warn('handle_add_station: cant get player')
        do return end
    end

    local gplayer = global.players[event.player_index]

    if not gplayer then
        logger.warn('handle_add_station: cant get global player', global.players, event.player_index)
        do return end
    end

    local train = player.opened.train;

    if not train then
        logger.warn('handle_add_station: cant get train')
        do return end
    end

    local selector = event.element.parent.ccr_station_selector
    local selected_station = selector.items[selector.selected_index]

    if not gplayer.circuits then
        gplayer.circuits = {}
    end

    local already_added = false

    for _, circuit in pairs(gplayer.circuits) do
        if circuit.train == train.id and circuit.station == selected_station then
            already_added = true;
        end
    end

    if not already_added then
        table.insert(gplayer.circuits, { train = train.id, station = selected_station })
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

    local gplayer = global.players[event.player_index]

    if not gplayer then
        logger.warn('handle_delete_station', 'cant get global player')
        do return end
    end

    logger.debug('handle_delete_station', 'remove station', station_index)
    table.remove(gplayer.circuits, station_index)
    update_station_table(event)
end

---@param event EventData.on_train_schedule_changed
local function handle_schedule_changed(event)
    logger.debug('handle_schedule_changed', event)

    local player = game.get_player(event.player_index)

    if not player then
        logger.warn('handle_add_station: cant get player')
        do return end
    end

    local gplayer = global.players[event.player_index]

    if not gplayer then
        logger.warn('handle_add_station: cant get global player', global.players, event.player_index)
        do return end
    end

    if not gplayer.circuits then
        gplayer.circuits = {}
    end

    for circuit_index, circuit in ipairs(gplayer.circuits) do
        local station_present = false
        for _, record in ipairs(event.train.schedule.records) do
            if circuit.station == record.station then
                station_present = true
                break
            end
        end
        if not station_present then
            table.remove(gplayer.circuits, circuit_index)
        end
    end
end

script.on_init(function()
    logger.debug('on_init')
    global.players = {}
end)

script.on_event(defines.events.on_player_created, function(event)
    logger.debug('on_player_created')
    global.players[event.player_index] = {}
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
    logger.debug('on_train_changed_state', event.train)
end)
