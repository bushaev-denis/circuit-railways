require('types')
require('utils')

logger.debug('Apply migration 1.1.0')
logger.debug('Before', global)

---@alias OldCircuit {train: number, station: string}

---@type {circuits: OldCircuit[]}
local oldGlobal = global or { circuits = {} }

---@type {circuits: Circuit[]}
local newGlobal = { circuits = {} }

for i = 1, #oldGlobal.circuits do
    local oldRecord = oldGlobal.circuits[i]

    local present = false

    for j = 1, #newGlobal.circuits do
        if newGlobal.circuits[j].train == oldRecord.train then
            present = true
        end
    end

    if not present then
        table.insert(newGlobal.circuits, { train = oldRecord.train, stations = {}, cache = nil })
    end

    for j = 1, #newGlobal.circuits do
        if newGlobal.circuits[j].train == oldRecord.train then
            table.insert(newGlobal.circuits[j].stations, oldRecord.station)
        end
    end
end

global = newGlobal
logger.debug('After', global)

logger.debug('remove gui start')
for pi = 1, #game.players do
    local player = game.players[pi]

    if player.gui.relative.ccr_main then
        player.gui.relative.ccr_main.destroy()
    end
end
logger.debug('remove gui finish')
