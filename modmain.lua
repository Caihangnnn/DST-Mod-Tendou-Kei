-- 让本文件可以直接访问饥荒的全局 API，例如 PrefabFiles、TUNING、AddAction 等。
GLOBAL.setmetatable(env, {
    __index = function(_, key)
        return GLOBAL.rawget(GLOBAL, key)
    end,
})

-- 角色与角色专属物品的 prefab 入口。
PrefabFiles = {
    "kei",
    "kei_items",
    "kei_data_recorder",
}

Assets = {}

-- Kei 的三项核心资源：电量、稳定性、机体完整度。
TUNING.KEI_MAX_POWER = 120
TUNING.KEI_MAX_STABILITY = 240
TUNING.KEI_MAX_INTEGRITY = 180

-- 设计中“普通食物转化电量效率较低”的实现参数。
TUNING.KEI_FOOD_ABSORPTION = 0.2
TUNING.KEI_BATTERY_POWER = 60
TUNING.KEI_REPAIR_VALUE = 50

-- 低电量 / 自动修复 / 协议消耗相关数值集中放在 TUNING，方便后续平衡。
TUNING.KEI_LOW_POWER_DAMAGE = 3
TUNING.KEI_SELF_REPAIR_PERIOD = 3
TUNING.KEI_PROTOCOL_DRAIN_PERIOD = 10
TUNING.KEI_PROTOCOL_DRAIN_AMOUNT = 2
TUNING.KEI_PROTOCOL_SLOT_MAX = 7
TUNING.KEI_RECORDER_RANGE = 18

-- 字符串、动作和配方分文件维护，避免入口文件继续膨胀。
modimport("scripts/kei_strings.lua")
modimport("scripts/kei_frontend.lua")
modimport("scripts/kei_actions.lua")
modimport("scripts/kei_recipes.lua")

-- 注册可选角色。贴图资源未完成前，实际外观在 prefab 内临时沿用 Wendy。
AddModCharacter("kei", "FEMALE")
