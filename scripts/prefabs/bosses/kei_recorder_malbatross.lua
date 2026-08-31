local assets = {
    Asset("ANIM", "anim/malbatross_basic.zip"),
    Asset("ANIM", "anim/malbatross_actions.zip"),
    Asset("ANIM", "anim/malbatross_build.zip"),
}

local prefabs = {
    "malbatross",
    "kei_recorder_malbatross_wave",
    "wave_splash",
}

local function fn(sim)
    local original = Prefabs["malbatross"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_malbatross")
    inst:SetPrefabNameOverride("malbatross")
    inst:AddTag("kei_recorder_malbatross")
    inst.persists = false
    return inst
end

return Prefab("kei_recorder_malbatross", fn, assets, prefabs)
