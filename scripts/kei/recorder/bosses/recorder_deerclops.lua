local ICE_SPAWN_TIME = 0.25
local ICE_SPIKE_RADIUS = 1
local AOE_RANGE_PADDING = 3
local MAX_ICE_SPIKE_SFX = 6
local RecorderDeerclops = {}

local FREEZE_CANT_TAGS = {
    "INLIMBO",
    "playerghost",
    "ghost",
    "FX",
    "NOCLICK",
    "DECOR",
    "shadow",
}

local AREAATTACK_MUST_TAGS = { "_combat" }
local AREA_EXCLUDE_TAGS = {
    "INLIMBO",
    "notarget",
    "noattack",
    "flight",
    "invisible",
    "playerghost",
    "deerclops",
}

local function DoIceSpikeAOE(inst, target, x, z, data)
    if inst.kei_recorder_dissolving then
        return
    end
    inst.components.combat.ignorehitrange = true
    local ents = TheSim:FindEntities(
        x,
        0,
        z,
        ICE_SPIKE_RADIUS + AOE_RANGE_PADDING,
        AREAATTACK_MUST_TAGS,
        AREA_EXCLUDE_TAGS
    )
    for _, ent in ipairs(ents) do
        if not data.targets[ent]
            and ent:IsValid()
            and not ent:IsInLimbo()
            and not (ent.components.health ~= nil and ent.components.health:IsDead())
        then
            local range = ICE_SPIKE_RADIUS + ent:GetPhysicsRadius(0)
            if ent:GetDistanceSqToPoint(x, 0, z) < range * range
                and inst.components.combat:CanTarget(ent)
            then
                inst.components.combat:DoAttack(ent)
                data.targets[ent] = true
            end
        end
    end
    inst.components.combat.ignorehitrange = false

    if data.count > 1 then
        data.count = data.count - 1
    elseif next(data.targets) == nil then
        inst:PushEvent("onmissother", { target = target })
    end
end

local function SpawnPersistentIceSpike(inst, target, rot, info, data, hitdelay, shouldsfx)
    local spikes = inst.kei_recorder_deerclops_icespikes
    if spikes == nil then
        spikes = {}
        inst.kei_recorder_deerclops_icespikes = spikes
    end

    local spike = SpawnPrefab("kei_recorder_deerclops_icespike")
    if spike ~= nil then
        spike.Transform:SetPosition(info.x, 0, info.z)
        spike.Transform:SetRotation(rot)
        spike:SetVariation(info.big, info.variation)
        spike.owner = inst
        spike.kei_recorder_source = inst.kei_recorder_source

        for i = #spikes, 1, -1 do
            local old_spike = spikes[i]
            if old_spike == nil or not old_spike:IsValid() or old_spike._disappearing then
                table.remove(spikes, i)
            else
                local old_x, _, old_z = old_spike.Transform:GetWorldPosition()
                local dx = old_x - info.x
                local dz = old_z - info.z
                if dx * dx + dz * dz <= ICE_SPIKE_RADIUS * ICE_SPIKE_RADIUS then
                    -- Refreshing an occupied position replaces the old spike,
                    -- while preserving its retract animation.
                    old_spike:BeginDisappear()
                    table.remove(spikes, i)
                end
            end
        end
        table.insert(spikes, spike)

        if shouldsfx then
            spike.SoundEmitter:PlaySound("dontstarve/creatures/deerclops/ice_small")
        end
    end

    if hitdelay < FRAMES then
        DoIceSpikeAOE(inst, target, info.x, info.z, data)
    else
        inst:DoTaskInTime(hitdelay, DoIceSpikeAOE, target, info.x, info.z, data)
    end
end

local function QueuePersistentIceSpike(inst, delay, target, rot, info, data, hitdelay, shouldsfx)
    inst.kei_recorder_deerclops_pending_spike_tasks = inst.kei_recorder_deerclops_pending_spike_tasks or {}
    local pending_tasks = inst.kei_recorder_deerclops_pending_spike_tasks
    local task
    task = inst:DoTaskInTime(delay, function(deerclops)
        for i = #pending_tasks, 1, -1 do
            if pending_tasks[i] == task then
                table.remove(pending_tasks, i)
                break
            end
        end
        SpawnPersistentIceSpike(deerclops, target, rot, info, data, hitdelay, shouldsfx)
    end)
    table.insert(pending_tasks, task)
end

local function FreezeTarget(inst, target)
    if target == nil
        or not target:IsValid()
        or target:IsInLimbo()
        or (target.components.health ~= nil and target.components.health:IsDead())
    then
        return
    end

    if target.components.burnable ~= nil then
        if target.components.burnable:IsBurning() then
            target.components.burnable:Extinguish()
        elseif target.components.burnable:IsSmoldering() then
            target.components.burnable:SmotherSmolder()
        end
    end

    if target.sg ~= nil and not target.sg:HasStateTag("frozen") then
        target:PushEvent("attacked", { attacker = inst, damage = 0, weapon = inst })
    end

    if target:IsValid() and target.components.freezable ~= nil then
        target.components.freezable:AddColdness(10, 10)
        target.components.freezable:SpawnShatterFX()
    end
