local easing = require("easing")
local WagBossUtil = require("prefabs/wagboss_util")

local assets =
{
    Asset("ANIM", "anim/wagboss_beam.zip"),
    Asset("SCRIPT", "scripts/prefabs/wagboss_util.lua"),
}

local BEAM_RADIUS = 3
local BEAM_RANGE_PADDING = 3
local DAMAGE_MUST_TAGS = { "_combat", "_health" }
local DAMAGE_CANT_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "flight", "invisible", "playerghost" }

local function GetLunarBurnDPS(target)
    local maxhealth = target.components.health ~= nil and target.components.health.maxhealth or nil
    return (maxhealth ~= nil and maxhealth * (TUNING.KEI_WAGBOSS_ORBITAL_STRIKE_MAX_HEALTH_DPS or 0.03) or 0)
        + (TUNING.KEI_WAGBOSS_ORBITAL_STRIKE_BONUS_DPS or 50)
end

local function CreateRing()
    local ring = CreateEntity()

    ring.persists = false
    ring.entity:AddTransform()
    ring.entity:AddAnimState()
    ring:AddTag("FX")
    ring:AddTag("NOCLICK")

    ring.AnimState:SetBank("wagboss_beam")
    ring.AnimState:SetBuild("wagboss_beam")
    ring.AnimState:PlayAnimation("ground_marker_pre")
    ring.AnimState:PushAnimation("ground_marker_loop")
    ring.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    ring.AnimState:SetLightOverride(0.3)
    ring.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    ring.AnimState:SetLayer(LAYER_BACKGROUND)
    ring.AnimState:SetSortOrder(3)

    return ring
end

local function SyncRingAnimation(inst)
    if inst.ring == nil then
        return
    end
    if inst.AnimState:IsCurrentAnimation("beam_pre") then
        local t = inst.AnimState:GetCurrentAnimationTime()
        local len = inst.ring.AnimState:GetCurrentAnimationLength()
        if t < len then
            inst.ring.AnimState:SetTime(t)
        else
            inst.ring.AnimState:PlayAnimation("ground_marker_loop", true)
            inst.ring.AnimState:SetTime(t - len)
        end
    elseif inst.AnimState:IsCurrentAnimation("beam_pst") then
        inst.ring.AnimState:PlayAnimation("ground_marker_pst")
        inst.ring.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
    else
        inst.ring.AnimState:PlayAnimation("ground_marker_loop", true)
        inst.ring.AnimState:SetTime(inst.AnimState:GetCurrentAnimationTime())
    end
end

local function PostUpdate_Client(inst)
    SyncRingAnimation(inst)
    inst._postupdating = nil
    inst.components.updatelooper:RemovePostUpdateFn(PostUpdate_Client)
end

local function OnAnimSync_Client(inst)
    if not inst._postupdating then
        inst._postupdating = true
        inst.components.updatelooper:AddPostUpdateFn(PostUpdate_Client)
    end
end

local function StartPreSound(inst)
    inst._initsoundtask = nil
    inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/beam_up")
end

local function UpdateTracking(inst, dt)
    if inst.target == nil
        or not inst.target:IsValid()
        or (inst.target.components.health ~= nil and inst.target.components.health:IsDead())
    then
        inst.target = nil
        inst.components.updatelooper:RemoveOnWallUpdateFn(UpdateTracking)
        return
    end

    dt = dt * TheSim:GetTimeScale()
    if dt > 0 then
        local t = inst.trackingt + dt
        if t >= inst.trackinglen then
            inst.target = nil
            inst.components.updatelooper:RemoveOnWallUpdateFn(UpdateTracking)
        else
            local x, _, z = inst.Transform:GetWorldPosition()
            local x1, _, z1 = inst.target.Transform:GetWorldPosition()
            local k = easing.outQuad(t, 0.8, 0.2, inst.trackinglen)
            local k1 = 1 - k
            inst.Transform:SetPosition(x * k + x1 * k1, 0, z * k + z1 * k1)
            inst.trackingt = t
        end
    end
end

local function TrackTarget(inst, target, x0, z0)
    if inst.targets == nil and inst.AnimState:IsCurrentAnimation("beam_pre") then
        if inst.target == nil then
            local x, _, z = target.Transform:GetWorldPosition()
            local dx = x - x0
            local dz = z - z0
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist > 0 then
                local k = math.min(dist / 2, 1) / dist
                inst.Transform:SetPosition(x - k * dx, 0, z - k * dz)
            else
                inst.Transform:SetPosition(x, 0, z)
            end
            inst.components.updatelooper:AddOnWallUpdateFn(UpdateTracking)
            inst.trackingt = inst.AnimState:GetCurrentAnimationTime()
            inst.trackinglen = inst.AnimState:GetCurrentAnimationLength()
        end
        inst.target = target

        if inst._initsoundtask ~= nil then
            inst._initsoundtask:Cancel()
            StartPreSound(inst)
        end
    end
