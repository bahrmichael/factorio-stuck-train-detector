data:extend({
    {
        type = "int-setting",
        name = "stuck-train-detector-check-frequency-seconds",
        setting_type = "runtime-global",
        minimum_value = 1,
        default_value = 10,
    },
    {
        type = "int-setting",
        name = "stuck-train-detector-check-minutes-until-considered-stuck",
        setting_type = "runtime-global",
        minimum_value = 1,
        default_value = 2,
    },
    {
        type = "bool-setting",
        name = "stuck-train-detector-allow-renotify",
        setting_type = "runtime-global",
        default_value = true,
    }
})