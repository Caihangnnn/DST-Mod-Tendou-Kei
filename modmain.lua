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
    "kei_protocol_binder",
    "kei_mutateddeerclops_aura",
    "kei_mutatedwarg_flamethrower",
    "kei_wagboss_beam",
    "kei_celestial_orb",
    "kei_daywalker2_shield",
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
    Asset("ANIM", "anim/kei_life_cd.zip"),
    Asset("ANIM", "anim/kei_data_recorder.zip"),
    Asset("ANIM", "anim/kei_data_recorder_item.zip"),
    Asset("ANIM", "anim/kei_protocol_binder.zip"),
    Asset("ANIM", "anim/kei_protocol_popup.zip"),
    Asset("ANIM", "anim/ui_kei_protocol_box_7x1.zip"),
    Asset("ANIM", "anim/wx_chassis.zip"),
    Asset("ANIM", "anim/kei_status_power.zip"),
    Asset("ANIM", "anim/kei_status_stability.zip"),
    Asset("ANIM", "anim/kei_status_integrity.zip"),
    Asset("ANIM", "anim/kei_status_power_meter.zip"),
    Asset("ANIM", "anim/kei_status_stability_meter.zip"),
    Asset("ANIM", "anim/kei_status_integrity_meter.zip"),
    Asset("ANIM", "anim/status_meter_wx_shield.zip"),

    Asset("ATLAS", "bigportraits/kei.xml"),  --人物大图（方形的那个）
    Asset("ATLAS", "bigportraits/kei.xml"),  --人物大图（椭圆的那个）
    Asset("ATLAS", "images/names_kei.xml"),  --人物名称
    Asset("ATLAS", "images/avatars/avatar_kei.xml"),  --tab键人物列表显示的头像  --  可以直接用小地图那张
    Asset("ATLAS", "images/avatars/avatar_ghost_kei.xml"),  --tab键人物列表显示的头像（死亡）
    Asset("ATLAS", "images/avatars/self_inspect_kei.xml"),  --人物检查按钮
    Asset("ATLAS", "images/map_icons/kei.xml"),  --地图图标
    Asset("ATLAS", "images/map_icons/wandering_trader.xml"),
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
    Asset("ATLAS", "images/kei_life_cd.xml"),
    Asset("ATLAS", "images/kei_data_recorder_item.xml"),
    Asset("ATLAS", "images/kei_protocol_binder.xml"),
    Asset("ATLAS", "images/kei_protocol_binder_open.xml"),
    Asset("ATLAS", "images/kei_protocol_slot_closed.xml"),
    Asset("ATLAS", "images/kei_protocol_slot_locked.xml"),
    Asset("ATLAS", "images/kei_protocol_slot_openable.xml"),
    Asset("ATLAS", "images/transparent_slot.xml"),
    Asset("IMAGE", "images/kei_protocol_binder.tex"),
    Asset("IMAGE", "images/kei_life_cd.tex"),
    Asset("IMAGE", "images/kei_data_recorder_item.tex"),
    Asset("IMAGE", "images/kei_protocol_binder_open.tex"),
    Asset("IMAGE", "images/kei_protocol_slot_closed.tex"),
    Asset("IMAGE", "images/kei_protocol_slot_locked.tex"),
    Asset("IMAGE", "images/kei_protocol_slot_openable.tex"),
    Asset("IMAGE", "images/transparent_slot.tex"),
}

PreloadAssets = {
    Asset("ANIM", "anim/kei_status_power.zip"),
    Asset("ANIM", "anim/kei_status_stability.zip"),
    Asset("ANIM", "anim/kei_status_integrity.zip"),
    Asset("ANIM", "anim/kei_status_power_meter.zip"),
    Asset("ANIM", "anim/kei_status_stability_meter.zip"),
    Asset("ANIM", "anim/kei_status_integrity_meter.zip"),
}

AddMinimapAtlas("images/map_icons/kei.xml")
AddMinimapAtlas("images/map_icons/wandering_trader.xml")

AddPrefabPostInit("wanderingtrader", function(inst)
    if not TheWorld.ismastersim then
        return
    end

    if inst.components.maprevealable == nil then
        inst:AddComponent("maprevealable")
    end
    inst.components.maprevealable:SetIcon("wandering_trader.tex")
    inst.components.maprevealable:AddRevealSource("kei_wandering_trader_compass", "compassbearer")
end)

if GetModConfigData("KEI_WANDERING_TRADER_MAP_MARKER") ~= false then
    AddPrefabPostInit("wanderingtrader", function(inst)
        if inst.MiniMapEntity == nil then
            inst.entity:AddMiniMapEntity()
        end
        inst.MiniMapEntity:SetIcon("wandering_trader.tex")
    end)
end

FOODTYPE.KEI_DEVICE = "KEI_DEVICE"