end

local function IsValidBeamTarget(inst, target)
    local caster = inst.caster
    return caster ~= nil
        and caster:IsValid()
        and caster.components.combat ~= nil
        and target ~= nil
        and target:IsValid()
        and not target:IsInLimbo()
        and target.entity:IsVisible()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and target.components.combat ~= nil
        and caster.components.combat:CanTarget(target)
        and not caster.components.combat:IsAlly(target)
end

local function UpdateBeamAOE(inst)
    if inst.caster == nil or not inst.caster:IsValid() then
        inst:KillFX()
        return
    end

    local tick = GetTick()
    local prevcoloured = inst.coloured2
    local x, y, z = inst.Transform:GetWorldPosition()
    for _, target in ipairs(TheSim:FindEntities(x, 0, z, BEAM_RADIUS + BEAM_RANGE_PADDING, DAMAGE_MUST_TAGS, DAMAGE_CANT_TAGS)) do
        if IsValidBeamTarget(inst, target) then
            local physrad = target:GetPhysicsRadius(0)
            local range = BEAM_RADIUS + physrad
            local dsq = target:GetDistanceSqToPoint(x, y, z)
            if dsq < range * range then
                if inst.targets[target] == nil and inst.firsthit then
                    target.components.combat:GetAttacked(
                        inst,
                        0,
                        nil,
                        nil,
                        { planar = TUNING.WAGBOSS_BEAM_PLANAR_DAMAGE or 50 }
                    )
                else
                    local pulse = tick >= (target.components.health.lastlunarburnpulsetick or 0) + 12
                    if pulse then
                        target.components.health.lastlunarburnpulsetick = tick
                    end
                    local dmg = WagBossUtil.CalcLunarBurnTickDamage(target, GetLunarBurnDPS(target))
                    target.components.health:DoDelta(-dmg, not pulse, inst.nameoverride, nil, inst)
                end
                if target.components.grogginess ~= nil and not target.components.health:IsDead() then
                    target.components.grogginess:MaximizeGrogginess()
                end
                target.components.health.lastlunarburnpulsetick = tick
                target.components.health:RegisterLunarBurnSource(inst, WagBossUtil.LunarBurnFlags.GENERIC)
                inst.targets[target] = tick

                local c = Remap(math.sqrt(dsq), BEAM_RADIUS - physrad, BEAM_RADIUS + physrad, 0, 1)
                if c < 1 then
                    c = 1 - math.max(0, c) ^ 2
                    if target:HasTag("epic") then
                        c = c * 0.4
                    elseif target:HasTag("largecreature") then
                        c = c * 0.6
                    end
                    if target.components.colouradder == nil then
                        target:AddComponent("colouradder")
                    end
                    target.components.colouradder:PushColour(inst, c, c, c, 0)
                    prevcoloured[target] = nil
                    inst.coloured1[target] = c
                end
            end
        end
    end

    for target, lasttick in pairs(inst.targets) do
        if not target:IsValid() then
            inst.targets[target] = nil
        elseif target.components.health ~= nil and lasttick < tick then
            target.components.health:UnregisterLunarBurnSource(inst)
            inst.targets[target] = nil
        end
    end
    for target in pairs(prevcoloured) do
        if target:IsValid() and target.components.colouradder ~= nil then
            target.components.colouradder:PopColour(inst)
        end
        prevcoloured[target] = nil
    end
    inst.coloured2 = inst.coloured1
    inst.coloured1 = prevcoloured
    inst.firsthit = nil
end

local FADE_TIME = 0.75
local function UpdateColouredFade(inst, dt)
    local prevcoloured = inst.coloured2
    local t = inst.fadet + dt
    inst.fadet = t

    if t < FADE_TIME then
        local fade = easing.inQuad(t, 1, -1, FADE_TIME)
        for target, colour in pairs(prevcoloured) do
            if target:IsValid() and target.components.colouradder ~= nil then
                colour = colour * fade
                target.components.colouradder:PushColour(inst, colour, colour, colour, 0)
            else
                prevcoloured[target] = nil
            end
        end
    else
        for target in pairs(prevcoloured) do
            if target:IsValid() and target.components.colouradder ~= nil then
                target.components.colouradder:PopColour(inst)
            end
            prevcoloured[target] = nil
        end
        inst.components.updatelooper:RemoveOnUpdateFn(UpdateColouredFade)
    end
end

local function StartBeamAOE(inst)
    if inst.target ~= nil then
        inst.target = nil
        inst.components.updatelooper:RemoveOnWallUpdateFn(UpdateTracking)
    end
    inst.targets = {}
    inst.coloured1 = {}
    inst.coloured2 = {}
    inst.firsthit = true
    inst.components.updatelooper:AddOnUpdateFn(UpdateBeamAOE)
    inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/beam_down_LP", "loop")
