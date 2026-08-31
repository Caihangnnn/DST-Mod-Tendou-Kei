local assets = {
    Asset("ANIM", "anim/antlion_build.zip"),
    Asset("ANIM", "anim/antlion_basic.zip"),
    Asset("ANIM", "anim/antlion_action.zip"),
    Asset("ANIM", "anim/sand_splash_fx.zip"),
}

local prefabs = {
    "antlion",
    "sandspike",
    "sandblock",
    "kei_recorder_antlion_sandcastle",
    "kei_recorder_antlion_shield_fx",
}

local function fn(sim)
    local original = Prefabs["antlion"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_antlion")
    inst:SetPrefabNameOverride("antlion")
    inst:AddTag("kei_recorder_antlion")
    inst.persists = false

    if TheWorld.ismastersim then
        -- The vanilla antlion only creates combat components while persistent.
        inst.persists = true
        inst:StartCombat()
        inst.persists = false
        inst:SetStateGraph("SGkei_recorder_antlion")
    end

    return inst
end

return Prefab("kei_recorder_antlion", fn, assets, prefabs)