local KEI_RPC_NAMESPACE = "TendouKei"
local protocol_slot_mode = GetModConfigData("KEI_PROTOCOL_SLOT_MODE") or "7_2"
local protocol_slot_settings = {
    ["7_2"] = { max = 7, step = 2 },
    ["4_1"] = { max = 4, step = 1 },
}
local protocol_slot_setting = protocol_slot_settings[protocol_slot_mode] or protocol_slot_settings["7_2"]
TUNING.KEI_ANALYSIS_CONSUME_EQUIPMENT = GetModConfigData("KEI_ANALYSIS_CONSUME_EQUIPMENT") == true
TUNING.KEI_ANALYSIS_USE_EQUIPMENT_VISUAL = GetModConfigData("KEI_ANALYSIS_USE_EQUIPMENT_VISUAL") ~= false
TUNING.KEI_ALLOW_DATA_COPY = GetModConfigData("KEI_ALLOW_DATA_COPY") ~= false
TUNING.KEI_PROTOCOL_DRAIN_SOUND = GetModConfigData("KEI_PROTOCOL_DRAIN_SOUND") ~= false
TUNING.KEI_BEEQUEEN_PRESTIGE_MODE = GetModConfigData("KEI_BEEQUEEN_PRESTIGE_MODE") or "area"
TUNING.KEI_MUTATEDWARG_FLAMETHROWER_DURATION = 5
TUNING.KEI_MUTATEDWARG_FLAMETHROWER_COOLDOWN = 10
TUNING.KEI_MUTATEDWARG_FLAMETHROWER_RANGE = 10
TUNING.KEI_MUTATEDWARG_FLAMETHROWER_DAMAGE = 50
TUNING.KEI_MUTATEDWARG_FLAMETHROWER_TICK = 0.5
TUNING.KEI_MUTATEDWARG_FLAMETHROWER_STABILITY_COST = 10
TUNING.KEI_MUTATEDWARG_FLAMETHROWER_AIM_UPDATE_PERIOD = 0.1

local function HasMutatedWargProtocol(player)
    return player ~= nil
        and player.components.kei_protocolslots ~= nil
        and player.components.kei_protocolslots:HasCombatProtocol("mutatedwarg")
end

local function IsMutatedWargFlameReady(player)
    return player ~= nil
        and player:HasTag("kei")
        and not player:HasTag("playerghost")
        and not player:HasTag("kei_dormant")
        and (player.components.health == nil or not player.components.health:IsDead())
        and HasMutatedWargProtocol(player)
        and player.kei_mutatedwarg_flamethrower_cd_task == nil
        and player.components.inventory ~= nil
        and player.components.inventory:GetActiveItem() == nil
        and player.components.sanity ~= nil
        and player.components.sanity.current >= (TUNING.KEI_MUTATEDWARG_FLAMETHROWER_STABILITY_COST or 10)
end

local function SpawnMutatedWargFlameReadyFx(player)
    if player == nil
        or not player:IsValid()
        or not player:HasTag("kei")
        or player:HasTag("playerghost")
        or player:HasTag("kei_dormant")
        or (player.components.health ~= nil and player.components.health:IsDead())
        or not HasMutatedWargProtocol(player)
    then
        return
    end

    local ismount = player.components.rider ~= nil and player.components.rider:IsRiding()
    local fx = SpawnPrefab(ismount and "fx_book_moon_mount" or "fx_book_moon")
    if fx ~= nil then
        if ismount then
            fx.Transform:SetSixFaced()
        end
        fx.Transform:SetPosition(player.Transform:GetWorldPosition())
        fx.Transform:SetRotation(player.Transform:GetRotation())
    end
end

local function StartMutatedWargFlameCooldown(player)
    if player == nil then
        return
    end
    if player.kei_mutatedwarg_flamethrower_cd_task ~= nil then
        player.kei_mutatedwarg_flamethrower_cd_task:Cancel()
    end
    player.kei_mutatedwarg_flamethrower_cd_task = player:DoTaskInTime(TUNING.KEI_MUTATEDWARG_FLAMETHROWER_COOLDOWN or 10, function(inst)
        inst.kei_mutatedwarg_flamethrower_cd_task = nil
        SpawnMutatedWargFlameReadyFx(inst)
    end)
end

local function RefreshMutatedWargChannelcastAnimation(player)
    if player == nil
        or player.sg == nil
        or player.sg:HasStateTag("busy")
        or player.sg:HasStateTag("overridelocomote")
    then
        return
    end

    if player.sg:HasStateTag("moving")
        and player.components.locomotor ~= nil
        and player.components.locomotor:WantsToMoveForward()
    then
        player.sg:GoToState("run_start")
    else
        player.sg:GoToState("idle")
    end
end

AddModRPCHandler(KEI_RPC_NAMESPACE, "MutatedWargFlame", function(player, x, z)
    if player == nil or not player:HasTag("kei") then
        return
    end

    if not IsMutatedWargFlameReady(player) then
        return
    end

    local px, py, pz = player.Transform:GetWorldPosition()
    if x == nil or z == nil then
        return
    end
    local dx = x - px
    local dz = z - pz
    if dx * dx + dz * dz <= 0 then
        return
    end

    local fx = SpawnPrefab("kei_mutatedwarg_flamethrower")
    if fx == nil then
        return
    end

    player.components.sanity:DoDelta(-(TUNING.KEI_MUTATEDWARG_FLAMETHROWER_STABILITY_COST or 10))
    player:ForceFacePoint(x, py, z)
    StartMutatedWargFlameCooldown(player)

    fx.Transform:SetPosition(px, py, pz)
    fx:SetCaster(player, Vector3(x, py, z))
    player.kei_mutatedwarg_flamethrower_fx = fx
    player.kei_mutatedwarg_channelcasting = true
    fx:ListenForEvent("onremove", function()
        if player.kei_mutatedwarg_flamethrower_fx == fx then
            player.kei_mutatedwarg_flamethrower_fx = nil
        end
        player.kei_mutatedwarg_channelcasting = nil
        RefreshMutatedWargChannelcastAnimation(player)
    end)

    if player.sg ~= nil then
        player.sg:GoToState("kei_mutatedwarg_flamethrower")
    end
end)