end

local function SpawnFreezeFX(inst, range)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ring = SpawnPrefab("crabking_ring_fx")
    if ring ~= nil then
        ring.Transform:SetPosition(x, y, z)
    end

    local fxcount = 8
    for _ = 1, fxcount do
        if math.random() < 0.35 then
            local theta = math.random() * TWOPI
            local radius = 2 + math.pow(math.random(), 0.8) * math.max(0, range - 2)
            local fx = SpawnPrefab("crab_king_icefx")
            if fx ~= nil then
                fx.Transform:SetPosition(
                    x + radius * math.cos(theta),
                    y,
                    z - radius * math.sin(theta)
                )
            end
        end
    end
end

local function FreezeRoar(inst)
    if inst == nil
        or not inst:IsValid()
        or inst.components.health == nil
        or inst.components.health:IsDead()
    then
        return
    end

    local range = TUNING.KEI_RECORDER_DEERCLOPS_FREEZE_ROAR_RANGE or 7.5
    local x, y, z = inst.Transform:GetWorldPosition()
    local players = TheSim:FindEntities(x, y, z, range, { "player" }, FREEZE_CANT_TAGS)
    for _, player in ipairs(players) do
        FreezeTarget(inst, player)
    end

    SpawnFreezeFX(inst, range)
end

local function SpikeInfoNearToFar(a, b)
    return a.radius < b.radius
end

local function SpawnPersistentIceSpikes(inst, target)
    local data = { targets = {}, count = 0 }
    local aoe_arc = 35
    local x, _, z = inst.Transform:GetWorldPosition()
    local angle = inst.Transform:GetRotation()
    local spikeinfo = {}

    local theta = angle * DEGREES
    local cos_theta = math.cos(theta)
    local sin_theta = math.sin(theta)
    local num = 3
    data.count = data.count + num
    for i = 1, num do
        local radius = TUNING.DEERCLOPS_ATTACK_RANGE / num * i
        table.insert(spikeinfo, {
            x = x + radius * cos_theta,
            z = z - radius * sin_theta,
            radius = radius,
        })
    end

    num = math.random(12, 17)
    data.count = data.count + num
    for i = 1, num do
        local spike_theta = (angle + math.random(aoe_arc * 2) - aoe_arc) * DEGREES
        local radius = TUNING.DEERCLOPS_ATTACK_RANGE * math.sqrt(math.random())
        table.insert(spikeinfo, {
            x = x + radius * math.cos(spike_theta),
            z = z - radius * math.sin(spike_theta),
            radius = radius,
        })
    end

    num = math.random(5, 8)
    data.count = data.count + num
    local new_arc = 180 - aoe_arc
    for i = 1, num do
        local spike_theta = (angle - 180 + math.random(new_arc * 2) - new_arc) * DEGREES
        local radius = 2 * math.random() + 1
        table.insert(spikeinfo, {
            x = x + radius * math.cos(spike_theta),
            z = z - radius * math.sin(spike_theta),
            radius = radius,
        })
    end

    table.sort(spikeinfo, SpikeInfoNearToFar)

    num = data.count
    local next_big = 1
    local delay_var = ICE_SPAWN_TIME / (num - 1) * 0.3
    local current_sfx = 0
    for i = 1, num do
        local random_index = math.floor(math.random() ^ 2 * #spikeinfo * 0.6) + 1
        local info = table.remove(spikeinfo, random_index)
        local delay = (i == 1 and 0)
            or (i == num and ICE_SPAWN_TIME)
            or (i - 1) / (num - 1) * ICE_SPAWN_TIME
                + delay_var * (math.random() - 0.5)
        local hitdelay = math.max(0, 3 * FRAMES - delay)
        local sound_index = math.floor((i - 1) / (num - 1) * (MAX_ICE_SPIKE_SFX - 1))
        local shouldsfx = sound_index >= current_sfx
        if shouldsfx then
            current_sfx = sound_index + 1
        end
        if math.floor(i * 4 / num) == next_big then
            info.big = true
            info.variation = next_big
            next_big = next_big + 1
        end
        QueuePersistentIceSpike(
            inst,
            delay,
            target,
            angle,
            info,
            data,
            hitdelay,
            shouldsfx
        )
    end
end

function RecorderDeerclops.Remove(inst)
    if inst == nil then
        return
    end

    if inst.kei_recorder_deerclops_pending_spike_tasks ~= nil then
        for _, task in ipairs(inst.kei_recorder_deerclops_pending_spike_tasks) do
            task:Cancel()
        end
        inst.kei_recorder_deerclops_pending_spike_tasks = nil
    end

    if inst.kei_recorder_deerclops_icespikes ~= nil then
        for _, spike in ipairs(inst.kei_recorder_deerclops_icespikes) do
            if spike ~= nil and spike:IsValid() then
                spike:Remove()
            end
        end
        inst.kei_recorder_deerclops_icespikes = nil
    end
end

return {
    FreezeRoar = FreezeRoar,
    SpawnPersistentIceSpikes = SpawnPersistentIceSpikes,
    Remove = RecorderDeerclops.Remove,
}
