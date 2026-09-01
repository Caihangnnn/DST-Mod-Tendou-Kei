local brain = require("brains/recorder/kei_recorder_beebrain")
local beecommon = require("brains/beecommon")

local assets = {
    Asset("ANIM", "anim/bee.zip"),
    Asset("ANIM", "anim/bee_build.zip"),
    Asset("ANIM", "anim/bee_angry_build.zip"),
    Asset("SOUND", "sound/bee.fsb"),
}

local prefabs = {
    "beecorpse",
}

local function OnEaten(inst, eater)
    if eater == nil or not eater:IsValid()
        or eater.components.health == nil
        or eater.components.health:IsDead()
    then
        return
    end

    local bee_health = inst.components.health ~= nil
        and inst.components.health.currenthealth
        or 0
    local multiplier = TUNING.KEI_RECORDER_BEARGER_BEE_HEAL_MULTIPLIER or 10
    if bee_health > 0 then
        eater.components.health:DoDelta(bee_health * multiplier, nil, inst.prefab)
    end
end

local function fn(sim)
    local original = Prefabs["bee"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_bee")
    inst:SetPrefabNameOverride("bee")
    inst:AddTag("kei_recorder_bee")
    inst:AddTag("prey")
    inst.persists = false

    if not TheWorld.ismastersim then
        return inst
    end

    inst:SetStateGraph("SGbee")
    inst:SetBrain(brain)
    -- Recorder bees actively attack their Bearger target, but their damage
    -- remains zero so the attack is only a visual/behavioural interaction.
    inst.components.combat.canattack = true
    inst.components.combat:SetDefaultDamage(0)
    inst.components.combat:SetRetargetFunction(nil)
    -- Do not let the base bee's defensive handlers replace its fixed
    -- Bearger target or make it share an attack target with other bees.
    inst:RemoveEventCallback("attacked", beecommon.OnAttacked)
    inst:RemoveEventCallback("worked", beecommon.OnWorked)

    if inst.components.lootdropper ~= nil then
        inst.components.lootdropper:SetLoot({})
        inst.components.lootdropper:ClearChanceLoot()
        inst.components.lootdropper:ClearRandomLoot()
        inst.components.lootdropper:SetChanceLootTable(nil)
        inst.components.lootdropper.droprecipeloot = false
    end

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.MEAT
    inst.components.edible.healthvalue = 0
    inst.components.edible.hungervalue = 0
    inst.components.edible.sanityvalue = 0
    inst.components.edible.degrades_with_spoilage = false
    inst.components.edible:SetOnEatenFn(OnEaten)
    inst.components.health:SetMaxHealth(TUNING.KEI_RECORDER_BEARGER_BEE_HEALTH or 100)

    function inst:SetRecorderBearger(bearger)
        self.kei_recorder_bearger = bearger
        if self.components.combat ~= nil and bearger ~= nil and bearger:IsValid() then
            self.components.combat:SetTarget(bearger)
        end
    end

    return inst
end

return Prefab("kei_recorder_bee", fn, assets, prefabs)
