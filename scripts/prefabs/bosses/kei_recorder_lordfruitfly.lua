local brain = require("brains/recorder/kei_recorder_lordfruitflybrain")

local assets = {
    Asset("ANIM", "anim/fruitfly.zip"),
    Asset("ANIM", "anim/fruitfly_evil.zip"),
    Asset("ANIM", "anim/fruitfly_evil_minion.zip"),
    Asset("ANIM", "anim/fruitflyfruit.zip"),
    Asset("SOUND", "sound/farming.fsb"),
}

local prefabs = {
    "lordfruitfly",
    "fruitfly",
    "fruitflyfruit",
    "killerbee",
    "weed_forgetmelots",
    "weed_tillweed",
    "weed_firenettle",
    "weed_ivy",
    "ivy_snare",
}

local function fn(sim)
    local original = Prefabs["lordfruitfly"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst ~= nil then
        inst:SetPrefabName("kei_recorder_lordfruitfly")
        inst:SetPrefabNameOverride("lordfruitfly")
        inst:AddTag("kei_recorder_lordfruitfly")
        inst.persists = false

        if TheWorld.ismastersim then
            inst.components.health:SetMaxHealth(6000)
            inst.components.combat:SetDefaultDamage(0)
            inst.components.combat:SetAttackPeriod(999999)
            inst:SetStateGraph("SGkei_recorder_lordfruitfly")
            inst:SetBrain(brain)
        end
    end
    return inst
end

return Prefab("kei_recorder_lordfruitfly", fn, assets, prefabs)
