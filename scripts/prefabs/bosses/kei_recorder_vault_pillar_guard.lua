local RecorderVaultPillarGuard = require("kei/recorder/bosses/recorder_vault_pillar_guard")

local assets = {
    Asset("ANIM", "anim/vault_pillar_guard.zip"),
    Asset("ANIM", "anim/vault_pillar_guard_actions.zip"),
    Asset("ANIM", "anim/vault_pillar_guard_actions2.zip"),
    Asset("ANIM", "anim/vault_pillar_guard_basic.zip"),
    Asset("SOUND", "sound/rifts7.fsb"),
}

local prefabs = {
    "vault_pillar_guard_swipe_fx",
    "vault_pillar_guard_smash_fx",
    "thulecite",
    "thulecite_pieces",
    "rocks",
    "moonrocknugget",
    "temp_beta_msg",
    "vault_pillar_guard_piece_1",
    "vault_pillar_guard_piece_2",
    "vault_pillar_guard_piece_3",
    "chesspiece_vault_pillar_guard_sketch",
}

local function fn(sim)
    local original = Prefabs["vault_pillar_guard"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_vault_pillar_guard")
    inst:SetPrefabNameOverride("vault_pillar_guard")
    inst:AddTag("kei_recorder_vault_pillar_guard")
    inst.persists = false

    if TheWorld.ismastersim then
        RecorderVaultPillarGuard.Initialize(inst)
    end

    return inst
end

return Prefab("kei_recorder_vault_pillar_guard", fn, assets, prefabs)
