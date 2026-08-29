local assets = {
    Asset("ANIM", "anim/bee_guard.zip"),
    Asset("ANIM", "anim/bee_guard_build.zip"),
    Asset("ANIM", "anim/bee_guard_puffy_build.zip"),
}

local prefabs = {
    "bee_poof_big",
    "bee_poof_small",
    "stinger",
    "ocean_splash_med1",
    "ocean_splash_med2",
    "beeguardcorpse",
    "kei_recorder_green_honey_trail",
}

local function LeaveGreenHoneyTrail(inst)
    if not TheWorld.ismastersim or inst.kei_recorder_beeguard_trail_spawned then
        return
    end
    inst.kei_recorder_beeguard_trail_spawned = true

    local trail = SpawnPrefab("kei_recorder_green_honey_trail")
    if trail ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        trail.Transform:SetPosition(x, y, z)
        trail.kei_recorder_source = inst.kei_recorder_source
        local source = trail.kei_recorder_source
        if source ~= nil and source:IsValid() then
            source.kei_recorder_green_honey_trails = source.kei_recorder_green_honey_trails or {}
            table.insert(source.kei_recorder_green_honey_trails, trail)
        end
        trail:SetVariation(
            math.random(7),
            1,
            TUNING.KEI_RECORDER_BEEGUARD_TRAIL_DURATION or 240
        )
    end
end

local function fn(sim)
    local original = Prefabs["beeguard"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    -- Reuse the original guard's brain, stategraph and commander callbacks.
    inst:SetPrefabName("kei_recorder_beeguard")
    inst:SetPrefabNameOverride("beeguard")
    inst:AddTag("kei_recorder_beeguard")
    inst.persists = false

    if not TheWorld.ismastersim then
        return inst
    end

    local original_focus_target = inst.FocusTarget
    inst.FocusTarget = function(guard, target)
        original_focus_target(guard, target)
        guard.components.combat:SetDefaultDamage(TUNING.KEI_RECORDER_BEEGUARD_DAMAGE or 1)
    end
    inst.components.combat:SetDefaultDamage(TUNING.KEI_RECORDER_BEEGUARD_DAMAGE or 1)
    inst.components.health.externalabsorbmodifiers:SetModifier(
        inst,
        TUNING.KEI_RECORDER_BEEGUARD_DAMAGE_REDUCTION or 0.5,
        "kei_recorder_beeguard_damage_reduction"
    )
    inst:ListenForEvent("death", LeaveGreenHoneyTrail)

    return inst
end

return Prefab("kei_recorder_beeguard", fn, assets, prefabs)
