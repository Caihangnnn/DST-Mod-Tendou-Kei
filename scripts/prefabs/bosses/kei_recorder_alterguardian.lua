local assets = {
    Asset("ANIM", "anim/alterguardian_phase3.zip"),
    Asset("ANIM", "anim/alterguardian_spawn_death.zip"),
}

local prefabs = {
    "alterguardian_laser",
    "alterguardian_laserempty",
    "alterguardian_phase3circle",
    "alterguardian_phase3deadorb",
    "alterguardian_phase3trapprojectile",
    "alterguardian_summon_fx",
    "archive_lockbox_player_fx",
    "chesspiece_guardianphase3_sketch",
    "largeguard_alterguardian_projectile",
    "moonglass",
    "moonglass_charged",
    "moonrocknugget",
}

local function fn(sim)
    local original = Prefabs["alterguardian_phase3"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_alterguardian")
    inst:SetPrefabNameOverride("alterguardian_phase3")
    inst:AddTag("kei_recorder_alterguardian")
    inst.persists = false

    if TheWorld.ismastersim then
        inst:SetStateGraph("SGkei_recorder_alterguardian_phase3")
    end

    return inst
end

return Prefab("kei_recorder_alterguardian", fn, assets, prefabs)
