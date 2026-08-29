local RecorderBoss = require("kei/recorder_boss")

local IGNITE_STATE = "kei_recorder_ignite"
local IGNITE_COOLDOWN = 10
local COOLDOWN_TICK = 0.25
local IGNITE_DURATION = 5

local function IsEligible(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst.kei_recorder_spawned == true
        and inst.kei_recorder_source ~= nil
        and inst.kei_recorder_source:IsValid()
        and inst.sg ~= nil
        and inst.components ~= nil
        and inst.components.health ~= nil
        and not inst.enraged
        and not inst.components.health:IsDead()
        and not inst.sg:HasAnyStateTag("busy", "grounded", "sleeping", "flight", "frozen", "electrocute")
end

local function IgniteArenaPlayers(inst)
    local source = inst.kei_recorder_source
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        local burnable = player.components ~= nil and player.components.burnable or nil
        if burnable ~= nil then
            local original_burntime = burnable.burntime
            burnable:SetBurnTime(IGNITE_DURATION)
            burnable:Ignite(false, inst, inst)
            burnable:SetBurnTime(original_burntime)
        end
        local x, _, z = player.Transform:GetWorldPosition()
        if x ~= nil then
            local fx = SpawnPrefab("firering_fx")
            if fx ~= nil then
                fx.Transform:SetPosition(x, 0, z)
            end
        end
    end
end

local function TryUseIgnite(inst)
    if IsEligible(inst)
        and (inst.kei_recorder_ignite_remaining or IGNITE_COOLDOWN) <= 0
    then
        inst.kei_recorder_ignite_remaining = IGNITE_COOLDOWN
        inst.sg:GoToState(IGNITE_STATE)
    end
end

local RecorderDragonfly = {}

RecorderDragonfly.IgniteArenaPlayers = IgniteArenaPlayers

function RecorderDragonfly.Apply(target)
    if target == nil
        or not target:IsValid()
        or target.prefab ~= "kei_recorder_dragonfly"
        or target.kei_recorder_spawned ~= true
    then
        return false
    end

    if target.sg == nil or not target.sg:HasState(IGNITE_STATE) then
        return false
    end

    local rampingspawner = target.components.rampingspawner
    if rampingspawner ~= nil then
        rampingspawner.spawn_prefab = "kei_recorder_lavae"
    end

    target.kei_recorder_ignite_remaining = IGNITE_COOLDOWN
    target.kei_recorder_ignite_task = target:DoPeriodicTask(COOLDOWN_TICK, function(inst)
        if not inst:IsValid() then
            return
        end
        if not inst.enraged then
            inst.kei_recorder_ignite_remaining = math.max(
                0,
                (inst.kei_recorder_ignite_remaining or 0) - COOLDOWN_TICK
            )
            TryUseIgnite(inst)
        end
    end)
    return true
end

function RecorderDragonfly.Remove(target)
    if target == nil then
        return
    end
    if target.kei_recorder_ignite_task ~= nil then
        target.kei_recorder_ignite_task:Cancel()
        target.kei_recorder_ignite_task = nil
    end
    target.kei_recorder_ignite_remaining = nil

    local rampingspawner = target.components ~= nil and target.components.rampingspawner or nil
    if rampingspawner ~= nil then
        rampingspawner:Stop()
        local spawns = {}
        for lavae in pairs(rampingspawner.spawns or {}) do
            table.insert(spawns, lavae)
        end
        for _, lavae in ipairs(spawns) do
            if lavae ~= nil and lavae:IsValid() then
                lavae:Remove()
            end
        end
        rampingspawner:Reset()
    end
end

return RecorderDragonfly
