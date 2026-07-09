local assets =
{
    Asset("ANIM", "anim/fx_book_web.zip"),
    Asset("SOUND", "sound/wickerbottom_rework.fsb"),
}

local BASE_RADIUS = 6
local BASE_VISUAL_SCALE = 1.25

local function SetRadius(inst, radius)
    radius = radius or BASE_RADIUS
    local scale = BASE_VISUAL_SCALE * radius / BASE_RADIUS
    inst.AnimState:SetScale(scale, scale)
end

local function SetAlpha(inst)
    inst.AnimState:SetMultColour(1, 1, 1, TUNING.KEI_SPIDERQUEEN_WEB_ALPHA or 0.55)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Transform:SetRotation(math.random(1, 360))

    inst.AnimState:SetBank("fx_book_web")
    inst.AnimState:SetBuild("fx_book_web")
    inst.AnimState:PlayAnimation("spawn")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    SetRadius(inst, BASE_RADIUS)
    SetAlpha(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.SetRadius = SetRadius
    inst.SoundEmitter:PlaySound("wickerbottom_rework/book_spells/web")

    return inst
end

return Prefab("kei_spiderqueen_web_fx", fn, assets)
