local assets = {
    Asset("ANIM", "anim/lunar_seed.zip"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddDynamicShadow()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("lunar_seed")
    inst.AnimState:SetBuild("lunar_seed")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetSymbolLightOverride("pb_energy_loop", 0.5)
    inst.AnimState:SetSymbolLightOverride("pb_ray", 0.5)
    inst.AnimState:SetSymbolLightOverride("SparkleBit", 0.5)
    inst.AnimState:SetSymbolLightOverride("lunar_seed_loop", 0.15)

    inst.Transform:SetScale(0.75, 0.75, 0.75)
    inst.DynamicShadow:SetSize(0.9, 0.45)
    inst.Light:SetRadius(0.8)
    inst.Light:SetFalloff(0.65)
    inst.Light:SetIntensity(0.45)
    inst.Light:SetColour(0.45, 0.72, 1)
    inst.Light:Enable(true)

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")

    inst.entity:SetPristine()

    inst.persists = false
    return inst
end

return Prefab("kei_celestial_orb_fx", fn, assets)
