local assets = {
    Asset("ANIM", "anim/sleepcloud.zip"),
}

local FX_DURATION = 3

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.AnimState:SetBank("sleepcloud")
    inst.AnimState:SetBuild("sleepcloud")
    inst.AnimState:PlayAnimation("sleepcloud_pst")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:DoTaskInTime(FX_DURATION, inst.Remove)
    return inst
end

return Prefab("kei_recorder_sporecloud_fx", fn, assets)
