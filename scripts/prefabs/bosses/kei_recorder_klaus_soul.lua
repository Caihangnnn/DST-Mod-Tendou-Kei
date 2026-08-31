local assets = {
    Asset("ANIM", "anim/wortox_soul_ball.zip"),
}

local prefabs = {
    "wortox_soul_heal_fx",
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst.entity:SetCanSleep(false)
    RemovePhysicsColliders(inst)

    inst.AnimState:SetBank("wortox_soul_ball")
    inst.AnimState:SetBuild("wortox_soul_ball")
    inst.AnimState:PlayAnimation("idle_loop", true)
    inst.AnimState:SetScale(.8, .8)
    inst.AnimState:SetMultColour(1, 1, 1, 1)

    inst:AddTag("companion")
    inst:AddTag("notarget")
    inst:AddTag("NOBLOCK")
    inst:AddTag("soul")
    inst:AddTag("kei_recorder_klaus_soul_healable")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("health")
    inst.components.health:SetMaxHealth(TUNING.KEI_RECORDER_KLAUS_SOUL_MAX_HEALTH or 50)
    -- Keep the soul healable while it is visually at zero health. Ordinary
    -- combat cannot select it because it has no combat component and carries
    -- the notarget tag.
    inst.components.health:SetCurrentHealth(0)
    inst.components.health:ForceUpdateHUD(true)
    inst.components.health.canheal = true
    inst:RemoveTag("isdead")
    inst.components.health.IsDead = function()
        return false
    end
    inst.components.health.deltamodifierfn = function(_, amount)
        return amount < 0 and 0 or amount
    end

    return inst
end

return Prefab("kei_recorder_klaus_soul", fn, assets, prefabs)
