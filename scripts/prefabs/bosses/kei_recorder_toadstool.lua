local assets = {
    Asset("ANIM", "anim/toadstool_basic.zip"),
    Asset("ANIM", "anim/toadstool_actions.zip"),
    Asset("ANIM", "anim/toadstool_build.zip"),
    Asset("ANIM", "anim/toadstool_upg_build.zip"),
    Asset("SOUND", "sound/together.fsb"),
}

local prefabs = {
    "toadstool",
    "kei_recorder_mushroomsprout",
    "kei_recorder_sporecloud",
}

local HYPNOSIS_COOLDOWN = 20

local function ClearRecorderSproutAbsorption(inst)
    if inst.components ~= nil and inst.components.health ~= nil then
        inst.components.health:SetAbsorptionAmount(0)
    end
end

local function StartHypnosisTask(inst)
    if inst.kei_recorder_hypnosis_task ~= nil then
        return
    end

    inst.kei_recorder_hypnosis_task = inst:DoPeriodicTask(.25, function(toadstool)
        if not toadstool:IsValid()
            or toadstool.components.health == nil
            or toadstool.components.health:IsDead()
            or toadstool.components.timer == nil
            or toadstool.components.timer:TimerExists("kei_recorder_hypnosis_cd")
            or toadstool.sg == nil
            or toadstool.sg:HasStateTag("busy")
            or toadstool.kei_recorder_source == nil
        then
            return
        end

        toadstool:PushEvent("kei_recorder_hypnosis")
    end)
end

local function fn(sim)
    local original = Prefabs["toadstool"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_toadstool")
    inst:SetPrefabNameOverride("toadstool")
    inst:AddTag("kei_recorder_toadstool")
    inst.persists = false

    -- The vanilla level update raises the toadstool's absorption as linked
    -- mushroom sprouts are added. Keep its level visuals and attack scaling,
    -- but remove that sprout-based self damage reduction for this entity.
    local original_update_level = inst.UpdateLevel
    inst.UpdateLevel = function(toadstool)
        if original_update_level ~= nil then
            original_update_level(toadstool)
        end
        ClearRecorderSproutAbsorption(toadstool)
    end
    ClearRecorderSproutAbsorption(inst)

    if not TheWorld.ismastersim then
        return inst
    end

    inst.mushroomsprout_prefab = "kei_recorder_mushroomsprout"
    inst:SetStateGraph("SGkei_recorder_toadstool")
    StartHypnosisTask(inst)

    return inst
end

return Prefab("kei_recorder_toadstool", fn, assets, prefabs)
