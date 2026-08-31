local brain = require("brains/kei_recorder_minotaurbrain")

local assets = {
    Asset("ANIM", "anim/rook.zip"),
    Asset("ANIM", "anim/rook_rhino.zip"),
    Asset("ANIM", "anim/rook_rhino_damaged_build.zip"),
    Asset("ANIM", "anim/rook_attacks.zip"),
    Asset("SOUND", "sound/chess.fsb"),
}

local prefabs = {
    "minotaur",
    "meat",
    "minotaurhorn",
    "minotaurchestspawner",
    "atrium_key",
    "collapse_small",
    "minotaur_ruinsrespawner_inst",
    "chesspiece_minotaur_sketch",
    "winter_ornament_boss_minotaur",
    "bigshadowtentacle",
    "shadowhand_fx",
    "ruins_cavein_obstacle",
    "minotaur_blood1",
    "minotaur_blood2",
    "minotaur_blood3",
    "minotaur_blood_big",
    "support_pillar_scaffold_blueprint",
    "minotaurchest",
    "minotaurcorpse",
}

local function fn(sim)
    local original = Prefabs["minotaur"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_minotaur")
    inst:SetPrefabNameOverride("minotaur")
    inst:AddTag("kei_recorder_minotaur")
    inst.persists = false

    if TheWorld.ismastersim then
        inst:SetStateGraph("SGkei_recorder_minotaur")
        inst:SetBrain(brain)
    end

    return inst
end

return Prefab("kei_recorder_minotaur", fn, assets, prefabs)
