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

FOODTYPE.KEI_DEVICE = "KEI_DEVICE"

local protocol_slot_mode = GetModConfigData("KEI_PROTOCOL_SLOT_MODE") or "7_2"
local protocol_slot_settings = {
    ["7_2"] = { max = 7, step = 2 },
    ["4_1"] = { max = 4, step = 1 },
}
local protocol_slot_setting = protocol_slot_settings[protocol_slot_mode] or protocol_slot_settings["7_2"]

-- Kei 的三项核心资源：电量、稳定性、机体完整度。
TUNING.KEI_MAX_POWER = 120 -- 最大电量上限
TUNING.KEI_MAX_STABILITY = 240 -- 最大稳定性上限
TUNING.KEI_MAX_INTEGRITY = 180 -- 最大机体完整度上限

-- 设计中"普通食物转化电量效率较低"的实现参数。
TUNING.KEI_FOOD_ABSORPTION = 0.2 -- 普通食物转化为电量的效率系数（20%）
TUNING.KEI_BATTERY_POWER = 60 -- 电池类物品提供的电量值
TUNING.KEI_REPAIR_VALUE = 50 -- 修复物品恢复的机体完整度

-- 低电量 / 自动修复 / 协议消耗相关数值集中放在 TUNING，方便后续平衡。
TUNING.KEI_LOW_POWER_DAMAGE = 3 -- 低电量时每秒受到的伤害值
TUNING.KEI_SELF_REPAIR_PERIOD = 3 -- 自动修复的周期（秒）
TUNING.KEI_PROTOCOL_DRAIN_PERIOD = 10 -- 协议消耗的周期（秒）
TUNING.KEI_PROTOCOL_DRAIN_AMOUNT = 2 -- 每个周期消耗的协议数量
TUNING.KEI_PROTOCOL_SLOT_HARD_MAX = 7 -- 协议槽位的硬性最大数量
TUNING.KEI_PROTOCOL_SLOT_INITIAL = 1 -- 初始拥有的协议槽位数
TUNING.KEI_PROTOCOL_SLOT_MAX = protocol_slot_setting.max -- 协议槽位的最大数量（根据配置）
TUNING.KEI_PROTOCOL_UNLOCK_STEP = protocol_slot_setting.step -- 每次解锁的协议槽位数（根据配置）
TUNING.KEI_RECORDER_RANGE = 35 -- 数据记录器的作用范围

-- 头部 / 身体解析协议使用的隐藏虚拟装备槽。
for i = 1, TUNING.KEI_PROTOCOL_SLOT_HARD_MAX do
    EQUIPSLOTS["KEI_PROTOCOL_" .. tostring(i)] = "kei_protocol_" .. tostring(i)
end

-- Kei 专用协议容器：复用 WX-78 扩展存储单元 UI，但只允许协议 CD 放入。
local containers = require("containers")
containers.params.kei_protocol_container = deepcopy(containers.params.wx78_inventorycontainer)
containers.params.kei_protocol_container.itemtestfn = function(container, item, slot)
    return item ~= nil and item:HasTag("kei_protocol_cd")
end
containers.params.kei_protocol_container.priorityfn = nil

local function GetProtocolUnlockRecipeTier(recname)
    return recname ~= nil and tonumber(string.match(recname, "^kei_protocol_mk(%d)$")) or nil
end

AddComponentPostInit("builder", function(self)
    local old_DoBuild = self.DoBuild

    function self:DoBuild(recname, pt, rotation, skin)
        local tier = GetProtocolUnlockRecipeTier(recname)
        if tier == nil then
            return old_DoBuild(self, recname, pt, rotation, skin)
        end

        local recipe = GetValidRecipe(recname)
        local protocolslots = self.inst.components.kei_protocolslots
        if recipe == nil
            or protocolslots == nil
            or not self.inst:HasTag("kei")
            or PREFAB_SKINS_SHOULD_NOT_SELECT[skin]
        then
            return false
        end

        if not (self:IsBuildBuffered(recname) or self:HasIngredients(recipe)) then
            return false
        end

        if recipe.canbuild ~= nil then
            local success, msg = recipe.canbuild(recipe, self.inst, pt, rotation, self.current_prototyper, skin)
            if not success then
                return false, msg
            end
        end

        if not protocolslots:CanUnlockTier(tier) then
            return false, "KEI_PROTOCOL_ALREADY_UNLOCKED"
        end

        local is_buffered_build = self.buffered_builds[recname] ~= nil
        if is_buffered_build then
            self.buffered_builds[recname] = nil
            self.inst.replica.builder:SetIsBuildBuffered(recname, false)
        end

        self.inst:PushEvent("refreshcrafting")

        local materials, discounted = self:GetIngredients(recname)
        if self:CheckIngredientsForMimic(materials) or (discounted and self:CheckDiscountEquipsForMimic()) then
            return false, "ITEMMIMIC"
        end

        self:RemoveIngredients(materials, recname, discounted)

        if protocolslots:UnlockTier(tier) then
            if self.inst.components.talker ~= nil then
                self.inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_PROTOCOL_UNLOCK)
            end
            return true
        end

        return false, "KEI_PROTOCOL_ALREADY_UNLOCKED"
    end
end)

-- 字符串、动作和配方分文件维护，避免入口文件继续膨胀。
AddComponentPostInit("inventory", function(self)
    local old_DropItem = self.DropItem

    function self:DropItem(item, wholestack, randomdir, pos, keepoverstacked)
        if item ~= nil
            and item:HasTag("kei_virtual_equipment")
            and not item.kei_allow_virtual_drop
            and item.components.equippable ~= nil
            and item.components.equippable:IsEquipped()
        then
            return nil
        end

        return old_DropItem(self, item, wholestack, randomdir, pos, keepoverstacked)
    end
end)

modimport("scripts/kei_strings.lua")
modimport("scripts/kei_assets.lua")
modimport("scripts/kei_actions.lua")
modimport("scripts/kei_recipes.lua")

-- 注册可选角色。
AddModCharacter("kei", "FEMALE")
