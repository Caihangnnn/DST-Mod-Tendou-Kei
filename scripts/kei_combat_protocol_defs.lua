local COMBAT_PROTOCOLS = {
    deerclops = {
        kind = "combat",
        protocol = "deerclops",
        description = "独眼巨鹿数据：攻击附带冰冻，并免疫冻结与过冷。",
    },
    bearger = {
        kind = "combat",
        protocol = "bearger",
        description = "熊獾数据：攻击会扩散冲击，造成群体伤害。",
    },
    dragonfly = {
        kind = "combat",
        protocol = "dragonfly",
        description = "龙蝇数据：攻击会点燃目标，并免疫过热与火焰伤害。",
    },
    moose = {
        kind = "combat",
        protocol = "moose",
        display_name = "麋鹿鹅",
        description = "麋鹿鹅数据：获得带电攻击，并免疫潮湿。",
    },
    eyeofterror = {
        kind = "combat",
        protocol = "eyeofterror",
        display_name = "恐怖之眼",
        description = "恐怖之眼数据：右键冲锋到鼠标指定位置。",
    },
}

local VALID_RECORD_TARGETS = {}

for prefab in pairs(COMBAT_PROTOCOLS) do
    VALID_RECORD_TARGETS[prefab] = true
end

return {
    COMBAT_PROTOCOLS = COMBAT_PROTOCOLS,
    VALID_RECORD_TARGETS = VALID_RECORD_TARGETS,
}
