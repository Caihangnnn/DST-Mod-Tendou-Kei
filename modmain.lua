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
    "kei_protocol_container",
}

Assets = {
    Asset("ANIM", "anim/kei.zip"),
    Asset("ANIM", "anim/ghost_kei_build.zip"),
    Asset("ANIM", "anim/player_idles_kei.zip"),

    Asset("ATLAS", "bigportraits/kei.xml"),
    Asset("ATLAS", "images/names_kei.xml"),
    Asset("ATLAS", "images/names_gold_kei.xml"),
    Asset("ATLAS", "images/avatars/avatar_kei.xml"),
    Asset("ATLAS", "images/avatars/avatar_ghost_kei.xml"),
    Asset("ATLAS", "images/avatars/self_inspect_kei.xml"),
    Asset("ATLAS", "images/map_icons/kei.xml"),
    Asset("ATLAS", "images/saveslot_portraits/kei.xml"),
    Asset("ATLAS", "images/selectscreen_portraits/kei.xml"),
    Asset("ATLAS", "images/selectscreen_portraits/kei_silho.xml"),
}

AddMinimapAtlas("images/map_icons/kei.xml")

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

-- 头部 / 身体解析协议使用的隐藏虚拟装备槽。
for i = 1, TUNING.KEI_PROTOCOL_SLOT_MAX do
    EQUIPSLOTS["KEI_PROTOCOL_" .. tostring(i)] = "kei_protocol_" .. tostring(i)
end

-- Kei 专用协议容器：复用 WX-78 扩展存储单元 UI，但只允许协议 CD 放入。
local containers = require("containers")
containers.params.kei_protocol_container = deepcopy(containers.params.wx78_inventorycontainer)
containers.params.kei_protocol_container.itemtestfn = function(container, item, slot)
    return item ~= nil and item:HasTag("kei_protocol_cd")
end
containers.params.kei_protocol_container.priorityfn = nil

-- 字符串、动作和配方分文件维护，避免入口文件继续膨胀。
modimport("scripts/kei_strings.lua")
modimport("scripts/kei_assets.lua")
modimport("scripts/kei_actions.lua")
modimport("scripts/kei_recipes.lua")

-- 注册可选角色。
AddModCharacter("kei", "FEMALE")
