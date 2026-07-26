-- 宠物性格定义：性格在捕捉时修正初始基础属性。
local PetPersonality = {}

local DEFAULT_ID = "normal"

local DEFINITIONS = {
    normal = {
        id = "normal",
        display_name = "普通",
        modifiers = {
            max_health_multiplier = 1,
            attack_damage_multiplier = 1,
            attack_interval_delta = 0,
            experience_growth_multiplier = 1,
            movement_speed_multiplier = 1,
            defense_delta = 0,
            damage_reduction_delta = 0,
            size_scale_multiplier = 1,
        },
    },
}

function PetPersonality.GetDefaultId()
    return DEFAULT_ID
end

function PetPersonality.Get(id)
    return DEFINITIONS[id] or DEFINITIONS[DEFAULT_ID]
end

function PetPersonality.NormalizeId(id)
    return DEFINITIONS[id] ~= nil and id or DEFAULT_ID
end

return PetPersonality
