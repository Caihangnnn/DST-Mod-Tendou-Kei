local assets = {
    Asset("ANIM", "anim/daywalker_build.zip"),
    Asset("ANIM", "anim/daywalker_buried.zip"),
    Asset("ANIM", "anim/daywalker_phase2.zip"),
    Asset("ANIM", "anim/daywalker_phase3.zip"),
    Asset("ANIM", "anim/daywalker_defeat.zip"),
    Asset("ANIM", "anim/scrapball.zip"),
}

local prefabs = {
    "daywalker2_buried_fx",
    "daywalker2_swipe_fx",
    "daywalker2_object_break_fx",
    "daywalker2_spike_break_fx",
    "daywalker2_spike_loot_fx",
    "daywalker2_cannon_break_fx",
    "daywalker2_armor1_break_fx",
    "daywalker2_armor2_break_fx",
    "daywalker2_cloth_break_fx",
    "junkball_fx",
    "junk_break_fx",
    "alterguardian_laser",
    "alterguardian_laserempty",
    "alterguardian_laserhit",
    "scrap_monoclehat",
    "wagpunk_bits",
    "gears",
    "wagpunkhat_blueprint",
    "armorwagpunk_blueprint",
    "chestupgrade_stacksize_blueprint",
    "wagpunkbits_kit_blueprint",
    "wagpunkbits_kit",
    "chesspiece_daywalker2_sketch",
    "winter_ornament_boss_daywalker2",
}

local function fn(sim)
    local original = Prefabs["daywalker2"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    -- Reuse the complete vanilla Daywalker setup while keeping this summon
    -- distinguishable from the world-spawned boss.
    inst:SetPrefabName("kei_recorder_daywalker2")
    inst:SetPrefabNameOverride("daywalker2")
    inst:AddTag("kei_recorder_daywalker2")
    inst.persists = false

    return inst
end

return Prefab("kei_recorder_daywalker2", fn, assets, prefabs)
