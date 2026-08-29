local assets = {
    Asset("ANIM", "anim/daywalker_build.zip"),
    Asset("ANIM", "anim/daywalker_pillar.zip"),
    Asset("ANIM", "anim/daywalker_imprisoned.zip"),
    Asset("ANIM", "anim/daywalker_phase1.zip"),
    Asset("ANIM", "anim/daywalker_phase2.zip"),
    Asset("ANIM", "anim/daywalker_defeat.zip"),
}

local prefabs = {
    "shadow_leech",
    "daywalker_sinkhole",
    "daywalker_pillar",
    "nightmarefuel",
    "horrorfuel",
    "armordreadstone_blueprint",
    "dreadstonehat_blueprint",
    "wall_dreadstone_item_blueprint",
    "support_pillar_dreadstone_scaffold_blueprint",
    "chesspiece_daywalker_sketch",
    "winter_ornament_boss_daywalker",
}

local function fn(sim)
    local original = Prefabs["daywalker"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_daywalker")
    inst:SetPrefabNameOverride("daywalker")
    inst:AddTag("kei_recorder_daywalker")
    inst.persists = false

    -- The custom stategraph uses server-only components such as locomotor.
    -- Keep the client-side stategraph created by the vanilla prefab.
    if TheWorld.ismastersim then
        inst:SetStateGraph("SGkei_recorder_daywalker")
    end
    return inst
end

return Prefab("kei_recorder_daywalker", fn, assets, prefabs)
