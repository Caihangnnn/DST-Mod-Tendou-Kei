local assets = {
    Asset("ANIM", "anim/klaus_basic.zip"),
    Asset("ANIM", "anim/klaus_actions.zip"),
    Asset("ANIM", "anim/klaus_build.zip"),
}

local prefabs = {
    "monstermeat",
    "charcoal",
    "klaussackkey",
    "deer_red",
    "deer_blue",
    "staff_castinglight",
    "chesspiece_klaus_sketch",
    "klauscorpse",
    "winter_food3",
}

local function fn(sim)
    local original = Prefabs["klaus"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_klaus")
    inst:SetPrefabNameOverride("klaus")
    inst:AddTag("kei_recorder_klaus")
    inst.persists = false

    if not TheWorld.ismastersim then
        return inst
    end

    -- The vanilla second phase is the post-resurrection, unchained state.
    -- Enrage is a separate health-triggered transition and does not represent
    -- Klaus's second life.
    inst:Unchain(false)
    inst.components.health:SetPercent(TUNING.KLAUS_HEALTH_REZ or .5)
    inst:SetStateGraph("SGkei_recorder_klaus")
    return inst
end

return Prefab("kei_recorder_klaus", fn, assets, prefabs)
