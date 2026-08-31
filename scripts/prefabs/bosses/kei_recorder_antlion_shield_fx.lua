local assets = {
    Asset("ANIM", "anim/stalker_shield.zip"),
}

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst.AnimState:SetBank("stalker_shield")
    inst.AnimState:SetBuild("stalker_shield")
    inst.AnimState:PlayAnimation("idle" .. tostring(math.random(1, 3)))
    inst.AnimState:SetScale(2.36, 2.36, 2.36)
    inst.AnimState:SetMultColour(0.95, 0.68, 0.18, 1)
    inst.AnimState:SetFinalOffset(2)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/stalker/shield")
    inst:ListenForEvent("animover", inst.Remove)
    inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength() + FRAMES, inst.Remove)
    return inst
end

return Prefab("kei_recorder_antlion_shield_fx", fn, assets)
