local MakePlayerCharacter = require("prefabs/player_common")

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("ANIM", "anim/player_idles_wendy.zip"),
}

local prefabs = {
    "kei_battery",
}

-- 初始物品先给一组电池，保证角色刚进世界时可以测试电量循环。
local start_inv = {
    "kei_battery",
    "kei_battery",
    "kei_battery",
    "kei_battery",
    "kei_battery",
}

local function ConfigureVisuals(inst)
    -- 角色专属动画资源尚未制作时，先用 Wendy 的 build 和小地图图标占位。
    inst.AnimState:SetBuild("wendy")
    inst.MiniMapEntity:SetIcon("wendy.png")
end

local function common_postinit(inst)
    -- 标签用于动作过滤、专属配方解锁，以及电击免疫等基础设定。
    inst:AddTag("kei")
    inst:AddTag("electricdamageimmune")
    inst:AddTag("batteryuser")
    ConfigureVisuals(inst)
end

local function OnEat(inst, food)
    if food ~= nil and food.components.edible ~= nil then
        -- 饥饿值在原组件中会先完整结算，这里再扣回 80%，等价于只吸收 20%。
        local hunger = food.components.edible:GetHunger(inst) or 0
        local full = hunger
        local reduced = hunger * TUNING.KEI_FOOD_ABSORPTION
        if full ~= reduced and inst.components.hunger ~= nil then
            inst.components.hunger:DoDelta(reduced - full)
        end
    end
end

local function UpdateIntegrityState(inst)
    -- 定时检查把“电量”和“机体完整度”的特殊规则挂到原生 hunger/health 上。
    if inst.components.health == nil or inst.components.hunger == nil or inst.components.locomotor == nil then
        return
    end

    local health = inst.components.health
    local hunger = inst.components.hunger
    if health:IsDead() then
        return
    end

    if hunger.current <= 0 then
        -- 电量耗尽后移动速度几乎归零，移动中还会持续损伤完整度。
        inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kei_no_power", 0.1)
        if inst.sg ~= nil and inst.sg:HasStateTag("moving") then
            health:DoDelta(-TUNING.KEI_LOW_POWER_DAMAGE * TUNING.KEI_SELF_REPAIR_PERIOD, true, "kei_no_power")
        end
    else
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "kei_no_power")
    end

    local low_threshold = health.maxhealth / 6
    if health.current <= low_threshold then
        -- 完整度过低时进入危险状态：减速、缓慢恶化，并周期性提示玩家。
        inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kei_low_integrity", 0.5)
        health:DoDelta(-1, true, "kei_low_integrity")
        if inst._kei_low_integrity_say_time == nil or GetTime() - inst._kei_low_integrity_say_time > 12 then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_LOW_INTEGRITY)
            inst._kei_low_integrity_say_time = GetTime()
        end
    else
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "kei_low_integrity")
    end

    if health.current > health.maxhealth * 5 / 6 and health.current < health.maxhealth then
        -- 高完整度区间允许机体自我修复，作为设计里的恢复特性。
        health:DoDelta(1, true, "kei_self_repair")
    end
end

local function OnSave(inst, data)
    -- 协议槽组件不是标准角色字段，需要主动写入角色存档。
    if inst.components.kei_protocolslots ~= nil then
        data.kei_protocolslots = inst.components.kei_protocolslots:OnSave()
    end
end

local function OnLoad(inst, data)
    if data ~= nil and data.kei_protocolslots ~= nil and inst.components.kei_protocolslots ~= nil then
        inst.components.kei_protocolslots:OnLoad(data.kei_protocolslots)
    end
end

local function master_postinit(inst)
    ConfigureVisuals(inst)

    inst.starting_inventory = start_inv

    -- 用原版三维组件承载设计文档中的完整度 / 电量 / 稳定性。
    inst.components.health:SetMaxHealth(TUNING.KEI_MAX_INTEGRITY)
    inst.components.hunger:SetMax(TUNING.KEI_MAX_POWER)
    inst.components.sanity:SetMax(TUNING.KEI_MAX_STABILITY)

    -- 稳定性不自然涨落，也不受常规光照、鬼魂和光环影响。
    inst.components.sanity.rate_modifier = 0
    inst.components.sanity.no_moisture_penalty = true
    inst.components.sanity:SetFullAuraImmunity(true)
    inst.components.sanity:SetNegativeAuraImmunity(true)
    inst.components.sanity:SetPlayerGhostImmunity(true)
    inst.components.sanity:SetLightDrainImmune(true)

    if inst.components.eater ~= nil then
        -- 禁用食物回血和回理智，仅保留食物转换为电量的路径。
        inst.components.eater:SetAbsorptionModifiers(0, 1, 0)
        inst.components.eater:SetCanEatGears()
        inst.components.eater:SetOnEatFn(OnEat)
    end

    -- 协议槽负责扫描背包前 1/3/5/7 格中的协议 CD 并施加效果。
    inst:AddComponent("kei_protocolslots")

    inst:DoPeriodicTask(TUNING.KEI_SELF_REPAIR_PERIOD, UpdateIntegrityState)

    -- MakePlayerCharacter 会调用角色实例上的 OnSave / OnLoad 字段。
    inst._OnSave = OnSave
    inst._OnLoad = OnLoad
end

return MakePlayerCharacter("kei", prefabs, assets, common_postinit, master_postinit)
