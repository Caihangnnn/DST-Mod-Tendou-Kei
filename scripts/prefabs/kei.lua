local MakePlayerCharacter = require("prefabs/player_common")
local PlayerCommonExtensions = require("prefabs/player_common_extensions")
local EyeOfTerrorDash = require("kei_eyeofterror_dash")
local DaywalkerLeap = require("kei_daywalker_leap")

local assets = {
    Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
    Asset("ANIM", "anim/kei.zip"),
    Asset("ANIM", "anim/ghost_kei_build.zip"),
    Asset("ANIM", "anim/player_idles_kei.zip"),
    Asset("ANIM", "anim/wx_chassis.zip"),
}

local prefabs = {
    "kei_battery",
    "kei_dormant_chassis",
    "kei_protocol_container",
    "kei_protocol_binder",
    "reticuleaoe",
    "reticuleaoeping",
    "reticuleline",
    "reticulelineping",
    "kei_mutatedwarg_flamethrower",
    "kei_celestial_orb_fx",
    "warg_mutated_breath_fx",
    "warg_mutated_ember_fx",
    "daywalker_sinkhole",
    "bigshadowtentacle",
    "shadow_pillar",
    "shadow_pillar_target",
    "waxwell_shadowstriker",
    "shadowstrike_slash_fx",
    "shadowstrike_slash2_fx",
    "statue_transition_2",
    "wortox_soul",
    "wortox_soul_heal_fx",
    "sleepbomb",
    "sleepbomb_burst",
    "sleepcloud",
    "sandspike_tall",
    "sandspike_short",
    "battlesong_instant_panic_fx",
    "collapse_small",
    "wx78_big_spark",
}

-- 初始物品先给一组电池，保证角色刚进世界时可以测试电量循环。
local start_inv = {
    "kei_battery",
    "kei_battery",
    "kei_battery",
    "kei_battery",
    "kei_battery",
}

local function SetReticulePrefab(reticule, prefab)
    if reticule == nil then
        return
    end
    if reticule.reticuleprefab ~= prefab and reticule.reticule ~= nil then
        reticule:DestroyReticule()
    end
    reticule.reticuleprefab = prefab
end

local function ConfigureEyeOfTerrorReticule(inst)
    local reticule = inst.components.reticule
    if reticule == nil then
        return
    end
    SetReticulePrefab(reticule, "reticuleline")
    reticule.pingprefab = nil
    reticule.targetfn = EyeOfTerrorDash.ReticuleTargetFn
    reticule.mousetargetfn = EyeOfTerrorDash.ReticuleMouseTargetFn
    reticule.updatepositionfn = EyeOfTerrorDash.ReticuleUpdatePositionFn
    reticule.validcolour = { 1, 0.2, 0.2, 0 }
    reticule.invalidcolour = { 0.5, 0, 0, 0 }
    reticule.twinstickrange = TUNING.KEI_EYEOFTERROR_DASH_DISTANCE or 12
end

local function ConfigureDaywalkerReticule(inst)
    local reticule = inst.components.reticule
    if reticule == nil then
        return
    end
    SetReticulePrefab(reticule, "reticuleaoe")
    reticule.pingprefab = "reticuleaoeping"
    reticule.targetfn = DaywalkerLeap.ReticuleTargetFn
    reticule.mousetargetfn = DaywalkerLeap.ReticuleMouseTargetFn
    reticule.updatepositionfn = nil
    reticule.validcolour = { 1, 0.75, 0, 1 }
    reticule.invalidcolour = { 0.5, 0, 0, 1 }
    reticule.twinstickrange = TUNING.KEI_DAYWALKER_LEAP_DISTANCE or 7
end

local function UpdateDaywalkerAimingReticule(inst)
    if inst.components.reticule == nil then
        return
    end
    if ThePlayer == inst
        and inst._kei_daywalker_aiming ~= nil
        and inst._kei_daywalker_aiming:value()
        and DaywalkerLeap.IsReady(inst)
    then
        ConfigureDaywalkerReticule(inst)
        inst.components.reticule:CreateReticule()
    else
        inst.components.reticule:DestroyReticule()
    end
end

