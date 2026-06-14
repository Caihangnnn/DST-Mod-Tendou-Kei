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
    Asset("ANIM", "anim/kei.zip"),  --人物模型
    Asset("ANIM", "anim/ghost_kei_build.zip"),  --人物灵魂状态模型
    Asset("ANIM", "anim/kei_battery.zip"),
    Asset("ANIM", "anim/kei_repair_tool.zip"),
    Asset("ANIM", "anim/kei_analysis_cd.zip"),
    Asset("ANIM", "anim/kei_analysis_tool.zip"),
    Asset("ANIM", "anim/kei_blank_cd.zip"),
    Asset("ANIM", "anim/kei_combat_cd.zip"),
    Asset("ANIM", "anim/wx_chassis.zip"),

    Asset("ATLAS", "bigportraits/kei.xml"),  --人物大图（方形的那个）
    Asset("ATLAS", "bigportraits/kei.xml"),  --人物大图（椭圆的那个）
    Asset("ATLAS", "images/names_kei.xml"),  --人物名称
    Asset("ATLAS", "images/avatars/avatar_kei.xml"),  --tab键人物列表显示的头像  --  可以直接用小地图那张
    Asset("ATLAS", "images/avatars/avatar_ghost_kei.xml"),  --tab键人物列表显示的头像（死亡）
    Asset("ATLAS", "images/avatars/self_inspect_kei.xml"),  --人物检查按钮
    Asset("ATLAS", "images/map_icons/kei.xml"),  --地图图标
    Asset("ATLAS", "images/saveslot_portraits/kei.xml"),  -- 存档图片
    -- Asset("ATLAS", "images/selectscreen_portraits/kei.xml"),
    -- Asset("ATLAS", "images/selectscreen_portraits/kei_silho.xml"),
    Asset("ATLAS", "images/kei_mk1.xml"),
    Asset("ATLAS", "images/kei_mk2.xml"),
    Asset("ATLAS", "images/kei_mk3.xml"),
    Asset("ATLAS", "images/kei_repair_tool.xml"),
    Asset("ATLAS", "images/kei_battery.xml"),
    Asset("ATLAS", "images/kei_analysis_cd.xml"),
    Asset("ATLAS", "images/kei_analysis_tool.xml"),
    Asset("ATLAS", "images/kei_blank_cd.xml"),
    Asset("ATLAS", "images/kei_combat_cd.xml"),
}

AddMinimapAtlas("images/map_icons/kei.xml")

FOODTYPE.KEI_DEVICE = "KEI_DEVICE"

local protocol_slot_mode = GetModConfigData("KEI_PROTOCOL_SLOT_MODE") or "7_2"
local protocol_slot_settings = {
    ["7_2"] = { max = 7, step = 2 },
    ["4_1"] = { max = 4, step = 1 },
}
local protocol_slot_setting = protocol_slot_settings[protocol_slot_mode] or protocol_slot_settings["7_2"]
TUNING.KEI_ANALYSIS_CONSUME_EQUIPMENT = GetModConfigData("KEI_ANALYSIS_CONSUME_EQUIPMENT") == true
TUNING.KEI_ANALYSIS_USE_EQUIPMENT_VISUAL = GetModConfigData("KEI_ANALYSIS_USE_EQUIPMENT_VISUAL") ~= false
TUNING.KEI_BEEQUEEN_PRESTIGE_MODE = GetModConfigData("KEI_BEEQUEEN_PRESTIGE_MODE") or "area"

-- Kei 的三项核心资源：电量、稳定性、机体完整度。
TUNING.KEI_MAX_POWER = 120 -- 最大电量上限
TUNING.KEI_MAX_STABILITY = 120 -- 最大稳定性上限
TUNING.KEI_MAX_INTEGRITY = 120 -- 最大机体完整度上限
TUNING.KEI_PROTOCOL_STAT_BONUS = 20 -- 每完成一次协议槽扩展时三维上限增加的数值

-- 设计中"普通食物转化电量效率较低"的实现参数。
TUNING.KEI_FOOD_ABSORPTION = 0.2 -- 普通食物转化为电量的效率系数（20%）
TUNING.KEI_BATTERY_POWER = 60 -- 电池类物品提供的电量值
TUNING.KEI_REPAIR_VALUE = 50 -- 修复物品恢复的机体完整度
TUNING.KEI_DORMANT_POWER_DRAIN = 1 -- 休眠状态每秒消耗的电量
TUNING.KEI_DORMANT_STABILITY_REGEN = 3 -- 休眠状态每秒恢复的数据稳定性
TUNING.KEI_DORMANT_INTEGRITY_REGEN = 3 -- 休眠状态每秒恢复的机体完整度

