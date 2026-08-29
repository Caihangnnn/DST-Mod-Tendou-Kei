local assets = {
    Asset("ANIM", "anim/dragonfly_build.zip"),
    Asset("ANIM", "anim/dragonfly_fire_build.zip"),
    Asset("ANIM", "anim/dragonfly_basic.zip"),
    Asset("ANIM", "anim/dragonfly_actions.zip"),
    Asset("ANIM", "anim/dragonfly_yule_build.zip"),
    Asset("ANIM", "anim/dragonfly_fire_yule_build.zip"),
    Asset("SOUND", "sound/dragonfly.fsb"),
}

local prefabs = {
    "dragonfly",
    "firesplash_fx",
    "tauntfire_fx",
    "attackfire_fx",
    "vomitfire_fx",
    "firering_fx",
    "dragonflycorpse",
    "explode_small",
}

local function fn(sim)
    local original = Prefabs["dragonfly"]
    if original == nil or original.fn == nil then
        return nil
    end

    -- Build the original entity directly so its components, brain, SG and
    -- animation setup remain identical to the base game boss.
    local inst = original.fn(sim)
    if inst ~= nil then
        inst:SetPrefabName("kei_recorder_dragonfly")
        inst:SetPrefabNameOverride("dragonfly")
        inst:AddTag("kei_recorder_dragonfly")
        inst.persists = false
        if inst.components ~= nil and inst.components.rampingspawner ~= nil then
            inst.components.rampingspawner.spawn_prefab = "kei_recorder_lavae"
        end
        if TheWorld.ismastersim then
            inst:SetStateGraph("SGkei_recorder_dragonfly")
        end
    end
    return inst
end

return Prefab("kei_recorder_dragonfly", fn, assets, prefabs)
