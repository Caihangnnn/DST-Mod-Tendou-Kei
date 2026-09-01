local RecorderBoss = require("kei/recorder/boss")
local brain = require("brains/recorder/kei_recorder_pigelitefighterbrain")

local assets = {
    Asset("ANIM", "anim/ds_pig_basic.zip"),
    Asset("ANIM", "anim/ds_pig_actions.zip"),
    Asset("ANIM", "anim/ds_pig_attacks.zip"),
    Asset("ANIM", "anim/ds_pig_elite.zip"),
    Asset("ANIM", "anim/ds_pig_elite_intro.zip"),
    Asset("ANIM", "anim/pig_elite_build.zip"),
    Asset("ANIM", "anim/pig_guard_build.zip"),
    Asset("ANIM", "anim/ds_pig_attacks_combo.zip"),
    Asset("ANIM", "anim/slide_puff.zip"),
    Asset("SOUND", "sound/pig.fsb"),
}

local prefabs = {
    "slide_puff",
    "propsign",
    "propsignshatterfx",
}

local VARIATIONS = { "1", "2", "3", "4" }
local DAMAGE_REDUCTION_KEY = "kei_recorder_pigelitefighter_damage_reduction"
local REARM_RANGE = 5
local REARM_CHECK_PERIOD = .25

local function RegisterSupport(owner, entity)
    if owner == nil or entity == nil then
        return
    end
    owner.kei_target_support_entities = owner.kei_target_support_entities or {}
    table.insert(owner.kei_target_support_entities, entity)
end

local function HasSign(inst)
    return inst.kei_recorder_propsign ~= nil
        and inst.kei_recorder_propsign:IsValid()
        and inst.components.inventory ~= nil
        and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == inst.kei_recorder_propsign
end

local function FindArenaTarget(inst)
    if not HasSign(inst) then
        return nil
    end

    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        return nil
    end

    local target = nil
    local target_dist_sq = math.huge
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        local dist_sq = inst:GetDistanceSqToInst(player)
        if dist_sq < target_dist_sq then
            target = player
            target_dist_sq = dist_sq
        end
    end
    return target
end

local function KeepArenaTarget(inst, target)
    if target == nil or not target:IsValid() or target:HasTag("playerghost")
        or target.components.health == nil or target.components.health:IsDead()
    then
        return false
    end

    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        return false
    end

    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        if player == target then
            return true
        end
    end
    return false
end

local function RemoveCarriedSign(inst)
    inst.kei_recorder_removing = true
    local sign = inst.kei_recorder_propsign
    if sign ~= nil and sign:IsValid() then
        sign:Remove()
    end
    inst.kei_recorder_propsign = nil
end

local function TryRearm(inst)
    if not TheWorld.ismastersim
        or not inst:IsValid()
        or HasSign(inst)
        or inst.kei_recorder_rearming
    then
        return
    end

    local junk = inst.kei_recorder_junk
    if junk == nil or not junk:IsValid()
        or inst.sg == nil or inst.sg:HasStateTag("busy")
        or inst:GetDistanceSqToInst(junk) > REARM_RANGE * REARM_RANGE
    then
        return
    end

    inst.kei_recorder_rearming = true
    local sign = inst:EquipRecorderSign(junk)
    inst.kei_recorder_rearming = nil
    if sign ~= nil then
        inst.components.combat:DropTarget()
    end
end

local function GiveSign(inst, source)
    if not TheWorld.ismastersim or inst.components.inventory == nil then
        return nil
    end

    local sign = SpawnPrefab("propsign")
    if sign == nil then
        return nil
    end

    if source ~= nil and source:IsValid() then
        sign.Transform:SetPosition(source.Transform:GetWorldPosition())
    else
        sign.Transform:SetPosition(inst.Transform:GetWorldPosition())
    end
    sign.kei_recorder_owner = inst
    sign:ListenForEvent("onremove", function(removed_sign)
        if inst:IsValid() and not inst.kei_recorder_removing
            and inst.kei_recorder_propsign == removed_sign
        then
            inst.kei_recorder_propsign = nil
            inst:PushEvent("kei_recorder_sign_lost")
        end
    end)

    inst.components.inventory:Equip(sign)
    if sign.components.inventoryitem == nil
        or sign.components.inventoryitem.owner ~= inst
    then
        sign:Remove()
        return nil
    end

    inst.kei_recorder_propsign = sign
    inst.kei_recorder_removing = nil
    return sign
end

local function fn(sim, variation)
    local original = Prefabs["pigelitefighter" .. variation]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    local prefab_name = "kei_recorder_pigelitefighter" .. variation
    inst:SetPrefabName(prefab_name)
    inst:SetPrefabNameOverride("pigelitefighter" .. variation)
    inst:AddTag("kei_recorder_pigelitefighter")
    inst.persists = false

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inventory")
    inst.EquipRecorderSign = function(_, source)
        local sign = GiveSign(inst, source)
        if sign ~= nil then
            RegisterSupport(inst.kei_recorder_support_owner, sign)
        end
        return sign
    end

    -- Keep the recorder-only fighter on the field until its recorder is
    -- stopped; vanilla fighters remove themselves on a full moon.
    if inst.StopAllWatchingWorldStates ~= nil then
        inst:StopAllWatchingWorldStates()
    end
    if inst.components.timer ~= nil then
        inst.components.timer:StopTimer("despawn_timer")
    end
    inst:SetBrain(brain)
    inst:SetStateGraph("SGkei_recorder_pigelitefighter")
    -- Replacing the stategraph creates a fresh mem table, so restore the
    -- variation used by SGpigelitefighter's spawnin pose selection.
    inst.sg.mem.variation = variation

    inst.components.health.externalabsorbmodifiers:SetModifier(
        inst,
        1,
        DAMAGE_REDUCTION_KEY
    )

    inst.kei_recorder_source = nil
    inst.kei_recorder_junk = nil
    inst.kei_recorder_support_owner = nil
    inst.kei_recorder_rearm_task = inst:DoPeriodicTask(REARM_CHECK_PERIOD, TryRearm)
    inst.components.combat:SetRetargetFunction(1, FindArenaTarget)
    inst.components.combat:SetKeepTargetFunction(KeepArenaTarget)
    inst.components.combat:SetDefaultDamage(0)
    inst:ListenForEvent("kei_recorder_sign_lost", function(fighter)
        if fighter.components.combat ~= nil then
            fighter.components.combat:DropTarget()
        end
        if fighter.sg ~= nil and not fighter.sg:HasStateTag("busy") then
            fighter.sg:GoToState("idle")
        end
    end)
    inst:ListenForEvent("onremove", function(fighter)
        if fighter.kei_recorder_rearm_task ~= nil then
            fighter.kei_recorder_rearm_task:Cancel()
            fighter.kei_recorder_rearm_task = nil
        end
        RemoveCarriedSign(fighter)
    end)

    -- SGpigelitefighter already contains the YOTP wrestling entrance.
    return inst
end

local prefabs_out = {}
for _, variation in ipairs(VARIATIONS) do
    table.insert(prefabs_out, Prefab("kei_recorder_pigelitefighter" .. variation, function(sim)
        return fn(sim, variation)
    end, assets, prefabs))
end

return unpack(prefabs_out)
