local BASIC_ATTRIBUTE_PROTOCOL_LIST = {
    {
        protocol = "power_max",
        prefab = "kei_basic_attribute_cd_power_max",
        display_name = "电量上限",
        description = "随机增加或降低电量上限。",
        attribute = "power_max",
        range_min = -5,
        range_max = 15,
    },
    {
        protocol = "stability_max",
        prefab = "kei_basic_attribute_cd_stability_max",
        display_name = "稳定性上限",
        description = "随机增加或降低稳定性上限。",
        attribute = "stability_max",
        range_min = -5,
        range_max = 15,
    },
    {
        protocol = "integrity_max",
        prefab = "kei_basic_attribute_cd_integrity_max",
        display_name = "完整度上限",
        description = "随机增加或降低完整度上限。",
        attribute = "integrity_max",
        range_min = -5,
        range_max = 15,
    },
    {
        protocol = "power_drain_reduction",
        prefab = "kei_basic_attribute_cd_power_drain_reduction",
        display_name = "电量消耗速度",
        description = "降低电量消耗速度。",
        attribute = "power_drain_reduction",
        range_min = 5,
        range_max = 15,
        is_percent = true,
    },
    {
        protocol = "fixed_damage_bonus",
        prefab = "kei_basic_attribute_cd_fixed_damage_bonus",
        display_name = "固定伤害",
        description = "随机增加或降低固定伤害。",
        attribute = "fixed_damage_bonus",
        range_min = -15,
        range_max = 30,
    },
    {
        protocol = "base_damage_bonus",
        prefab = "kei_basic_attribute_cd_base_damage_bonus",
        display_name = "基础伤害",
        description = "随机增加或降低普通攻击的基础伤害。",
        attribute = "base_damage_bonus",
        range_min = -5,
        range_max = 10,
    },
    {
        protocol = "percent_damage_bonus",
        prefab = "kei_basic_attribute_cd_percent_damage_bonus",
        display_name = "百分比伤害",
        description = "随机增加或降低百分比伤害。",
        attribute = "percent_damage_bonus",
        range_min = -10,
        range_max = 20,
        is_percent = true,
    },
    {
        protocol = "percent_speed_bonus",
        prefab = "kei_basic_attribute_cd_percent_speed_bonus",
        display_name = "百分比移速",
        description = "随机增加或降低百分比移速。",
        attribute = "percent_speed_bonus",
        range_min = -10,
        range_max = 20,
        is_percent = true,
    },
    {
        protocol = "fixed_damage_reduction",
        prefab = "kei_basic_attribute_cd_fixed_damage_reduction",
        display_name = "固定伤害减免",
        description = "固定减少受到的伤害。",
        attribute = "fixed_damage_reduction",
        range_min = 1,
        range_max = 3,
    },
    {
        protocol = "fixed_health_loss_reduction",
        prefab = "kei_basic_attribute_cd_fixed_health_loss_reduction",
        display_name = "固定扣血减免",
        description = "在最终扣除生命值时固定减少生命损失。",
        attribute = "fixed_health_loss_reduction",
        range_min = -1,
        range_max = 2,
    },
    {
        protocol = "percent_damage_reduction",
        prefab = "kei_basic_attribute_cd_percent_damage_reduction",
        display_name = "百分比伤害减免",
        description = "随机增加或降低百分比伤害减免。",
        attribute = "percent_damage_reduction",
        range_min = -5,
        range_max = 10,
        is_percent = true,
    },
}

local BASIC_ATTRIBUTE_PROTOCOLS = {}
local BASIC_ATTRIBUTE_PROTOCOL_PREFABS = {}

for _, def in ipairs(BASIC_ATTRIBUTE_PROTOCOL_LIST) do
    def.kind = "basic_attribute"
    BASIC_ATTRIBUTE_PROTOCOLS[def.protocol] = def
    BASIC_ATTRIBUTE_PROTOCOL_PREFABS[def.prefab] = def.protocol
end

return {
    BASIC_ATTRIBUTE_PROTOCOL_LIST = BASIC_ATTRIBUTE_PROTOCOL_LIST,
    BASIC_ATTRIBUTE_PROTOCOLS = BASIC_ATTRIBUTE_PROTOCOLS,
    BASIC_ATTRIBUTE_PROTOCOL_PREFABS = BASIC_ATTRIBUTE_PROTOCOL_PREFABS,
}