AddModRPCHandler(KEI_RPC_NAMESPACE, "MapTeleport", function(player, x, z)
    local teleport_power_cost = TUNING.KEI_MAP_TELEPORT_POWER_COST or 30
    local hunger = player ~= nil and player.components.hunger or nil
    if player ~= nil and (hunger == nil or hunger.current < teleport_power_cost) then
        if player.components.talker ~= nil then
            player.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_MAP_TELEPORT_NO_POWER)
        end
        return
    end

    if player == nil
        or x == nil
        or z == nil
        or not player:HasTag("kei")
        or player:HasTag("playerghost")
        or player:HasTag("kei_dormant")
        or player:HasTag("noteleport")
        or player.sg == nil
        or player.components.kei_protocolslots == nil
        or not player.components.kei_protocolslots:HasLifeProtocol("map_teleport")
        or (player.components.health ~= nil and player.components.health:IsDead())
        or (player.components.rider ~= nil and player.components.rider:IsRiding())
        or (player.components.inventory ~= nil and player.components.inventory:IsHeavyLifting())
    then
        return
    end

    player.sg:GoToState("kei_map_teleport", Vector3(x, 0, z))
end)

AddModRPCHandler(KEI_RPC_NAMESPACE, "UpdateMutatedWargFlameAim", function(player, x, z)
    if player == nil
        or x == nil
        or z == nil
        or not player:HasTag("kei")
        or player:HasTag("playerghost")
        or player:HasTag("kei_dormant")
    then
        return
    end

    local fx = player.kei_mutatedwarg_flamethrower_fx
    if fx ~= nil and fx:IsValid() and fx.SetTargetPoint ~= nil then
        local _, y = player.Transform:GetWorldPosition()
        fx:SetTargetPoint(Vector3(x, y, z))
        player:ForceFacePoint(x, y, z)
    end
end)

-- Kei 的三项核心资源：电量、稳定性、机体完整度。
TUNING.KEI_MAX_POWER = 120 -- 最大电量上限
TUNING.KEI_MAX_STABILITY = 120 -- 最大稳定性上限
TUNING.KEI_MAX_INTEGRITY = 120 -- 最大机体完整度上限
TUNING.KEI_PROTOCOL_STAT_BONUS = 20 -- 每完成一次协议槽扩展时三维上限增加的数值

-- 设计中"普通食物转化电量效率较低"的实现参数。
TUNING.KEI_FOOD_ABSORPTION = 0.2 -- 普通食物转化为电量的效率系数（20%）
TUNING.KEI_BATTERY_POWER = 60 -- 电池类物品提供的电量值
TUNING.KEI_REPAIR_VALUE = 50 -- 修复物品恢复的机体完整度
TUNING.KEI_MAP_TELEPORT_POWER_COST = 30 -- 地图传送生活协议的单次电量消耗
TUNING.KEI_LIFE_GROWTH_ACCELERATION_RADIUS = 20
TUNING.KEI_LIFE_GROWTH_ACCELERATION_PERIOD = 1
TUNING.KEI_LIFE_GROWTH_ACCELERATION_PER_STACK = 2
TUNING.KEI_LIFE_DURABILITY_RESTORE_PERIOD = 60
TUNING.KEI_LIFE_DURABILITY_RESTORE_PER_STACK = 0.1
TUNING.KEI_DORMANT_POWER_DRAIN = 1 -- 休眠状态每秒消耗的电量
TUNING.KEI_DORMANT_STABILITY_REGEN = 3 -- 休眠状态每秒恢复的数据稳定性
TUNING.KEI_DORMANT_INTEGRITY_REGEN = 3 -- 休眠状态每秒恢复的机体完整度
TUNING.KEI_DORMANT_BATTERY_CHARGE_RATE = 3 -- 休眠时从薇诺娜发电机获得的每秒充电量
TUNING.KEI_DORMANT_ZERO_POWER_GRACE_TIME = 3 -- 休眠时电量为0后强制退出前的宽限时间

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
TUNING.KEI_EYEOFTERROR_DASH_DISTANCE = 16 -- 克眼协议单次冲锋的最大位移距离
TUNING.KEI_EYEOFTERROR_DASH_COOLDOWN = 1 -- 克眼协议冲锋冷却时间
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
TUNING.KEI_MINOTAUR_TENTACLE_LIFETIME = 30 -- 远古守卫者协议生成的暗影触手强制存在时间
TUNING.KEI_MINOTAUR_SHADOW_PRISON_CHANCE = 0.15 -- 远古守卫者协议触发暗影牢笼的概率
TUNING.KEI_STALKER_SHADOWSTRIKE_CHANCE = 0.30 -- 织影者协议触发影袭的概率
TUNING.KEI_STALKER_SHADOWSTRIKE_DAMAGE_MULT = 0.5 -- 影袭造成的额外伤害比例
TUNING.KEI_KLAUS_SOUL_CHANCE = 0.20 -- 克劳斯协议抽取灵魂并治疗周围单位的概率
TUNING.KEI_TOADSTOOL_SLEEPBOMB_CHANCE = 0.3 -- 蟾蜍协议触发睡眠炸弹弹药的概率
TUNING.KEI_TOADSTOOL_SLEEPBOMB_COOLDOWN = 0.5 -- 蟾蜍协议投掷睡眠炸弹弹药后的内置冷却
TUNING.KEI_MUTATEDBEARGER_ATTACK_SPEED_MULT = 1.3 -- 装甲熊獾协议攻击速度倍率
TUNING.KEI_VAULT_PILLAR_GUARD_ATTACK_SPEED_MULT = 1.2 -- 远古戍卫塔协议攻击速度倍率
TUNING.KEI_WAGBOSS_ORBITAL_STRIKE_COOLDOWN = 20 -- 战争瓦器人协议轨道打击冷却时间
TUNING.KEI_WAGBOSS_ORBITAL_STRIKE_MAX_HEALTH_DPS = 0.03 -- 战争瓦器人协议月能灼烧每秒按目标最大生命值计算的比例
TUNING.KEI_WAGBOSS_ORBITAL_STRIKE_BONUS_DPS = 50 -- 战争瓦器人协议月能灼烧每秒追加伤害
TUNING.KEI_CELESTIAL_ORB_COUNT = 3 -- 天体后裔协议环绕宝珠数量
TUNING.KEI_CELESTIAL_ORB_RADIUS = 2.7 -- 天体后裔协议宝珠环绕半径
TUNING.KEI_CELESTIAL_ORB_HEIGHT = 1.35 -- 天体后裔协议宝珠显示高度
TUNING.KEI_CELESTIAL_ORB_IDLE_SPEED = 0.012 -- 天体后裔协议宝珠常态旋转速度
TUNING.KEI_CELESTIAL_ORB_ATTACK_SPEED = 0.22 -- 天体后裔协议宝珠攻击触发后的旋转速度
TUNING.KEI_CELESTIAL_ORB_ACCEL_DURATION = 1.25 -- 天体后裔协议攻击后宝珠加速持续时间
TUNING.KEI_CELESTIAL_ORB_DAMAGE_MULT = 0.5 -- 天体后裔协议追加伤害占本次伤害的比例
TUNING.KEI_CELESTIAL_ORB_HIT_RADIUS = 1.35 -- 天体后裔协议宝珠命中半径
TUNING.KEI_MUTATEDDEERCLOPS_AURA_RADIUS = 5.5 -- 独眼晶体巨鹿协议寒冷圈半径
TUNING.KEI_MUTATEDDEERCLOPS_AURA_DURATION = 5 -- 独眼晶体巨鹿协议寒冷圈持续时间
TUNING.KEI_MUTATEDDEERCLOPS_AURA_COOLDOWN = 3 -- 独眼晶体巨鹿协议寒冷圈触发冷却
TUNING.KEI_MUTATEDDEERCLOPS_AURA_SLOW_MULT = 0.5 -- 独眼晶体巨鹿协议寒冷圈动画与移速倍率
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

