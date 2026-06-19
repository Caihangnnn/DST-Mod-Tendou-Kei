local assets =
{
    Asset("ANIM", "anim/status_meter_wx_shield.zip"),
}

local SHIELD_COLOUR = { 249 / 255, 179 / 255, 212 / 255, 0.7 }

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("DECOR")
    inst:AddTag("NOBLOCK")

    inst.AnimState:SetBank("status_meter_wx_shield")
    inst.AnimState:SetBuild("status_meter_wx_shield")
    inst.AnimState:PlayAnimation("full", true)
    inst.AnimState:SetSymbolMultColour("border_art", SHIELD_COLOUR[1], SHIELD_COLOUR[2], SHIELD_COLOUR[3], SHIELD_COLOUR[4])
    inst.AnimState:SetSymbolMultColour("hex_art", SHIELD_COLOUR[1], SHIELD_COLOUR[2], SHIELD_COLOUR[3], SHIELD_COLOUR[4])
    inst.AnimState:SetFinalOffset(1)

    inst.Transform:SetScale(6, 6, 6)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("kei_daywalker2_shield_fx", fn, assets)