-- 低电量 / 自动修复 / 协议消耗相关数值集中放在 TUNING，方便后续平衡。
TUNING.KEI_LOW_POWER_DAMAGE = 3 -- 低电量时每秒受到的伤害值
TUNING.KEI_SELF_REPAIR_PERIOD = 3 -- 自动修复的周期（秒）
TUNING.KEI_PROTOCOL_DRAIN_PERIOD = 10 -- 协议消耗的周期（秒）
TUNING.KEI_PROTOCOL_DRAIN_AMOUNT = 2 -- 每个周期消耗的协议数量
TUNING.KEI_PROTOCOL_DRAIN_MAX_PER_PERIOD = 10 -- 协议消耗每个周期的扣除上限
TUNING.KEI_ALTERGUARDIAN_POWER_REGEN = 10 -- 天体英雄协议每个消耗周期回复的电量
TUNING.KEI_PROTOCOL_SLOT_HARD_MAX = 7 -- 协议槽位的硬性最大数量
TUNING.KEI_PROTOCOL_SLOT_INITIAL = 1 -- 初始拥有的协议槽位数
TUNING.KEI_PROTOCOL_SLOT_MAX = protocol_slot_setting.max -- 协议槽位的最大数量（根据配置）
TUNING.KEI_PROTOCOL_UNLOCK_STEP = protocol_slot_setting.step -- 每次解锁的协议槽位数（根据配置）
TUNING.KEI_RECORDER_RANGE = 35 -- 数据记录器的作用范围
TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE = 10 -- 独眼巨鹿协议防止过冷时的最低体温
TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE = 60 -- 龙蝇协议防止过热时的最高体温
TUNING.KEI_EYEOFTERROR_DASH_DISTANCE = 16 -- 恐怖之眼协议单次冲锋的最大位移距离
TUNING.KEI_DAYWALKER_LEAP_DISTANCE = 12 -- 梦魇疯猪协议单次跳劈的最大位移距离
TUNING.KEI_DAYWALKER_LEAP_RADIUS = 4 -- 梦魇疯猪协议跳劈的伤害范围
TUNING.KEI_DAYWALKER_LEAP_DAMAGE_BASE = 150 -- 梦魇疯猪协议跳劈的固定伤害
TUNING.KEI_DAYWALKER_LEAP_DAMAGE_MAXHEALTH_PERCENT = 0.04 -- 梦魇疯猪协议跳劈按目标最大生命值追加的伤害比例
TUNING.KEI_DAYWALKER_LEAP_SLOW_MULT = 0.1 -- 梦魇疯猪协议跳劈命中后的移速倍率
TUNING.KEI_DAYWALKER_LEAP_SLOW_DURATION = 3 -- 梦魇疯猪协议跳劈命中后的减速时间
TUNING.KEI_DAYWALKER_SINKHOLE_DURATION = 0.5 -- 梦魇疯猪协议跳劈留下的坑持续时间
TUNING.KEI_DAYWALKER_LEAP_COOLDOWN = 3 -- 梦魇疯猪协议跳劈冷却时间
TUNING.KEI_MINOTAUR_TENTACLE_CHANCE = 0.30 -- 远古守卫者协议触发暗影触手的概率
TUNING.KEI_MINOTAUR_TENTACLE_COOLDOWN = 0.5 -- 远古守卫者协议生成暗影触手后的内置冷却
TUNING.KEI_MINOTAUR_SHADOW_PRISON_CHANCE = 0.15 -- 远古守卫者协议触发暗影牢笼的概率
TUNING.KEI_STALKER_SHADOWSTRIKE_CHANCE = 0.30 -- 织影者协议触发影袭的概率
TUNING.KEI_STALKER_SHADOWSTRIKE_DAMAGE_MULT = 0.5 -- 影袭造成的额外伤害比例
TUNING.KEI_KLAUS_SOUL_CHANCE = 0.20 -- 克劳斯协议抽取灵魂并治疗周围单位的概率
TUNING.KEI_TOADSTOOL_SLEEPBOMB_CHANCE = 0.3 -- 蟾蜍协议触发睡眠炸弹弹药的概率
TUNING.KEI_ANTLION_SANDSPIKE_CHANCE = 0.30 -- 蚁狮协议触发高大沙刺的概率
TUNING.KEI_ANTLION_SANDSPIKE_COOLDOWN = 0.5 -- 蚁狮协议生成沙刺后的内置冷却
TUNING.KEI_ANTLION_SANDSPIKE_VERTEX_DELAY = 8 * FRAMES -- 中心沙刺后，三角形顶点沙刺的延迟
TUNING.KEI_ANTLION_SANDSPIKE_TRIANGLE_RADIUS = 1.6 -- 三个顶点沙刺到目标中心的距离
TUNING.KEI_ANTLION_SANDSPIKE_DAMAGE_RADIUS = 1.1 -- 沙刺的实际命中半径
TUNING.KEI_ANTLION_SANDSPIKE_TALL_DAMAGE = 200 -- 中心高大沙刺的目标伤害
TUNING.KEI_ANTLION_SANDSPIKE_SHORT_DAMAGE = 100 -- 三角顶点小沙刺的目标伤害
TUNING.KEI_BEEQUEEN_PANIC_DURATION = 5 -- 蜂后协议威压造成的恐慌持续时间
TUNING.KEI_BEEQUEEN_PANIC_RADIUS = 12 -- 蜂后协议嘶吼领域威压范围
TUNING.KEI_BEEQUEEN_PANIC_COOLDOWN = 3 -- 蜂后协议嘶吼领域触发冷却

-- 头部 / 身体解析协议使用的隐藏虚拟装备槽。
for i = 1, TUNING.KEI_PROTOCOL_SLOT_HARD_MAX do
    EQUIPSLOTS["KEI_PROTOCOL_" .. tostring(i)] = "kei_protocol_" .. tostring(i)
end

require("bufferedaction")
local old_BufferedAction_Do = BufferedAction.Do

function BufferedAction:Do(...)
    if self.doer ~= nil
        and self.doer:HasTag("kei_dormant")
        and self.action ~= ACTIONS.KEI_WAKE
    then
        self:Fail()
        return false, "KEI_DORMANT"
    end

    return old_BufferedAction_Do(self, ...)
end

AddComponentPostInit("temperature", function(self)
    local old_SetTemperature = self.SetTemperature

    function self:SetTemperature(value, ...)
        if self.inst:HasTag("kei_nooverheat") then
            value = math.min(value, TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE)
        end
        if self.inst:HasTag("kei_nofreezing") then
            value = math.max(value, TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE)
        end

        return old_SetTemperature(self, value, ...)
    end
end)

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
        if self.inst:HasTag("kei_dormant") then
            return false, "KEI_DORMANT"
        end

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
        if self.inst:HasTag("kei_dormant") then
            return nil
        end

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