local containers = require("containers")
containers.params.kei_protocol_container = deepcopy(containers.params.wx78_inventorycontainer)
containers.params.kei_protocol_container.itemtestfn = function(container, item, slot)
    return item ~= nil and item:HasTag("kei_protocol_cd")
end
containers.params.kei_protocol_container.priorityfn = nil
containers.params.kei_protocol_container.widget.animbank = "kei_protocol_popup"
containers.params.kei_protocol_container.widget.animbuild = "kei_protocol_popup"
containers.params.kei_protocol_container.widget.slotpos = {
    Vector3(0, -7, 0),
}
containers.params.kei_protocol_container.widget.slotscale = 1.3
containers.params.kei_protocol_container.widget.slothighlightscale = 1.15
containers.params.kei_protocol_container.widget.animloop = nil
containers.params.kei_protocol_container.widget.slotbg = {
    {
        atlas = "images/transparent_slot.xml",
        image = "transparent_slot.tex",
    },
}
containers.params.kei_protocol_container.widget.animfn = function(container, doer, anim)
    if anim == "open" then
        return "opening"
    elseif anim == "close" then
        return "closing"
    end
    return anim
end

local function ContainerHasRoomForItem(container, item)
    if container == nil
        or item == nil
        or not container:CanTakeItemInSlot(item)
    then
        return false
    end

    for slot = 1, container:GetNumSlots() do
        local stored = container:GetItemInSlot(slot)
        if stored == nil then
            if container:CanTakeItemInSlot(item, slot) then
                return true
            end
        elseif container:AcceptsStacks()
            and stored.components.stackable ~= nil
            and not stored.components.stackable:IsFull()
            and stored.components.stackable:CanStackWith(item)
        then
            return true
        end
    end

    return false
end

local function InventoryHasNonProtocolRoomForItem(inventory, item)
    if inventory == nil
        or item == nil
        or not inventory:IsOpenedBy(inventory.inst)
    then
        return false
    end

    local slot, target = inventory:GetNextAvailableSlot(item)
    return slot ~= nil
        and not (target ~= nil and target.inst ~= nil and target.inst:HasTag("kei_protocol_slot"))
end

local function FindOpenProtocolBinderWithRoom(opener, item)
    local inventory = opener ~= nil and opener.components.inventory or nil
    if inventory == nil then
        return nil
    end

    for container_inst in pairs(inventory.opencontainers) do
        local container = container_inst.components.container
        if container_inst:HasTag("kei_protocol_binder")
            and container ~= nil
            and container:IsOpenedBy(opener)
            and ContainerHasRoomForItem(container, item)
        then
            return container_inst
        end
    end
end

AddComponentPostInit("container", function(self)
    local old_MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot

    function self:MoveItemFromAllOfSlot(slot, container, opener, ...)
        local item = self:GetItemInSlot(slot)
        if opener ~= nil
            and self.inst:HasTag("kei_protocol_slot")
            and item ~= nil
            and item:HasTag("kei_protocol_cd")
            and item.components.inventoryitem ~= nil
            and not item.components.inventoryitem.islockedinslot
        then
            local binder = FindOpenProtocolBinderWithRoom(opener, item)
            if binder ~= nil then
                old_MoveItemFromAllOfSlot(self, slot, binder, opener, ...)
                return
            end

            if InventoryHasNonProtocolRoomForItem(opener.components.inventory, item) then
                old_MoveItemFromAllOfSlot(self, slot, opener, opener, ...)
                return
            end

            return
        end

        old_MoveItemFromAllOfSlot(self, slot, container, opener, ...)
    end
end)

