local COOLDOWN = TUNING.KEI_RECORDER_MALBATROSS_SKILL_COOLDOWN or 20
local COOLDOWN_TICK = 0.25
local WAVE_UPDATE_PERIOD = TUNING.KEI_RECORDER_MALBATROSS_WAVE_UPDATE_PERIOD or 0.05
local WAVE_PREFAB = "kei_recorder_malbatross_wave"

local RecorderMalbatross = {}

local function IsLiving(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst.components ~= nil
        and inst.components.health ~= nil
        and not inst.components.health:IsDead()
end

local function PruneWaves(inst)
    local waves = inst.kei_recorder_malbatross_waves or {}
    for i = #waves, 1, -1 do
        if waves[i] == nil or not waves[i]:IsValid() then
            table.remove(waves, i)
        end
    end
    inst.kei_recorder_malbatross_waves = waves
end

local function UpdateWaves(inst)
    local now = GetTime()
    for _, wave in ipairs(inst.kei_recorder_malbatross_waves or {}) do
        if wave ~= nil and wave:IsValid() then
            if wave.UpdateLinearMotion ~= nil then
                wave:UpdateLinearMotion()
            elseif wave.UpdateRingMotion ~= nil then
                wave:UpdateRingMotion()
            end
            if wave.kei_recorder_malbatross_wave_expire_time ~= nil
                and now >= wave.kei_recorder_malbatross_wave_expire_time
                and wave.BeginDisappear ~= nil
            then
                wave:BeginDisappear()
            end
        end
    end
end

local function TrackWave(inst, wave)
    if wave == nil then
        return
    end
    wave.kei_recorder_malbatross_owner = inst
    table.insert(inst.kei_recorder_malbatross_waves, wave)
end

local function GetMalbatrossCastPosition(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    return x, z
end

local function SpawnLinearWave(inst, x, z, angle, speed, lifetime, damage, travel_distance)
    local wave = SpawnPrefab(WAVE_PREFAB)
    if wave == nil then
        return
    end

    wave.Transform:SetPosition(x, 0, z)
    wave:SetLinearMotion(angle, speed, lifetime, inst, damage, travel_distance)
    TrackWave(inst, wave)
    if damage and wave.CheckForPlayerTouch ~= nil then
        wave:CheckForPlayerTouch()
    end
end

local function QueueSkillTask(inst, delay, callback)
    local task
    task = inst:DoTaskInTime(delay, function(malbatross)
        for i = #malbatross.kei_recorder_malbatross_pending_tasks, 1, -1 do
            if malbatross.kei_recorder_malbatross_pending_tasks[i] == task then
                table.remove(malbatross.kei_recorder_malbatross_pending_tasks, i)
                break
            end
        end
        if IsLiving(malbatross) then
            callback(malbatross)
        end
    end)
    table.insert(inst.kei_recorder_malbatross_pending_tasks, task)
end

local function SpawnConvergingBatch(inst, center_x, center_z)
    local count = TUNING.KEI_RECORDER_MALBATROSS_CONVERGE_WAVE_COUNT or 12
    local radius = TUNING.KEI_RECORDER_MALBATROSS_CONVERGE_RADIUS or 20
    local speed = TUNING.KEI_RECORDER_MALBATROSS_CONVERGE_SPEED or 7
    local lifetime = radius / math.max(speed, 0.1)
    local phase = math.random() * TWOPI

    for i = 1, count do
        local theta = phase + (i - 1) * TWOPI / count
        local x = center_x + math.cos(theta) * radius
        local z = center_z - math.sin(theta) * radius
        SpawnLinearWave(
            inst,
            x,
            z,
            theta / DEGREES + 180,
            speed,
            lifetime,
            false,
            radius
        )
    end
end

local function UseConvergingWaves(inst)
    local center_x, center_z = GetMalbatrossCastPosition(inst)
    local interval = TUNING.KEI_RECORDER_MALBATROSS_CONVERGE_INTERVAL or 1.5
    local layers = TUNING.KEI_RECORDER_MALBATROSS_CONVERGE_WAVE_LAYERS or 5

    SpawnConvergingBatch(inst, center_x, center_z)
    for layer = 2, layers do
        QueueSkillTask(inst, (layer - 1) * interval, function(malbatross)
            SpawnConvergingBatch(malbatross, center_x, center_z)
        end)
    end
end

local function UseRotatingRings(inst)
    local center_x, _, center_z = inst.Transform:GetWorldPosition()
    local max_radius = TUNING.KEI_RECORDER_MALBATROSS_CONVERGE_RADIUS or 20
    local duration = TUNING.KEI_RECORDER_MALBATROSS_RING_DURATION or 10
    local angular_speed = TUNING.KEI_RECORDER_MALBATROSS_RING_SPEED or 0.75

    for ring = 1, 3 do
        local radius = max_radius * ring / 3
        local count = 4 + ring * 4
        local direction = math.random() < 0.5 and -1 or 1
        local phase = math.random() * TWOPI
        for i = 1, count do
            local theta = phase + (i - 1) * TWOPI / count
            local wave = SpawnPrefab(WAVE_PREFAB)
            if wave ~= nil then
                wave:SetRingMotion(
                    center_x,
                    center_z,
                    radius,
                    theta,
                    angular_speed * direction / ring,
                    duration,
                    inst,
                    true
                )
                TrackWave(inst, wave)
            end
        end
    end
end

local function UseOutwardWaves(inst)
    local center_x, center_z = GetMalbatrossCastPosition(inst)
    local count = TUNING.KEI_RECORDER_MALBATROSS_OUTWARD_WAVE_COUNT or 24
    local speed = TUNING.KEI_RECORDER_MALBATROSS_OUTWARD_SPEED or 7
    local travel_distance = TUNING.KEI_RECORDER_MALBATROSS_OUTWARD_TRAVEL_DISTANCE or 20
    local lifetime = travel_distance / math.max(speed, 0.1)
    local layers = TUNING.KEI_RECORDER_MALBATROSS_OUTWARD_WAVE_LAYERS or 5
    local layer_interval = TUNING.KEI_RECORDER_MALBATROSS_OUTWARD_LAYER_INTERVAL or 0.8

    local function SpawnLayer(malbatross)
        for _ = 1, count do
            SpawnLinearWave(
                malbatross,
                center_x,
                center_z,
                math.random() * 360,
                speed,
                lifetime,
                true,
                travel_distance
            )
        end
    end

    SpawnLayer(inst)
    for layer = 2, layers do
        local layer_delay = (layer - 1) * layer_interval
        QueueSkillTask(inst, layer_delay, SpawnLayer)
    end
end

local function CanUseSkill(inst)
    return IsLiving(inst)
        and inst.kei_recorder_source ~= nil
        and inst.kei_recorder_source:IsValid()
        and inst.sg ~= nil
        and not inst.sg:HasAnyStateTag("busy", "flight", "frozen", "electrocute")
        and (inst.kei_recorder_malbatross_skill_remaining or 0) <= 0
end

local function TryUseSkill(inst)
    if not CanUseSkill(inst) then
        return
    end

    PruneWaves(inst)
    local effect = math.random(3)
    if effect == 1 then
        UseConvergingWaves(inst)
    elseif effect == 2 then
        UseRotatingRings(inst)
    else
        UseOutwardWaves(inst)
    end

    inst.kei_recorder_malbatross_skill_remaining = COOLDOWN
    -- The vanilla taunt state is the malbatross's roar animation.
    if inst.sg:HasState("taunt") then
        inst.sg:GoToState("taunt")
    end
end

function RecorderMalbatross.Apply(inst)
    if not IsLiving(inst) then
        return false
    end

    RecorderMalbatross.Remove(inst)
    inst.kei_recorder_malbatross_waves = {}
    inst.kei_recorder_malbatross_pending_tasks = {}
    inst.kei_recorder_malbatross_skill_remaining = 0
    inst.kei_recorder_malbatross_removed = nil

    inst.kei_recorder_malbatross_task = inst:DoPeriodicTask(COOLDOWN_TICK, function(malbatross)
        if not IsLiving(malbatross) then
            return
        end

        PruneWaves(malbatross)
        malbatross.kei_recorder_malbatross_skill_remaining = math.max(
            0,
            (malbatross.kei_recorder_malbatross_skill_remaining or 0) - COOLDOWN_TICK
        )
        TryUseSkill(malbatross)
    end)
    inst.kei_recorder_malbatross_wave_update_task = inst:DoPeriodicTask(
        WAVE_UPDATE_PERIOD,
        UpdateWaves
    )
    return true
end

function RecorderMalbatross.Remove(inst)
    if inst == nil then
        return
    end

    inst.kei_recorder_malbatross_removed = true
    if inst.kei_recorder_malbatross_task ~= nil then
        inst.kei_recorder_malbatross_task:Cancel()
        inst.kei_recorder_malbatross_task = nil
    end
    if inst.kei_recorder_malbatross_wave_update_task ~= nil then
        inst.kei_recorder_malbatross_wave_update_task:Cancel()
        inst.kei_recorder_malbatross_wave_update_task = nil
    end

    for _, task in ipairs(inst.kei_recorder_malbatross_pending_tasks or {}) do
        task:Cancel()
    end
    inst.kei_recorder_malbatross_pending_tasks = nil

    for _, wave in ipairs(inst.kei_recorder_malbatross_waves or {}) do
        if wave ~= nil and wave:IsValid() then
            wave:Remove()
        end
    end
    inst.kei_recorder_malbatross_waves = nil
    inst.kei_recorder_malbatross_skill_remaining = nil
end

return RecorderMalbatross
