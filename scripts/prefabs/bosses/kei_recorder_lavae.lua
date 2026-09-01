local brain = require("brains/recorder/kei_recorder_lavaebrain")

local assets = {
    Asset("ANIM", "anim/lavae.zip"),
    Asset("SOUND", "sound/together.fsb"),
}

local prefabs = {
    "lavae_move_fx",
    "explode_small",
}

local function Explode(inst)
    if inst.kei_recorder_lavae_exploding then
        return
    end
    inst.kei_recorder_lavae_exploding = true

    if inst.kei_recorder_lavae_death_fn ~= nil then
        inst:RemoveEventCallback("death", inst.kei_recorder_lavae_death_fn)
        inst.kei_recorder_lavae_death_fn = nil
    end

    local explosive = inst.components ~= nil and inst.components.explosive or nil
    if explosive ~= nil then
        explosive:OnBurnt()
    elseif inst:IsValid() then
        inst:Remove()
    end
end

local function fn(sim)
    local original = Prefabs["lavae"]
    if original == nil or original.fn == nil then
        return nil
    end

    -- Reuse the base lavae setup, then replace only the recorder-specific AI,
    -- stategraph and combat behaviour.
    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_lavae")
    inst:SetPrefabNameOverride("lavae")
    inst:AddTag("kei_recorder_lavae")
    inst:AddTag("noattack")
    inst.persists = false

    if not TheWorld.ismastersim then
        return inst
    end

    inst:SetStateGraph("SGkei_recorder_lavae")
    inst:SetBrain(brain)

    inst.components.combat.canattack = false
    inst.components.combat:SetDefaultDamage(0)
    inst.components.locomotor.walkspeed = 5.5 * 2

    inst.components.health.externalabsorbmodifiers:SetModifier(
        inst,
        1,
        "kei_recorder_lavae_damage_reduction"
    )

    inst:AddComponent("explosive")
    inst.components.explosive.explosivedamage = TUNING.LAVAE_DAMAGE or 50
    inst.components.explosive:SetOnExplodeFn(function(exploding)
        local fx = SpawnPrefab("explode_small")
        if fx ~= nil then
            fx.Transform:SetPosition(exploding.Transform:GetWorldPosition())
        end
    end)

    inst.kei_recorder_lavae_death_fn = Explode
    inst:ListenForEvent("death", inst.kei_recorder_lavae_death_fn)

    return inst
end

return Prefab("kei_recorder_lavae", fn, assets, prefabs)
