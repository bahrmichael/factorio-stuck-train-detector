local function should_be_checked(state)
    return state == defines.train_state.path_lost
        or state == defines.train_state.wait_signal
end

script.on_event(defines.events.on_train_changed_state, function(event)
    local train = event.train

    if global.stuck_train_detector_trains == nil then
        global.stuck_train_detector_trains = {}
    end

    if should_be_checked(train.state) then
        global.stuck_train_detector_trains[train.id] = train
    elseif global.stuck_train_detector_trains[train.id] ~= nil then
        global.stuck_train_detector_trains[train.id] = nil
        if global.stuck_train_detector_timers ~= nil then
            global.stuck_train_detector_timers[train.id] = nil
        end
    end
end)

local TICKS_PER_SECOND = 60
local TICKS_PER_MINUTE = 60 * TICKS_PER_SECOND

local function get_frequency()
    if settings.global["stuck-train-detector-check-frequency-seconds"] == nil then
        return TICKS_PER_SECOND * 10
    else
        return TICKS_PER_SECOND * settings.global["stuck-train-detector-check-frequency-seconds"].value
    end
end

local function get_time_until_stuck()
    if settings.global["stuck-train-detector-check-minutes-until-considered-stuck"] == nil then
        return TICKS_PER_MINUTE * 1
    else
        return TICKS_PER_MINUTE * settings.global["stuck-train-detector-check-minutes-until-considered-stuck"].value
    end
end

script.on_nth_tick(get_frequency(), function ()
    if global.stuck_train_detector_timers == nil then
        global.stuck_train_detector_timers = {}
    end

    for _, train in pairs(global.stuck_train_detector_trains or {}) do
        if should_be_checked(train.state) then
            if global.stuck_train_detector_timers[train.id] == nil then
                global.stuck_train_detector_timers[train.id] = game.tick
            else
                if game.tick - global.stuck_train_detector_timers[train.id] >= get_time_until_stuck() then
                    if train.front_stock.backer_name then
                        game.print({"", {"stuck-train-detector-named-train-is-stuck", train.front_stock.backer_name}, train.front_rail.gps_tag})
                    else
                        game.print({"", {"stuck-train-detector-a-train-is-stuck"}, train.front_rail.gps_tag})
                    end
                    global.stuck_train_detector_timers[train.id] = nil
                end
            end
        elseif global.stuck_train_detector_timers[train.id] ~= nil then
            global.stuck_train_detector_timers[train.id] = nil
        end
    end
end)