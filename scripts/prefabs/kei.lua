local MakePlayerCharacter = require("prefabs/player_common")
local EyeOfTerrorDash = require("kei_eyeofterror_dash")

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("ANIM", "anim/kei.zip"),
    Asset("ANIM", "anim/ghost_kei_build.zip"),
    Asset("ANIM", "anim/player_idles_kei.zip"),
}

local prefabs = {
    "kei_battery",
    "kei_protocol_container",
}

-- 初始物品先给一组电池，保证角色刚进世界时可以测试电量循环。
local start_inv = {
    "kei_battery",
    "kei_battery",
    "kei_battery",
    "kei_battery",
    "kei_battery",
}

local function GetPointSpecialActions(inst, pos, useitem, right, usereticulepos)
    if right
        and useitem == nil
        and ACTIONS.KEI_EYEOFTERROR_DASH ~= nil
        and EyeOfTerrorDash.HasProtocol(inst)
        and not inst:HasTag("playerghost")
    then
        local targetpos = usereticulepos and EyeOfTerrorDash.ReticuleTargetFn(inst) or EyeOfTerrorDash.GetTargetPoint(inst, pos)
        if targetpos ~= nil then
            return { ACTIONS.KEI_EYEOFTERROR_DASH }, targetpos
        end
    end
    return {}
end

local function OnSetOwner(inst)
    if inst.components.playeractionpicker ~= nil then
        inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
    end
end

local function ConfigureVisuals(inst)
    -- 使用 Kei 自己的角色 build；角色 id、文件名和资源 build 统一为小写 kei。
    inst.AnimState:SetBuild("kei")
    inst.MiniMapEntity:SetIcon("kei.tex")
end

local function common_postinit(inst)
    -- 标签用于动作过滤、专属配方解锁，以及电击免疫等基础设定。
    inst:AddTag("kei")
    inst:AddTag("electricdamageimmune")
    inst:AddTag("batteryuser")
    inst:AddTag(FOODTYPE.KEI_DEVICE .. "_eater")

    inst._kei_unlocked_protocol_slots = net_smallbyte(inst.GUID, "kei.unlocked_protocol_slots", "kei_protocol_slots_dirty")
    inst._kei_eyeofterror_protocol_active = net_bool(inst.GUID, "kei.eyeofterror_protocol_active", "kei_eyeofterror_protocol_dirty")

    inst:AddComponent("reticule")
    inst.components.reticule.reticuleprefab = "reticuleline"
    inst.components.reticule.pingprefab = nil
    inst.components.reticule.targetfn = EyeOfTerrorDash.ReticuleTargetFn
    inst.components.reticule.mousetargetfn = EyeOfTerrorDash.ReticuleMouseTargetFn
    inst.components.reticule.updatepositionfn = EyeOfTerrorDash.ReticuleUpdatePositionFn
    inst.components.reticule.validcolour = { 1, 0.2, 0.2, 0 }
    inst.components.reticule.invalidcolour = { 0.5, 0, 0, 0 }
    inst.components.reticule.ease = true
    inst.components.reticule.mouseenabled = true
    inst.components.reticule.twinstickcheckscheme = true
    inst.components.reticule.twinstickmode = 1
    inst.components.reticule.twinstickrange = TUNING.KEI_EYEOFTERROR_DASH_DISTANCE or 12

    inst:ListenForEvent("setowner", OnSetOwner)

    ConfigureVisuals(inst)
end

local function HandleKeiDeviceEat(inst, food)
    if food:HasTag("kei_battery") then
        if inst.components.hunger ~= nil then
            inst.components.hunger:DoDelta(TUNING.KEI_BATTERY_POWER)
        end
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_CHARGED)
        end
        return true
    elseif food:HasTag("kei_repair_tool") then
        if inst.components.health ~= nil and not inst.components.health:IsDead() then
            inst.components.health:DoDelta(TUNING.KEI_REPAIR_VALUE, nil, "kei_repair_tool")
        end
        if inst.components.talker ~= nil then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_REPAIRED)
        end
        return true
    end
    return false
end

local function OnEat(inst, food)
    if food ~= nil and food.components.edible ~= nil then
        if food.components.edible.foodtype == FOODTYPE.KEI_DEVICE and HandleKeiDeviceEat(inst, food) then
            return
        end

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

    local current_power = hunger.current or 0
    local current_integrity = health.currenthealth or health.maxhealth or 0
    local max_integrity = health.maxhealth or TUNING.KEI_MAX_INTEGRITY

    if current_power <= 0 then
        -- 电量耗尽后移动速度几乎归零，移动中还会持续损伤完整度。
        inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kei_no_power", 0.1)
        if inst.sg ~= nil and inst.sg:HasStateTag("moving") then
            health:DoDelta(-TUNING.KEI_LOW_POWER_DAMAGE * TUNING.KEI_SELF_REPAIR_PERIOD, true, "kei_no_power")
        end
    else
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "kei_no_power")
    end

    local low_threshold = max_integrity / 6
    if current_integrity <= low_threshold then
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

    if current_integrity > max_integrity * 5 / 6 and current_integrity < max_integrity then
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
        table.insert(inst.components.eater.caneat, FOODTYPE.KEI_DEVICE)
        table.insert(inst.components.eater.preferseating, FOODTYPE.KEI_DEVICE)
        inst.components.eater.cacheedibletags = nil
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