local function ClientContainerHasRoomForItem(container, item)
    if container == nil
        or item == nil
        or not container:CanTakeItemInSlot(item)
    then
        return false
    end

    local item_stackable = item.replica.stackable
    if container:AcceptsStacks() and item_stackable ~= nil then
        for _, stored in pairs(container:GetItems()) do
            local stored_stackable = stored.replica.stackable
            if stored_stackable ~= nil
                and not stored_stackable:IsFull()
                and stored_stackable:CanStackWith(item)
            then
                return true
            end
        end
    end

    for slot = 1, container:GetNumSlots() do
        if container:GetItemInSlot(slot) == nil and container:CanTakeItemInSlot(item, slot) then
            return true
        end
    end

    return false
end

local function ClientFindOpenProtocolBinderWithRoom(character, item)
    local inventory = character ~= nil and character.replica.inventory or nil
    local opencontainers = inventory ~= nil and inventory:GetOpenContainers() or nil
    if opencontainers == nil then
        return nil
    end

    for container_inst in pairs(opencontainers) do
        local container = container_inst.replica.container
        if container_inst:HasTag("kei_protocol_binder")
            and container ~= nil
            and container:IsOpenedBy(character)
            and ClientContainerHasRoomForItem(container, item)
        then
            return container_inst
        end
    end
end

local function ClientInventoryHasRoomForItem(character, item)
    local inventory = character ~= nil and character.replica.inventory or nil
    if inventory == nil or item == nil then
        return false
    end

    if ClientContainerHasRoomForItem(inventory, item) then
        return true
    end

    local overflow = inventory:GetOverflowContainer()
    return overflow ~= nil and ClientContainerHasRoomForItem(overflow, item)
end

if not TheNet:IsDedicated() then
    AddClassPostConstruct("widgets/invslot", function(self)
        local old_TradeItem = self.TradeItem

        function self:TradeItem(stack_mod, ...)
            local slot_number = self.num
            local character = self.owner
            local inventory = character ~= nil and character.replica.inventory or nil
            local container = self.container
            local container_inst = container ~= nil and container.inst or nil
            local container_item = container ~= nil
                and (container.IsReadOnlyContainer == nil or not container:IsReadOnlyContainer())
                and container:GetItemInSlot(slot_number)
                or nil

            if not stack_mod
                and character ~= nil
                and inventory ~= nil
                and container_inst ~= nil
                and container_inst:HasTag("kei_protocol_slot")
                and container_item ~= nil
                and container_item:HasTag("kei_protocol_cd")
                and container_item.replica.inventoryitem ~= nil
                and not container_item.replica.inventoryitem:IsLockedInSlot()
            then
                local dest_inst = ClientFindOpenProtocolBinderWithRoom(character, container_item)
                if dest_inst == nil and ClientInventoryHasRoomForItem(character, container_item) then
                    dest_inst = character
                end

                if dest_inst ~= nil then
                    container:MoveItemFromAllOfSlot(slot_number, dest_inst)
                    TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_object")
                else
                    TheFocalPoint.SoundEmitter:PlaySound("dontstarve/HUD/click_negative")
                end
                return
            end

            return old_TradeItem(self, stack_mod, ...)
        end
    end)
end

local function MakeProtocolBinderSlotPositions(count)
    local slots = {}
    local spacing = 75
    local start = -spacing * (count - 1) * 0.5
    for i = 1, count do
        slots[i] = Vector3(start + spacing * (i - 1), 0, 0)
    end
    return slots
end

local function MakeProtocolBinderSlotBgs(count)
    local slotbgs = {}
    for i = 1, count do
        slotbgs[i] = {
            atlas = "images/transparent_slot.xml",
            image = "transparent_slot.tex",
        }
    end
    return slotbgs
end

local protocol_binder_slots = TUNING.KEI_PROTOCOL_SLOT_HARD_MAX or 7
local protocol_binder_width = 75 * math.max(protocol_binder_slots - 1, 0)
local PROTOCOL_BINDER_BUTTON_COOLDOWN = 0.5

local function RefreshProtocolBinderButton(inst)
    if inst ~= nil and ThePlayer ~= nil then
        inst:PushEvent("itemget", {})
    end
end

local function IsProtocolBinderButtonCoolingDown(inst)
    return inst ~= nil
        and inst._kei_protocol_binder_button_ready_time ~= nil
        and GetTime() < inst._kei_protocol_binder_button_ready_time
end

local function StartProtocolBinderButtonCooldown(inst)
    if inst == nil or IsProtocolBinderButtonCoolingDown(inst) then
        return false
    end

    inst._kei_protocol_binder_button_ready_time = GetTime() + PROTOCOL_BINDER_BUTTON_COOLDOWN
    RefreshProtocolBinderButton(inst)

    if inst._kei_protocol_binder_button_task ~= nil then
        inst._kei_protocol_binder_button_task:Cancel()
    end
    inst._kei_protocol_binder_button_task = inst:DoTaskInTime(PROTOCOL_BINDER_BUTTON_COOLDOWN, function()
        inst._kei_protocol_binder_button_ready_time = nil
        inst._kei_protocol_binder_button_task = nil
        RefreshProtocolBinderButton(inst)
    end)

    return true
