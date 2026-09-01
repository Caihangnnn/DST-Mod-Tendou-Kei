    local brain = require("brains/recorder/kei_recorder_beargerbrain")

local assets = {
    Asset("ANIM", "anim/bearger_build.zip"),
    Asset("ANIM", "anim/bearger_basic.zip"),
    Asset("ANIM", "anim/bearger_actions.zip"),
    Asset("ANIM", "anim/bearger_yule.zip"),
    Asset("SOUND", "sound/bearger.fsb"),
}

local prefabs = {
    "bearger",
    "bearger_swipe_fx",
    "groundpound_fx",
    "groundpoundring_fx",
    "bearger_fur",
    "furtuft",
    "meat",
    "chesspiece_bearger_sketch",
    "collapse_small",
    "beargercorpse",
    "kei_recorder_bee",
}

local function fn(sim)
    local original = Prefabs["bearger"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_bearger")
    inst:SetPrefabNameOverride("bearger")
    inst:AddTag("kei_recorder_bearger")
    inst.persists = false

    if TheWorld.ismastersim then
        inst:SetBrain(brain)
    end

    return inst
end

return Prefab("kei_recorder_bearger", fn, assets, prefabs)
