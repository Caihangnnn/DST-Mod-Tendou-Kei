local assets =
{
    Asset("ANIM", "anim/status_meter_wx_shield.zip"),
}

local PULSE_COLOUR = { 249 / 255, 179 / 255, 212 / 255, 0.5 }

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
    inst.AnimState:PlayAnimation("full_pulse")
    inst.AnimState:SetSymbolMultColour("border_art", PULSE_COLOUR[1], PULSE_COLOUR[2], PULSE_COLOUR[3], PULSE_COLOUR[4])
    inst.AnimState:SetSymbolMultColour("hex_art", PULSE_COLOUR[1], PULSE_COLOUR[2], PULSE_COLOUR[3], PULSE_COLOUR[4])
    inst.AnimState:SetFinalOffset(1)
    inst.Transform:SetScale(6, 6, 6)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst:ListenForEvent("animover", inst.Remove)

    return inst
end

return Prefab("kei_rook_shield_pulse_fx", fn, assets)