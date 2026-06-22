local prefabs =
{
    "warg_mutated_breath_fx",
}

local FLAME_DISTANCES = { 2.5, 4.5, 6.5, 8.5, 10.5 }
local FLAME_ANGLE_OFFSETS = { -18, 0, 18 }
local DAMAGE_RADIUS = 1.25
local DAMAGE_MUST_TAGS = { "_combat", "_health" }
local DAMAGE_CANT_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }

local function GetCasterPosition(inst)
    if inst.caster ~= nil and inst.caster:IsValid() then
        return inst.caster.Transform:GetWorldPosition()
    end
    return inst.Transform:GetWorldPosition()
end

local function GetPointOnFlame(inst, dist, angleoffset)
    local angle = inst.angle + angleoffset * DEGREES
    local x, y, z = GetCasterPosition(inst)
    return x + math.cos(angle) * dist, y, z - math.sin(angle) * dist
end

local function SpawnBreathFX(inst, dist, angleoffset)
    local fx = SpawnPrefab("warg_mutated_breath_fx")
    if fx == nil then
        return
    end

    local x, _, z = GetPointOnFlame(inst, dist, angleoffset)
    local scale = 1.25 + math.random() * 0.2
    local fadeoption = dist < 5 and "nofade" or (dist < 8 and "latefade" or nil)

    fx.Transform:SetPosition(x, 0, z)
    fx.Transform:SetRotation(-inst.angle / DEGREES)
    if fx.RestartFX ~= nil then
        fx:RestartFX(scale, fadeoption)
    end
end

local function IsValidTarget(inst, target)
    local caster = inst.caster
    if caster == nil
        or target == caster
        or target.components.health == nil
        or target.components.health:IsDead()
        or target.components.combat == nil
    then
        return false
    end

    if caster.components.combat ~= nil and not caster.components.combat:IsValidTarget(target) then
        return false
    end

    return true
end

local function DoFlameDamage(inst)
    if inst.caster == nil
        or not inst.caster:IsValid()
        or inst.caster.components.health == nil
        or inst.caster.components.health:IsDead()
    then
        inst:KillFX()
        return
    end

    local targets = {}
    for _, dist in ipairs(FLAME_DISTANCES) do
        for _, angleoffset in ipairs(FLAME_ANGLE_OFFSETS) do
            local x, _, z = GetPointOnFlame(inst, dist, angleoffset)
            for _, target in ipairs(TheSim:FindEntities(x, 0, z, DAMAGE_RADIUS, DAMAGE_MUST_TAGS, DAMAGE_CANT_TAGS)) do
                if targets[target] == nil and IsValidTarget(inst, target) then
                    targets[target] = true
                end
            end
        end
    end

    for target in pairs(targets) do
        target.components.combat:GetAttacked(inst.caster, TUNING.KEI_MUTATEDWARG_FLAMETHROWER_DAMAGE or 50)
    end
end

local function SpawnFlameVisuals(inst)
    if inst.caster == nil or not inst.caster:IsValid() then
        inst:KillFX()
        return
    end

    local x, y, z = GetCasterPosition(inst)
    inst.Transform:SetPosition(x, y, z)
    for _, dist in ipairs(FLAME_DISTANCES) do
        for _, angleoffset in ipairs(FLAME_ANGLE_OFFSETS) do
            SpawnBreathFX(inst, dist, angleoffset)
        end
    end
end

local function KillSound(inst)
    inst.SoundEmitter:KillSound("loop")
end

local function CancelTask(task)
    if task ~= nil then
        task:Cancel()
    end
end

local function KillFX(inst)
    if inst.killed then
        return
    end
    inst.killed = true

    CancelTask(inst.visual_task)
    CancelTask(inst.damage_task)
    CancelTask(inst.kill_task)
    inst.visual_task = nil
    inst.damage_task = nil
    inst.kill_task = nil

    inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_pst")
    inst:DoTaskInTime(6 * FRAMES, KillSound)
    inst:DoTaskInTime(1, inst.Remove)
end

local function SetCaster(inst, caster, targetpos)
    if caster == nil or targetpos == nil then
        inst:KillFX()
        return
    end

    local x, y, z = caster.Transform:GetWorldPosition()
    local dx = targetpos.x - x
    local dz = targetpos.z - z
    if dx * dx + dz * dz <= 0 then
        inst:KillFX()
        return
    end

    inst.caster = caster
    inst.Transform:SetPosition(x, y, z)
    inst:SetTargetPoint(targetpos)
end

local function SetTargetPoint(inst, targetpos)
    if inst.caster == nil or not inst.caster:IsValid() or targetpos == nil then
        return
    end

    local x, _, z = inst.caster.Transform:GetWorldPosition()
    local dx = targetpos.x - x
    local dz = targetpos.z - z
    if dx * dx + dz * dz <= 0 then
        return
    end

    inst.angle = -math.atan2(dz, dx)
    inst.Transform:SetRotation(-inst.angle / DEGREES)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("CLASSIFIED")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.angle = 0
    inst.persists = false

    inst.SetCaster = SetCaster
    inst.SetTargetPoint = SetTargetPoint
    inst.KillFX = KillFX

    inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_pre_f17")
    inst.SoundEmitter:PlaySound("rifts3/mutated_varg/blast_lp", "loop")

    inst.visual_task = inst:DoPeriodicTask(5 * FRAMES, SpawnFlameVisuals, 0)
    inst.damage_task = inst:DoPeriodicTask(TUNING.KEI_MUTATEDWARG_FLAMETHROWER_TICK or 0.5, DoFlameDamage, 0)
    inst.kill_task = inst:DoTaskInTime(TUNING.KEI_MUTATEDWARG_FLAMETHROWER_DURATION or 5, KillFX)

    return inst
end

return Prefab("kei_mutatedwarg_flamethrower", fn, nil, prefabs)