end

containers.params.kei_protocol_binder = {
    widget = {
        slotpos = {
            Vector3(-267, 3, 0),
            Vector3(-190, 3, 0),
            Vector3(-113, 3, 0),
            Vector3(-36, 3, 0),
            Vector3(41, 3, 0),
            Vector3(118, 3, 0),
            Vector3(195, 3, 0),
        },
        slotbg = MakeProtocolBinderSlotBgs(protocol_binder_slots),
        animbank = "ui_kei_protocol_box_7x1",
        animbuild = "ui_kei_protocol_box_7x1",
        animfn = function(container, doer, anim)
            if anim == "open" then
                return "opening"
            elseif anim == "close" then
                return "closing"
            end
            return anim
        end,
        pos = Vector3(0, 200, 0),
        side_align_tip = math.max(160, protocol_binder_width * 0.5 + 120),
        buttoninfo = {
            text = "交换",
            position = Vector3(305, 5, 0),
        },
    },
    type = "kei_protocol_binder",
    openlimit = 1,
    acceptsstacks = false,
}

function containers.params.kei_protocol_binder.itemtestfn(container, item, slot)
    return item ~= nil and item:HasTag("kei_protocol_cd")
end

function containers.params.kei_protocol_binder.widget.buttoninfo.fn(inst, doer)
    if not StartProtocolBinderButtonCooldown(inst) then
        return
    end

    if inst.SwapWithProtocolSlots ~= nil then
        inst:SwapWithProtocolSlots(doer)
    elseif inst.replica.container ~= nil then
        SendRPCToServer(RPC.DoWidgetButtonAction, nil, inst, nil)
    end
end

function containers.params.kei_protocol_binder.widget.buttoninfo.validfn(inst)
    return inst ~= nil
        and inst.replica.container ~= nil
        and not IsProtocolBinderButtonCoolingDown(inst)
end

local KEI_CONTROL_IMMUNE_EVENTS = {
    suspended = true,
    knockback = true,
}

local function AddKeiStaggerImmunityToStategraph(sg)
    if sg.events == nil or sg.events.attacked == nil then
        return
    end

    local old_attacked_fn = sg.events.attacked.fn
    sg.events.attacked.fn = function(inst, data)
        if inst:HasTag("kei_stagger_immune") then
            return
        end
        return old_attacked_fn ~= nil and old_attacked_fn(inst, data) or nil
    end
end

AddStategraphPostInit("wilson", AddKeiStaggerImmunityToStategraph)
AddStategraphPostInit("wilson_client", AddKeiStaggerImmunityToStategraph)

local function AddKeiControlImmunityToStategraph(sg)
    if sg.events == nil then
        return
    end

    for eventname in pairs(KEI_CONTROL_IMMUNE_EVENTS) do
        local event = sg.events[eventname]
        if event ~= nil and event.fn ~= nil then
            local old_fn = event.fn
            event.fn = function(inst, ...)
                if inst:HasTag("kei_control_immune") then
                    return
                end
                return old_fn(inst, ...)
            end
        end
    end
end

AddStategraphPostInit("wilson", AddKeiControlImmunityToStategraph)
AddStategraphPostInit("wilson_client", AddKeiControlImmunityToStategraph)

local function GetKeiAttackSpeedMult(inst)
    if inst == nil then
        return 1
    end

    local mult = 1
    if inst:HasTag("kei_attack_speed_boost") then
        mult = mult * (TUNING.KEI_MUTATEDBEARGER_ATTACK_SPEED_MULT or 1)
    end
    if inst:HasTag("kei_vault_pillar_guard_spin") then
        mult = mult * (TUNING.KEI_VAULT_PILLAR_GUARD_ATTACK_SPEED_MULT or 1)
    end
    return mult > 1 and mult or 1
end

local function ApplyKeiAttackSpeedToAttackState(inst, state)
    if inst.sg == nil or inst.sg.currentstate ~= state then
        return
    end

    local mult = GetKeiAttackSpeedMult(inst)
    if mult <= 1 then
        return
    end

    inst.sg.statemem.kei_attack_speed_mult = mult

    local combat = inst.components ~= nil and inst.components.combat or nil
    if combat ~= nil and combat.laststartattacktime ~= nil then
        local period = combat.min_attack_period or 0
        if period > 0 then
            combat.laststartattacktime = combat.laststartattacktime - period * (1 - 1 / mult)
        end
    end

    if inst.AnimState ~= nil then
        inst.AnimState:SetDeltaTimeMultiplier(mult)
    end

    if type(inst.sg.timeout) == "number" and inst.sg.timeout > 0 then
        inst.sg:SetTimeout(inst.sg.timeout / mult)
    end
end

local function ClearKeiAttackSpeedFromAttackState(inst)
    if inst.sg ~= nil
        and inst.sg.statemem ~= nil
        and inst.sg.statemem.kei_attack_speed_mult ~= nil
        and inst.AnimState ~= nil then
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end
end

local function GetKeiEquippedHandItem(inst)
    if inst.components ~= nil
        and inst.components.inventory ~= nil then
        return inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    end
    if inst.replica ~= nil
        and inst.replica.inventory ~= nil then
        return inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    end
    return nil
end

local function GetWeaponAttackRange(item)
    if item == nil then
        return nil
    end
    if item.components ~= nil
        and item.components.weapon ~= nil then
        return item.components.weapon.attackrange or 0
    end
    if item.replica ~= nil
        and item.replica.inventoryitem ~= nil
        and item.replica.inventoryitem.IsWeapon ~= nil
        and item.replica.inventoryitem:IsWeapon() then
        return item.replica.inventoryitem:AttackRange() or 0
    end
    return nil
