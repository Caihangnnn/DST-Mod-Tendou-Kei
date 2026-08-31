local assets = {
    Asset("ANIM", "anim/sand_block.zip"),
    Asset("ANIM", "anim/sand_splash_fx.zip"),
}

local prefabs = {
    "sandblock",
    "glassblock",
}

local function OnDeath(inst)
    local owner = inst.kei_recorder_antlion_owner
    if owner ~= nil and owner:IsValid() and not inst.kei_recorder_cleanup then
        local recorder_antlion = require("kei/recorder_antlion")
        recorder_antlion.OnSandcastleDestroyed(owner, inst)
    end
end

local function fn(sim)
    local original = Prefabs["sandblock"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_antlion_sandcastle")
    inst:SetPrefabNameOverride("sandblock")
    inst:AddTag("kei_recorder_antlion_sandcastle")
    inst.persists = false
    inst.Transform:SetScale(2, 2, 2)
    if inst.Physics ~= nil then
        inst:SetPhysicsRadiusOverride(2.2)
        inst.Physics:SetCapsule(2.2, 2)
    end

    if TheWorld.ismastersim then
        inst.components.health:SetMaxHealth(TUNING.KEI_RECORDER_ANTLION_CASTLE_HEALTH or 200)
        if inst.components.health.SetCurrentHealth ~= nil then
            inst.components.health:SetCurrentHealth(TUNING.KEI_RECORDER_ANTLION_CASTLE_HEALTH or 200)
        end
        inst:ListenForEvent("death", OnDeath)
        inst.kei_recorder_antlion_keep_alive_task = inst:DoPeriodicTask(0.25, function(castle)
            if castle:IsValid()
                and castle.components.health ~= nil
                and not castle.components.health:IsDead()
                and not castle.components.health:IsInvincible()
                and castle.task ~= nil
            then
                castle.task:Cancel()
                castle.task = nil
            end
        end)
        inst:ListenForEvent("death", function(castle)
            if castle.kei_recorder_antlion_keep_alive_task ~= nil then
                castle.kei_recorder_antlion_keep_alive_task:Cancel()
                castle.kei_recorder_antlion_keep_alive_task = nil
            end
        end)
    end

    return inst
end

return Prefab("kei_recorder_antlion_sandcastle", fn, assets, prefabs)
