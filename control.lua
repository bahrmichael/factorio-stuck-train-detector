

local TICKS_PER_SECOND = 60
local TICKS_PER_MINUTE = 60 * TICKS_PER_SECOND

local function should_be_checked(state)
    return state == defines.train_state.no_path
        or state == defines.train_state.wait_signal
end

script.on_init(function()
    storage.stuck_train_detector_trains = {}
    storage.stuck_train_detector_ignore_signals = {}
    storage.stuck_train_detector_timers = {}
end)

script.on_event(defines.events.on_train_changed_state, function(event)
    if storage.stuck_train_detector_trains == nil then
        storage.stuck_train_detector_trains = {}
    end
    if storage.stuck_train_detector_ignore_signals == nil then
        storage.stuck_train_detector_ignore_signals = {}
    end
    if storage.stuck_train_detector_timers == nil then
        storage.stuck_train_detector_timers = {}
    end

    local train = event.train
    assert(train ~= nil, "The train of a on_train_changed_state should never be nil.")

    if should_be_checked(train.state) then
        if train.has_path then
            -- Train is waiting at a signal
            local rail = train.path.rails[train.path.current]
            assert(rail ~= nil, "A train's current path pointed to a nil value.")
            local next_signal = rail.get_outbound_signals()[1]
            
            if next_signal ~= nil and storage.stuck_train_detector_ignore_signals[next_signal.unit_number] == nil then
                -- The train is waiting at a signal that is not opted out. Start monitoring it.
                storage.stuck_train_detector_trains[train.id] = train
            end
        else
            -- Train has lost its path
            storage.stuck_train_detector_trains[train.id] = train
        end
    elseif storage.stuck_train_detector_trains[train.id] ~= nil then
        -- The train is not in a state that should be monitored, but it currently is in the list of trains being monitored. Remove it and delete the timer.
        storage.stuck_train_detector_trains[train.id] = nil
        if storage.stuck_train_detector_timers ~= nil then
            storage.stuck_train_detector_timers[train.id] = nil
        end
    end
end)

local function get_frequency()
    return TICKS_PER_SECOND * (settings.global["stuck-train-detector-check-frequency-seconds"] or {}).value or 10
end

local function get_time_until_stuck()
    return TICKS_PER_MINUTE * (settings.global["stuck-train-detector-check-minutes-until-considered-stuck"] or {}).value or 2
end

script.on_nth_tick(get_frequency(), function ()
    if storage.stuck_train_detector_trains == nil then
        storage.stuck_train_detector_trains = {}
    end
    if storage.stuck_train_detector_timers == nil then
        storage.stuck_train_detector_timers = {}
    end

    for id, train in pairs(storage.stuck_train_detector_trains) do
        if not train.valid then
            -- Train references become invalid if they are deconstructed, or changed (e.g. by adding a new wagon).
            -- We'll stop monitoring, and wait for the train to be waiting at a signal again.
            storage.stuck_train_detector_trains[id] = nil
            storage.stuck_train_detector_timers[id] = nil
        elseif should_be_checked(train.state) then
            if storage.stuck_train_detector_timers[train.id] == nil then
                -- If the train is not on a timer yet, then remember the first time we saw it waiting. We'll use this timestamp later to calculate how long it has been waiting.
                storage.stuck_train_detector_timers[train.id] = game.tick
            else
                if game.tick - storage.stuck_train_detector_timers[train.id] >= get_time_until_stuck() then
                    if train.front_stock.backer_name then
                        game.print({"", {"stuck-train-detector-named-train-is-stuck", train.front_stock.backer_name}, train.front_stock.gps_tag})
                    else
                        -- The backer_name is an optional field on the LuaEntity, so we have default to a generic message if there is no name.
                        -- This can also happen if the train has cargo wagons in the front.
                        game.print({"", {"stuck-train-detector-a-train-is-stuck"}, train.front_stock.gps_tag})
                    end
                    -- Delete the timer after printing the message. It can show up after another full duration, but should not trigger immediately again.
                    storage.stuck_train_detector_timers[train.id] = nil
                    if not (settings.global["stuck-train-detector-allow-renotify"] or {}).value then
                        -- If the player disabled re-notification, then stop tracking the train until its state changes.
                        storage.stuck_train_detector_trains[id] = nil
                    end
                end
            end
        elseif storage.stuck_train_detector_timers[train.id] ~= nil then
            storage.stuck_train_detector_timers[train.id] = nil
        end
    end
end)

script.on_event(defines.events.on_gui_opened, function (event)
    if storage.stuck_train_detector_ignore_signals == nil then
        storage.stuck_train_detector_ignore_signals = {}
    end

    if event.entity ~= nil and (event.entity.name == "rail-signal" or event.entity.name == "rail-chain-signal") then

        local player = game.players[event.player_index]
        local unit_number = event.entity.unit_number

        local guiKey = "rail_signal"
        local signalGui = player.gui.relative[guiKey]
        if signalGui ~= nil then
            -- clear any previous gui so that we can fully reconstruct it
            signalGui.destroy()
        end

        local anchor = {gui = defines.relative_gui_type.rail_signal_base_gui, name = event.entity.name, position = defines.relative_gui_position.right}

        signalGui = player.gui.relative.add{type = "frame", anchor = anchor, caption = "Stuck Train Detector", direction = "vertical", name = guiKey}

        signalGui.add{
            type = "checkbox", 
            caption = {"", {"stuck-train-detector-signal-setting", (settings.global["stuck-train-detector-check-minutes-until-considered-stuck"] or {}).value or 2}}, 
            state = not storage.stuck_train_detector_ignore_signals[unit_number],
            enabled = true,
            name = "stuck_train_detector_signal_" .. unit_number,
            tags = {
                unit_number = unit_number
            }
        }
    end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    if storage.stuck_train_detector_ignore_signals == nil then
        storage.stuck_train_detector_ignore_signals = {}
    end

    local element = event.element
    if not string.find(element.name, "stuck_train_detector", 1, true) then
        return
    end

    if element.state == false then
        storage.stuck_train_detector_ignore_signals[element.tags.unit_number] = true
    else
        storage.stuck_train_detector_ignore_signals[element.tags.unit_number] = nil
    end
end)
