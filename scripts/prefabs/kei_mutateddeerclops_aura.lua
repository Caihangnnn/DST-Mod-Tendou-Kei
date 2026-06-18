local assets =
{
    Asset("ANIM", "anim/deer_ice_circle.zip"),
}

local function OnAnimOver(inst)
    inst:RemoveEventCallback("animover", OnAnimOver)
    inst.SoundEmitter:KillSound("loop")
end

local function GrowFX(inst)
    inst.AnimState:PlayAnimation("pre")
    inst.AnimState:SetFrame(20)
    inst.SoundEmitter:PlaySound("dontstarve/creatures/together/deer/fx/ice_circle_LP", "loop")
    inst:ListenForEvent("animover", OnAnimOver)
end

local function KillFX(inst, quick)
    OnAnimOver(inst)
    if quick then
        inst:Remove()
        return
    end
    ErodeAway(inst, 0.75)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.AnimState:SetBank("deer_ice_circle")
    inst.AnimState:SetBuild("deer_ice_circle")
    inst.AnimState:PlayAnimation("impact")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetScale(2.2, 2.2)
    inst.AnimState:SetMultColour(0.7, 0.25, 1, 1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.Transform:SetRotation(math.random() * 360)
    inst.persists = false
    inst.GrowFX = GrowFX
    inst.KillFX = KillFX

    return inst
end

return Prefab("kei_mutateddeerclops_aura_fx", fn, assets)