end

local function IsKeiRiding(inst)
    if inst.components ~= nil
        and inst.components.rider ~= nil then
        return inst.components.rider:IsRiding()
    end
    if inst.replica ~= nil
        and inst.replica.rider ~= nil then
        return inst.replica.rider:IsRiding()
    end
    return false
end

local function ShouldUseKeiVaultPillarGuardSpinAttack(inst)
    if inst == nil
        or not inst:HasTag("kei_vault_pillar_guard_spin")
        or inst:HasTag("playerghost")
        or inst:HasTag("kei_dormant")
        or IsKeiRiding(inst)
    then
        return false
    end

    local equip = GetKeiEquippedHandItem(inst)
    if equip == nil
        or equip:HasTag("punch")
        or equip:HasTag("projectile")
        or equip:HasTag("rangedweapon")
    then
        return false
    end

    local range = GetWeaponAttackRange(equip)
    return range ~= nil and range <= 1
end

local function ApplyKeiVaultPillarGuardSpinAttack(inst, state)
    if inst.sg == nil
        or inst.sg.currentstate ~= state
        or not ShouldUseKeiVaultPillarGuardSpinAttack(inst)
    then
        return
    end

    inst.sg.statemem.kei_vault_pillar_guard_spin = true
    inst.AnimState:PlayAnimation("wx_spin_attack_loop_slow")
    inst.AnimState:PushAnimation("wx_spin_attack_pst", false)
end

local KEI_VAULT_PILLAR_GUARD_SPIN_MUST_TAGS = { "_combat" }
local KEI_VAULT_PILLAR_GUARD_SPIN_CANT_TAGS = {
    "INLIMBO",
    "NOCLICK",
    "FX",
    "decor",
    "companion",
    "flight",
    "invisible",
    "notarget",
    "noattack",
    "playerghost",
}

local function DoKeiVaultPillarGuardSpinAOE(inst)
    if TheWorld == nil
        or not TheWorld.ismastersim
        or inst.sg == nil
        or inst.sg.statemem == nil
        or not inst.sg.statemem.kei_vault_pillar_guard_spin
        or inst.components == nil
        or inst.components.combat == nil
    then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local attacktarget = inst.sg.statemem.attacktarget
    local radius = TUNING.WX78_SPIN_RADIUS or 2.1
    for _, target in ipairs(TheSim:FindEntities(
        x, y, z,
        radius + 3,
        KEI_VAULT_PILLAR_GUARD_SPIN_MUST_TAGS,
        KEI_VAULT_PILLAR_GUARD_SPIN_CANT_TAGS
    )) do
        if target ~= inst
            and target ~= attacktarget
            and target:IsValid()
            and target.entity:IsVisible()
            and target.components.health ~= nil
            and not target.components.health:IsDead()
            and inst.components.combat:CanTarget(target)
            and not inst.components.combat:IsAlly(target)
        then
            local range = radius + target:GetPhysicsRadius(0)
            if target:GetDistanceSqToPoint(x, y, z) < range * range then
                inst.components.combat:DoAttack(target)
            end
        end
    end
end

local function InsertStateTimelineEvent(timeline, event)
    if timeline == nil then
        return
    end
    local insert_index = #timeline + 1
    for index, timeline_event in ipairs(timeline) do
        if timeline_event.time > event.time then
            insert_index = index
            break
        end
    end
    table.insert(timeline, insert_index, event)
end

local function AddKeiAttackStateOverridesToStategraph(sg)
    local state = sg.states ~= nil and sg.states.attack or nil
    if state == nil then
        return
    end

    local old_onenter = state.onenter
    state.onenter = function(inst, ...)
        if old_onenter ~= nil then
            old_onenter(inst, ...)
        end
        ApplyKeiVaultPillarGuardSpinAttack(inst, state)
        ApplyKeiAttackSpeedToAttackState(inst, state)
    end

    local old_onexit = state.onexit
    state.onexit = function(inst, ...)
        if old_onexit ~= nil then
            old_onexit(inst, ...)
        end
        ClearKeiAttackSpeedFromAttackState(inst)
    end

    InsertStateTimelineEvent(state.timeline, TimeEvent(8 * FRAMES, DoKeiVaultPillarGuardSpinAOE))
end

AddStategraphPostInit("wilson", AddKeiAttackStateOverridesToStategraph)
AddStategraphPostInit("wilson_client", AddKeiAttackStateOverridesToStategraph)

if StateGraphInstance ~= nil and StateGraphInstance.UpdateState ~= nil then
    local old_StateGraphInstance_UpdateState = StateGraphInstance.UpdateState
    function StateGraphInstance:UpdateState(dt)
        if self.inst ~= nil and self.inst:HasTag("kei_mutateddeerclops_sg_slow") then
            dt = dt * (TUNING.KEI_MUTATEDDEERCLOPS_AURA_SLOW_MULT or 0.5)
        end
        return old_StateGraphInstance_UpdateState(self, dt)
    end
end

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
modimport("scripts/kei_winona_compat.lua")
modimport("scripts/kei_recipes.lua")
modimport("scripts/kei_wanderingtrader_trades.lua")

