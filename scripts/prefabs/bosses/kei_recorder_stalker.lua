local assets = {
    Asset("ANIM", "anim/stalker_basic.zip"),
    Asset("ANIM", "anim/stalker_action.zip"),
    Asset("ANIM", "anim/stalker_atrium.zip"),
    Asset("ANIM", "anim/stalker_shadow_build.zip"),
    Asset("ANIM", "anim/stalker_atrium_build.zip"),
}

local prefabs = {
    "stalker_atrium",
    "shadow_despawn",
    "shadow_teleport_in",
    "crawlinghorror",
    "terrorbeak",
    "ruinsnightmare",
}

local function fn(sim)
    local original = Prefabs["stalker_atrium"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_stalker")
    inst:SetPrefabNameOverride("stalker_atrium")
    inst:AddTag("kei_recorder_stalker")
    inst.persists = false

    if TheWorld.ismastersim then
        inst:SetStateGraph("SGkei_recorder_stalker")
    end

    return inst
end

return Prefab("kei_recorder_stalker", fn, assets, prefabs)
