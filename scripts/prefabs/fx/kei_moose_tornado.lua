local brain = require("brains/tornadobrain")

local assets =
{
    Asset("ANIM", "anim/tornado.zip"),
}

local function OnTornadoLifetime(inst)
    inst.task = nil
    if inst.sg ~= nil then
        inst.sg:GoToState("despawn")
    else
        inst:Remove()
    end
end

local function SetDuration(inst, duration)
    if inst.task ~= nil then
        inst.task:Cancel()
    end
    inst.task = inst:DoTaskInTime(duration, OnTornadoLifetime)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOBLOCK")

    inst.AnimState:SetFinalOffset(2)
    inst.AnimState:SetBank("tornado")
    inst.AnimState:SetBuild("tornado")
    inst.AnimState:PlayAnimation("tornado_pre")
    inst.AnimState:PushAnimation("tornado_loop")

    inst.SoundEmitter:PlaySound("dontstarve_DLC001/common/tornado", "spinLoop")

    MakeInventoryPhysics(inst)
    RemovePhysicsColliders(inst)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("knownlocations")

    inst:AddComponent("locomotor")
    inst.components.locomotor.walkspeed = (TUNING.TORNADO_WALK_SPEED or 5) * 0.33
    inst.components.locomotor.runspeed = TUNING.TORNADO_WALK_SPEED or 5

    inst:SetStateGraph("SGkei_moose_tornado")
    inst:SetBrain(brain)

    inst.WINDSTAFF_CASTER = nil
    inst.WINDSTAFF_CASTER_ISPLAYER = false
    inst.KEI_DAMAGE_PER_HIT = TUNING.KEI_MOOSE_TORNADO_DAMAGE or 20
    inst.KEI_MAX_HEALTH_DAMAGE_PERCENT = TUNING.KEI_MOOSE_TORNADO_MAX_HEALTH_PERCENT or 0.0005
    inst.KEI_HIT_RADIUS = TUNING.KEI_MOOSE_TORNADO_HIT_RADIUS or 3
    inst.persists = false

    inst.SetDuration = SetDuration
    inst:SetDuration(TUNING.KEI_MOOSE_TORNADO_LIFETIME or TUNING.TORNADO_LIFETIME or 10)

    return inst
end

return Prefab("kei_moose_tornado", fn, assets)