if not TheNet:IsDedicated() then
    AddClassPostConstruct("screens/mapscreen", function(self)
        local old_OnMouseButton = self.OnMouseButton
        self.OnMouseButton = function(self, button, down, ...)
            local player = ThePlayer
            if down
                and button == MOUSEBUTTON_RIGHT
                and player ~= nil
                and player:HasTag("kei")
                and not player:HasTag("playerghost")
                   and not player:HasTag("kei_dormant")
                   and player._kei_map_teleport_protocol_active ~= nil
                   and player._kei_map_teleport_protocol_active:value()
                   and player.replica.hunger ~= nil
                   and player.replica.hunger:GetCurrent() >= (TUNING.KEI_MAP_TELEPORT_POWER_COST or 30)
                   and player.replica.inventory ~= nil
                and player.replica.inventory:GetActiveItem() == nil
                and (player.replica.rider == nil or not player.replica.rider:IsRiding())
                and (player.replica.inventory == nil or not player.replica.inventory:IsHeavyLifting())
                and self.minimap ~= nil
                and self.WidgetPosToMapPos ~= nil
                and self.ScreenPosToWidgetPos ~= nil
            then
                local screenpos = TheInput:GetScreenPosition()
                local mousemappos = self:WidgetPosToMapPos(self:ScreenPosToWidgetPos(screenpos))
                local x, z = self.minimap:MapPosToWorldPos(mousemappos:Get())
                SendModRPCToServer(MOD_RPC[KEI_RPC_NAMESPACE].MapTeleport, x, z)
                TheFrontEnd:PopScreen(self)
                return true
            end

            return old_OnMouseButton ~= nil and old_OnMouseButton(self, button, down, ...) or false
        end
    end)
end

if not TheNet:IsDedicated() and TheInput ~= nil then
    local kei_mutatedwarg_key_down = false
    local kei_mutatedwarg_aim_update_task = nil
    local kei_mutatedwarg_aim_update_stop_task = nil
    local kei_mutatedwarg_channelcast_stop_task = nil

    local function SetLocalMutatedWargChannelcasting(player, enabled)
        if player == nil then
            return
        end
        player.kei_mutatedwarg_channelcasting = enabled == true or nil
        RefreshMutatedWargChannelcastAnimation(player)
    end

    local function StopMutatedWargAimUpdates()
        if kei_mutatedwarg_aim_update_task ~= nil then
            kei_mutatedwarg_aim_update_task:Cancel()
            kei_mutatedwarg_aim_update_task = nil
        end
        if kei_mutatedwarg_aim_update_stop_task ~= nil then
            kei_mutatedwarg_aim_update_stop_task:Cancel()
            kei_mutatedwarg_aim_update_stop_task = nil
        end
        if kei_mutatedwarg_channelcast_stop_task ~= nil then
            kei_mutatedwarg_channelcast_stop_task:Cancel()
            kei_mutatedwarg_channelcast_stop_task = nil
        end
        SetLocalMutatedWargChannelcasting(ThePlayer, false)
    end

    local function SendMutatedWargAimUpdate()
        local player = ThePlayer
        if player == nil
            or player:HasTag("playerghost")
            or player:HasTag("kei_dormant")
            or player._kei_mutatedwarg_protocol_active == nil
            or not player._kei_mutatedwarg_protocol_active:value()
        then
            StopMutatedWargAimUpdates()
            return
        end

        local pos = TheInput:GetWorldPosition()
        if pos ~= nil then
            SendModRPCToServer(MOD_RPC[KEI_RPC_NAMESPACE].UpdateMutatedWargFlameAim, pos.x, pos.z)
        end
    end

    local function StartMutatedWargAimUpdates(player)
        StopMutatedWargAimUpdates()
        SetLocalMutatedWargChannelcasting(player, true)
        SendMutatedWargAimUpdate()
        kei_mutatedwarg_aim_update_task = player:DoPeriodicTask(
            TUNING.KEI_MUTATEDWARG_FLAMETHROWER_AIM_UPDATE_PERIOD or 0.1,
            SendMutatedWargAimUpdate
        )
        kei_mutatedwarg_aim_update_stop_task = player:DoTaskInTime(
            (TUNING.KEI_MUTATEDWARG_FLAMETHROWER_DURATION or 5) + 0.25,
            StopMutatedWargAimUpdates
        )
        kei_mutatedwarg_channelcast_stop_task = player:DoTaskInTime(
            TUNING.KEI_MUTATEDWARG_FLAMETHROWER_DURATION or 5,
            function()
                SetLocalMutatedWargChannelcasting(player, false)
                kei_mutatedwarg_channelcast_stop_task = nil
            end
        )
    end

    TheInput:AddKeyDownHandler(KEY_Z, function()
        if kei_mutatedwarg_key_down then
            return
        end
        kei_mutatedwarg_key_down = true
        local player = ThePlayer
        local screen = TheFrontEnd ~= nil and TheFrontEnd:GetActiveScreen() or nil
        if player ~= nil
            and screen ~= nil
            and screen.name == "HUD"
            and player:HasTag("kei")
            and player._kei_mutatedwarg_protocol_active ~= nil
            and player._kei_mutatedwarg_protocol_active:value()
            and not player:HasTag("playerghost")
            and not player:HasTag("kei_dormant")
            and player.replica.inventory ~= nil
            and player.replica.inventory:GetActiveItem() == nil
        then
            local pos = TheInput:GetWorldPosition()
            if pos ~= nil then
                SendModRPCToServer(MOD_RPC[KEI_RPC_NAMESPACE].MutatedWargFlame, pos.x, pos.z)
                StartMutatedWargAimUpdates(player)
            end
        end
    end)
    TheInput:AddKeyUpHandler(KEY_Z, function()
        kei_mutatedwarg_key_down = false
    end)
end

-- 注册可选角色。
AddModCharacter("kei", "FEMALE")