local function SetMalbatrossCollision(inst, enabled)
    if enabled and not TheWorld:HasTag("cave") and not inst:HasTag("playerghost") then
        inst.Physics:SetCollisionMask(
            COLLISION.GROUND,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
    elseif not inst:HasTag("playerghost") then
        inst.Physics:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
    end
end

local function OnMalbatrossProtocolDirty(inst)
    SetMalbatrossCollision(
        inst,
        inst._kei_malbatross_protocol_active ~= nil and inst._kei_malbatross_protocol_active:value()
    )
end

local function GetPointSpecialActions(inst, pos, useitem, right, usereticulepos)
    if ACTIONS.KEI_DAYWALKER_LEAP ~= nil
        and DaywalkerLeap.HasProtocol(inst)
        and DaywalkerLeap.IsAiming(inst)
        and DaywalkerLeap.IsReady(inst)
        and not inst:HasTag("playerghost")
    then
        ConfigureDaywalkerReticule(inst)
        local targetpos = usereticulepos and DaywalkerLeap.ReticuleTargetFn(inst) or DaywalkerLeap.GetTargetPoint(inst, pos)
        if targetpos ~= nil then
            return { right and ACTIONS.KEI_DAYWALKER_CANCEL_AIM or ACTIONS.KEI_DAYWALKER_LEAP }, targetpos
        end
        return right and { ACTIONS.KEI_DAYWALKER_CANCEL_AIM } or {}
    end

    if right
        and useitem == nil
        and ACTIONS.KEI_DAYWALKER_AIM ~= nil
        and DaywalkerLeap.HasProtocol(inst)
        and DaywalkerLeap.IsReady(inst)
        and not inst:HasTag("playerghost")
    then
        ConfigureDaywalkerReticule(inst)
        local targetpos = usereticulepos and DaywalkerLeap.ReticuleTargetFn(inst) or DaywalkerLeap.GetTargetPoint(inst, pos)
        if targetpos ~= nil then
            return { ACTIONS.KEI_DAYWALKER_AIM }, targetpos
        end
    end

    if right
        and useitem == nil
        and ACTIONS.KEI_EYEOFTERROR_DASH ~= nil
        and EyeOfTerrorDash.HasProtocol(inst)
        and not inst:HasTag("playerghost")
    then
        ConfigureEyeOfTerrorReticule(inst)
        local targetpos = usereticulepos and EyeOfTerrorDash.ReticuleTargetFn(inst) or EyeOfTerrorDash.GetTargetPoint(inst, pos)
        if targetpos ~= nil then
            return { ACTIONS.KEI_EYEOFTERROR_DASH }, targetpos
        end
    end
    return {}
end

local function DaywalkerAimLeftClickPicker(inst, target, position)
    if ACTIONS.KEI_DAYWALKER_LEAP ~= nil
        and DaywalkerLeap.HasProtocol(inst)
        and DaywalkerLeap.IsAiming(inst)
        and DaywalkerLeap.IsReady(inst)
        and position ~= nil
        and not inst:HasTag("playerghost")
    then
        local targetpos = DaywalkerLeap.GetTargetPoint(inst, position)
        return targetpos ~= nil and inst.components.playeractionpicker:SortActionList({ ACTIONS.KEI_DAYWALKER_LEAP }, targetpos) or {}
    end
    if inst._kei_old_leftclickoverride ~= nil then
        return inst._kei_old_leftclickoverride(inst, target, position)
    end
    return nil, true
end

local function GetRightClickDashPoint(inst, target, position)
    if ACTIONS.KEI_EYEOFTERROR_DASH == nil
        or not EyeOfTerrorDash.HasProtocol(inst)
        or inst:HasTag("playerghost")
        or target == nil
        or target == inst
        or (inst.replica.inventory ~= nil and inst.replica.inventory:GetActiveItem() ~= nil)
    then
        return nil
    end

    local rawpos = position
    if rawpos == nil and target ~= nil and target:IsValid() then
        rawpos = target:GetPosition()
    end
    if rawpos == nil then
        return nil
    end

    ConfigureEyeOfTerrorReticule(inst)
    return EyeOfTerrorDash.GetTargetPoint(inst, rawpos)
end

local function DaywalkerAimRightClickPicker(inst, target, position)
    if ACTIONS.KEI_DAYWALKER_CANCEL_AIM ~= nil
        and DaywalkerLeap.IsAiming(inst)
        and DaywalkerLeap.IsReady(inst)
        and not inst:HasTag("playerghost")
    then
        return inst.components.playeractionpicker:SortActionList({ ACTIONS.KEI_DAYWALKER_CANCEL_AIM }, position or inst:GetPosition())
    end
    local dashpos = GetRightClickDashPoint(inst, target, position)
    if dashpos ~= nil then
        return inst.components.playeractionpicker:SortActionList({ ACTIONS.KEI_EYEOFTERROR_DASH }, dashpos)
    end
    if inst._kei_old_rightclickoverride ~= nil then
        return inst._kei_old_rightclickoverride(inst, target, position)
    end
    return nil, true
end

local function OnSetOwner(inst)
    if inst.components.playeractionpicker ~= nil then
        if not inst._kei_daywalker_picker_wrapped then
            inst._kei_old_leftclickoverride = inst.components.playeractionpicker.leftclickoverride
            inst._kei_old_rightclickoverride = inst.components.playeractionpicker.rightclickoverride
            inst.components.playeractionpicker.leftclickoverride = DaywalkerAimLeftClickPicker
            inst.components.playeractionpicker.rightclickoverride = DaywalkerAimRightClickPicker
            inst._kei_daywalker_picker_wrapped = true
        end
        inst.components.playeractionpicker.pointspecialactionsfn = GetPointSpecialActions
    end
end

local function ConfigureVisuals(inst)
    -- 使用 Kei 自己的角色 build；角色 id、文件名和资源 build 统一为小写 kei。
    inst.AnimState:SetBuild("kei")
    inst.MiniMapEntity:SetIcon("kei.tex")
end

local function PatchKeiChannelCastingFns(inst)
    if inst._kei_old_IsChannelCasting ~= nil then
        return
    end

    inst._kei_old_IsChannelCasting = inst.IsChannelCasting
    inst._kei_old_IsChannelCastingItem = inst.IsChannelCastingItem

    inst.IsChannelCasting = function(player, ...)
        return player.kei_mutatedwarg_channelcasting == true
            or (player._kei_old_IsChannelCasting ~= nil and player:_kei_old_IsChannelCasting(...))
            or false
    end

    inst.IsChannelCastingItem = function(player, ...)
        return player.kei_mutatedwarg_channelcasting == true
            or (player._kei_old_IsChannelCastingItem ~= nil and player:_kei_old_IsChannelCastingItem(...))
            or false
    end
end

local UpdateDormantActionFilter

local function common_postinit(inst)
    -- 标签用于动作过滤、专属配方解锁，以及电击免疫等基础设定。
    inst:AddTag("kei")
    inst:AddTag("electricdamageimmune")
    inst:AddTag("batteryuser")
    inst:AddTag(FOODTYPE.KEI_DEVICE .. "_eater")

    inst._kei_unlocked_protocol_slots = net_smallbyte(inst.GUID, "kei.unlocked_protocol_slots", "kei_protocol_slots_dirty")
    inst._kei_eyeofterror_protocol_active = net_bool(inst.GUID, "kei.eyeofterror_protocol_active", "kei_eyeofterror_protocol_dirty")
    inst._kei_daywalker_protocol_active = net_bool(inst.GUID, "kei.daywalker_protocol_active", "kei_daywalker_protocol_dirty")
    inst._kei_malbatross_protocol_active = net_bool(inst.GUID, "kei.malbatross_protocol_active", "kei_malbatross_protocol_dirty")
    inst._kei_mutatedwarg_protocol_active = net_bool(inst.GUID, "kei.mutatedwarg_protocol_active", "kei_mutatedwarg_protocol_dirty")
    inst._kei_daywalker_aiming = net_bool(inst.GUID, "kei.daywalker_aiming", "kei_daywalker_aiming_dirty")
    inst._kei_daywalker_leap_on_cooldown = net_bool(inst.GUID, "kei.daywalker_leap_on_cooldown", "kei_daywalker_leap_cd_dirty")

    inst:AddComponent("reticule")
    inst.components.reticule.ease = true
    inst.components.reticule.mouseenabled = true
    inst.components.reticule.twinstickcheckscheme = true
    inst.components.reticule.twinstickmode = 1
    ConfigureEyeOfTerrorReticule(inst)

    inst:ListenForEvent("setowner", OnSetOwner)
    inst:ListenForEvent("kei_daywalker_aiming_dirty", UpdateDaywalkerAimingReticule)
    inst:ListenForEvent("kei_daywalker_leap_cd_dirty", UpdateDaywalkerAimingReticule)
    inst:ListenForEvent("kei_malbatross_protocol_dirty", OnMalbatrossProtocolDirty)
    inst:DoTaskInTime(0, OnMalbatrossProtocolDirty)
    inst:DoPeriodicTask(0.25, UpdateDormantActionFilter)

    PatchKeiChannelCastingFns(inst)
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

local function HasAlterguardianPowerOverride(inst)
    return inst.components.kei_protocolslots ~= nil
        and inst.components.kei_protocolslots:AlterguardianProtocolOverridesPower()
end

local function KeiDormantActionFilter(inst, action)
    return action == ACTIONS.KEI_WAKE
end

function UpdateDormantActionFilter(inst)
    local playeractionpicker = inst.components.playeractionpicker
    if playeractionpicker == nil then
        return
    end

    if inst:HasTag("kei_dormant") then
        if not inst.kei_dormant_action_filter_active then
            playeractionpicker:PushActionFilter(KeiDormantActionFilter, 999)
            inst.kei_dormant_action_filter_active = true
        end
    elseif inst.kei_dormant_action_filter_active then
        playeractionpicker:PopActionFilter(KeiDormantActionFilter)
        inst.kei_dormant_action_filter_active = nil
    end
end

local function SpawnDormantTransitionFx(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local collapse = SpawnPrefab("collapse_small")
    if collapse ~= nil then
        collapse.Transform:SetPosition(x, y, z)
        if collapse.SetMaterial ~= nil then
            collapse:SetMaterial("metal")
        end
    end

    local spark = SpawnPrefab("wx78_big_spark")
    if spark ~= nil then
        if spark.AlignToTarget ~= nil then
            spark:AlignToTarget(inst)
        else
            spark.Transform:SetPosition(x, y, z)
        end
    end
    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound("WX_rework/chassis/chassis_clunk")
    end
end

local function RestoreKeiDormantColour(inst)
    if inst.kei_dormant_old_multcolour ~= nil then
        inst.AnimState:SetMultColour(unpack(inst.kei_dormant_old_multcolour))
        inst.kei_dormant_old_multcolour = nil
    else
        inst.AnimState:SetMultColour(1, 1, 1, 1)
    end
end

local function RemoveDormantVisual(inst)
    if inst.kei_dormant_visual ~= nil then
        if inst.kei_dormant_visual:IsValid() then
            inst.kei_dormant_visual:Remove()
        end
        inst.kei_dormant_visual = nil
    end
end

local DORMANT_FACE_SYMBOLS = { "face", "swap_face", "cheeks" }

local function HideDormantFaceSymbols(visual)
    for _, symbol in ipairs(DORMANT_FACE_SYMBOLS) do
        visual.AnimState:HideSymbol(symbol)
    end
end

local function SetDormantChassisPose(visual)
    visual.AnimState:AddOverrideBuild("wx_chassis")
    visual.AnimState:PlayAnimation("wx_chassis_poweroff")
    visual.AnimState:SetPercent("wx_chassis_poweroff", 1)
    visual.AnimState:Pause()
    HideDormantFaceSymbols(visual)
end

local function CopyDormantVisualAppearance(owner, visual)
    if visual.components.skinner ~= nil and owner.components.skinner ~= nil then
        visual.components.skinner:CopySkinsFromPlayer(owner, true)
        SetDormantChassisPose(visual)
    end
end

local function SpawnDormantVisual(inst)
    RemoveDormantVisual(inst)

    local visual = SpawnPrefab("kei_dormant_chassis")
    if visual == nil then
        return
    end

    visual.entity:SetParent(inst.entity)
    visual.Transform:SetPosition(0, 0, 0)
    visual.Transform:SetRotation(0)
    visual.Transform:SetScale(1, 1, 1)
    CopyDormantVisualAppearance(inst, visual)
    inst.kei_dormant_visual = visual
end

local function ClearDormantAttackers(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 40, { "_combat" }, { "INLIMBO" })
    for _, ent in ipairs(ents) do
        if ent ~= inst and ent.components.combat ~= nil and ent.components.combat.target == inst then
            ent.components.combat:SetTarget(nil)
        end
    end
end

local function DoDormantTick(inst)
    if not inst.kei_dormant_active
        or inst.components.health == nil
        or inst.components.health:IsDead()
        or inst.components.hunger == nil
    then
        if inst.StopKeiDormant ~= nil then
            inst:StopKeiDormant()
        end
        return
    end

    if inst.components.hunger.current <= 0 then
        inst:StopKeiDormant()
        return
    end

    ClearDormantAttackers(inst)
    inst.components.hunger:DoDelta(-(TUNING.KEI_DORMANT_POWER_DRAIN or 1))
    if inst.components.sanity ~= nil then
        inst.components.sanity:DoDelta(TUNING.KEI_DORMANT_STABILITY_REGEN or 3)
    end
    inst.components.health:DoDelta(TUNING.KEI_DORMANT_INTEGRITY_REGEN or 3, true, "kei_dormant", true)
end

local function StopDormantTask(inst)
    if inst.kei_dormant_task ~= nil then
        inst.kei_dormant_task:Cancel()
        inst.kei_dormant_task = nil
    end
end

local function StartKeiDormant(inst, playfx)
    if inst.kei_dormant_active
        or inst:HasTag("playerghost")
        or inst.components.health == nil
        or inst.components.health:IsDead()
    then
        return false
    end

    if inst.components.hunger == nil or inst.components.hunger.current <= 0 then
        return false
    end

    inst.kei_dormant_active = true
    inst:AddTag("kei_dormant")
    inst:AddTag("notarget")
    inst:AddTag("noattack")
    inst:AddTag("NOBLOCK")

    if inst.components.health ~= nil then
        inst.kei_dormant_old_invincible = inst.components.health.invincible
        inst.components.health:SetInvincible(true)
    end
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:Stop()
        inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kei_dormant", 0)
    end
    if inst.components.combat ~= nil then
        inst.components.combat:SetTarget(nil)
    end
    if inst.components.inventory ~= nil then
        inst.components.inventory:Hide()
        inst.components.inventory:CloseAllChestContainers()
    end
    inst.kei_daywalker_aiming = nil
    if inst._kei_daywalker_aiming ~= nil then
        inst._kei_daywalker_aiming:set(false)
    end
    ClearDormantAttackers(inst)

    inst.kei_dormant_old_multcolour = { inst.AnimState:GetMultColour() }
    inst.AnimState:SetMultColour(
        inst.kei_dormant_old_multcolour[1] or 1,
        inst.kei_dormant_old_multcolour[2] or 1,
        inst.kei_dormant_old_multcolour[3] or 1,
        0
    )
    SpawnDormantVisual(inst)
    if playfx ~= false then
        SpawnDormantTransitionFx(inst)
    end
    StopDormantTask(inst)
    inst.kei_dormant_task = inst:DoPeriodicTask(1, DoDormantTick, 1)
    UpdateDormantActionFilter(inst)

    return true
end

local function StopKeiDormant(inst, playfx)
    if not inst.kei_dormant_active then
        return false
    end

    StopDormantTask(inst)
    inst.kei_dormant_active = nil
    inst:RemoveTag("kei_dormant")
    inst:RemoveTag("notarget")
    inst:RemoveTag("noattack")
    inst:RemoveTag("NOBLOCK")

    if inst.components.health ~= nil then
        inst.components.health:SetInvincible(inst.kei_dormant_old_invincible == true)
    end
    inst.kei_dormant_old_invincible = nil
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "kei_dormant")
    end
    if inst.components.inventory ~= nil then
        inst.components.inventory:Show()
    end
    inst:ShowActions(true)
    if inst.components.playercontroller ~= nil then
        inst.components.playercontroller:EnableMapControls(true)
        inst.components.playercontroller:Enable(true)
    end

    RestoreKeiDormantColour(inst)
    RemoveDormantVisual(inst)
    if playfx ~= false then
        SpawnDormantTransitionFx(inst)
    end
    UpdateDormantActionFilter(inst)

    return true
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
    if inst.kei_dormant_active then
        return
    end

    local current_power = hunger.current or 0
    local current_integrity = health.currenthealth or health.maxhealth or 0
    local max_integrity = health.maxhealth or TUNING.KEI_MAX_INTEGRITY

    if current_power <= 0 and not HasAlterguardianPowerOverride(inst) then
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

    inst.StartKeiDormant = StartKeiDormant
    inst.StopKeiDormant = StopKeiDormant

    inst:DoPeriodicTask(TUNING.KEI_SELF_REPAIR_PERIOD, UpdateIntegrityState)
    inst:ListenForEvent("death", StopKeiDormant)
    inst:ListenForEvent("onremove", StopKeiDormant)

    -- MakePlayerCharacter 会调用角色实例上的 OnSave / OnLoad 字段。
    inst._OnSave = OnSave
    inst._OnLoad = OnLoad
end

local function dormant_chassis_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddDynamicShadow()
    inst.entity:AddNetwork()

    inst:AddTag("equipmentmodel")
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    PlayerCommonExtensions.SetupBaseSymbolVisibility(inst)
    inst.AnimState:SetBank("wilson")
    inst.AnimState:SetBuild("wx78")
    SetDormantChassisPose(inst)
    inst.DynamicShadow:SetSize(1.3, 0.6)

    inst.AnimState:Hide("shad_veins")
    inst.AnimState:Hide("mimic1")
    inst.AnimState:Hide("mimic2")
    inst.AnimState:Hide("mimic3")
    inst.AnimState:Hide("trapper")
    inst.AnimState:Hide("gestalt_die")
    inst.AnimState:Hide("gestalt_flee")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    local skinner = inst:AddComponent("skinner")
    skinner:SetupNonPlayerData()
    skinner.useskintypeonload = true

    return inst
end

return MakePlayerCharacter("kei", prefabs, assets, common_postinit, master_postinit),
    Prefab("kei_dormant_chassis", dormant_chassis_fn, assets)