end

local function UpdateBeamLightPre(inst)
    if inst.AnimState:IsCurrentAnimation("beam_pre") then
        local frame = inst.AnimState:GetCurrentAnimationFrame()
        if frame > 28 then
            local len = inst.AnimState:GetCurrentAnimationNumFrames()
            inst.Light:SetRadius(easing.outQuad(frame - 28, 0, 3, len - 28))
            inst.Light:Enable(true)
        end
    else
        inst.Light:SetRadius(3)
        inst.Light:Enable(true)
        inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPre)
    end
end

local function UpdateBeamLightPst(inst)
    if inst.AnimState:IsCurrentAnimation("beam_pst") then
        local frame = inst.AnimState:GetCurrentAnimationFrame()
        if frame < 5 then
            inst.Light:SetRadius(3)
            inst.Light:Enable(true)
        elseif frame < 10 then
            inst.Light:SetRadius(easing.inQuad(frame - 4, 3, -3, 10 - 4))
            inst.Light:Enable(true)
        else
            inst.Light:Enable(false)
            inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPst)
        end
    else
        inst.Light:Enable(false)
        inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamLightPst)
    end
end

local function KillFX(inst)
    if inst:IsAsleep() then
        inst:Remove()
        return
    end
    if inst.ring ~= nil then
        inst.ring.AnimState:PlayAnimation("ground_marker_pst")
    end
    inst.AnimState:PlayAnimation("beam_pst")
    inst:ListenForEvent("animover", inst.Remove)
    inst.OnEntitySleep = inst.Remove
    inst.animsync:set_local(true)
    inst.animsync:set(true)
    inst.components.updatelooper:RemoveOnUpdateFn(UpdateBeamAOE)
    inst.components.updatelooper:AddOnUpdateFn(UpdateBeamLightPst)
    if inst.coloured2 ~= nil and next(inst.coloured2) ~= nil then
        inst.components.updatelooper:AddOnUpdateFn(UpdateColouredFade)
        inst.fadet = 0
    end
    if inst.targets ~= nil then
        for target in pairs(inst.targets) do
            if target:IsValid() and target.components.health ~= nil then
                target.components.health:UnregisterLunarBurnSource(inst)
            end
        end
    end

    inst.SoundEmitter:KillSound("loop")
    inst.SoundEmitter:PlaySound("rifts5/wagstaff_boss/beam_down_pst")
end

local function SetCaster(inst, caster)
    inst.caster = caster
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddLight()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.Light:SetIntensity(0.5)
    inst.Light:SetFalloff(0.95)
    inst.Light:SetColour(0.01, 0.35, 1)
    inst.Light:Enable(false)

    inst.AnimState:SetBank("wagboss_beam")
    inst.AnimState:SetBuild("wagboss_beam")
    inst.AnimState:PlayAnimation("beam_pre")
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(0.3)

    inst.animsync = net_bool(inst.GUID, "kei_wagboss_beam_fx.animsync", "animsyncdirty")
    inst.animsync:set(true)
    inst:SetPrefabNameOverride("wagboss_robot")

    inst:AddComponent("updatelooper")

    if not TheNet:IsDedicated() then
        inst.ring = CreateRing()
        inst.ring.entity:SetParent(inst.entity)
    end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("animsyncdirty", OnAnimSync_Client)
        OnAnimSync_Client(inst)
        return inst
    end

    inst.components.updatelooper:AddOnUpdateFn(UpdateBeamLightPre)
    inst.AnimState:PushAnimation("beam_loop")

    inst:AddComponent("combat")
    inst.components.combat:SetDefaultDamage(0)
    inst.components.combat.ignorehitrange = true

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(TUNING.WAGBOSS_BEAM_PLANAR_DAMAGE)

    inst._initsoundtask = inst:DoTaskInTime(0, StartPreSound)
    inst:DoTaskInTime(inst.AnimState:GetCurrentAnimationLength(), StartBeamAOE)
    inst:DoTaskInTime(6, KillFX)

    inst.SetCaster = SetCaster
    inst.TrackTarget = TrackTarget
    inst.KillFX = KillFX
    inst.persists = false

    return inst
end

local function targetfn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")

    inst.AnimState:SetBank("wagboss_beam")
    inst.AnimState:SetBuild("wagboss_beam")
    inst.AnimState:PlayAnimation("ground_marker_pre")
    inst.AnimState:PushAnimation("ground_marker_loop", true)
    inst.AnimState:SetMultColour(242 / 255, 144 / 255, 186 / 255, 0.7)
    inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    inst.AnimState:SetLightOverride(0.3)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false

    return inst
end

return Prefab("kei_wagboss_beam_fx", fn, assets),
    Prefab("kei_wagboss_target_fx", targetfn, assets)
