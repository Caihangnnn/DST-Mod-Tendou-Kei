local RecorderBoss = require("kei/recorder/boss")

local RecorderAntlion = {}

local CASTLE_COUNT = TUNING.KEI_RECORDER_ANTLION_CASTLE_COUNT or 6
local CASTLE_RADIUS = TUNING.KEI_RECORDER_ANTLION_CASTLE_RADIUS or 12
local WALL_COOLDOWN = TUNING.KEI_RECORDER_ANTLION_WALL_COOLDOWN or 30
local STORM_UPDATE_PERIOD = TUNING.KEI_RECORDER_ANTLION_STORM_UPDATE_PERIOD or 0.5

local function IsValid(inst)
    return inst ~= nil and inst:IsValid()
end

local function IsLivingCastle(castle)
    return IsValid(castle)
        and castle.components ~= nil
        and castle.components.health ~= nil
        and not castle.components.health:IsDead()
end

local function RefreshStormWatcher(player)
    if player ~= nil
        and player.components ~= nil
        and player.components.stormwatcher ~= nil
    then
        player.components.stormwatcher:UpdateStormLevel()
    end
end

local function AddForcedSandstorm(player, source)
    if player == nil or player.components == nil or player.components.stormwatcher == nil then
        return
    end

    player._kei_recorder_antlion_sandstorm_sources =
        player._kei_recorder_antlion_sandstorm_sources or {}
    player._kei_recorder_antlion_sandstorm_sources[source] = true
    RefreshStormWatcher(player)
end

local function RemoveForcedSandstorm(player, source)
    local sources = player ~= nil and player._kei_recorder_antlion_sandstorm_sources or nil
    if sources == nil then
        return
    end

    sources[source] = nil
    if next(sources) == nil then
        player._kei_recorder_antlion_sandstorm_sources = nil
    end
    RefreshStormWatcher(player)
end

local function UpdateArenaStorm(inst)
    if not IsValid(inst) then
        return
    end

    local source = inst.kei_recorder_source
    local current = {}
    if IsValid(source) then
        for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
            current[player] = true
            AddForcedSandstorm(player, inst)
        end
    end

    for player in pairs(inst.kei_recorder_antlion_players or {}) do
        if not current[player] then
            RemoveForcedSandstorm(player, inst)
        end
    end
    inst.kei_recorder_antlion_players = current
end

local function SpawnShieldFX(inst)
    local fx = SpawnPrefab("kei_recorder_antlion_shield_fx")
    if fx ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        fx.Transform:SetPosition(x, y + 1.5, z)
    end
end

local function RepelAttacker(inst, attacker)
    if attacker == nil or not attacker:IsValid() then
        return
    end

    if attacker:HasTag("player") then
        attacker:PushEvent("repelled", { repeller = inst, radius = 4 })
        return
    end

    if attacker.Physics == nil then
        return
    end

    local ix, _, iz = inst.Transform:GetWorldPosition()
    local ax, _, az = attacker.Transform:GetWorldPosition()
    local dx, dz = ax - ix, az - iz
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance < 0.01 then
        dx, dz, distance = 1, 0, 1
    end
    attacker.Physics:SetMotorVelOverride(dx / distance * 12, 0, dz / distance * 12)
    attacker:DoTaskInTime(10 * FRAMES, function(entity)
        if entity:IsValid() and entity.Physics ~= nil then
            entity.Physics:ClearMotorVelOverride()
        end
    end)
end

local function OnShieldHit(inst, attacker)
    if not IsValid(inst) then
        return
    end
    SpawnShieldFX(inst)
    RepelAttacker(inst, attacker)
end

local function HasLivingCastles(inst)
    for _, castle in ipairs(inst.kei_recorder_antlion_castles or {}) do
        if IsLivingCastle(castle) then
            return true
        end
    end
    return false
end

local function RemoveShieldHooks(inst)
    local health = inst.components ~= nil and inst.components.health or nil
    if health ~= nil then
        if health.deltamodifierfn == inst._kei_recorder_antlion_health_hook then
            health.deltamodifierfn = inst._kei_recorder_antlion_old_healthfn
        end
        if health.DoDelta == inst._kei_recorder_antlion_dodelta_hook then
            health.DoDelta = inst._kei_recorder_antlion_old_dodelta
        end
    end

    local combat = inst.components ~= nil and inst.components.combat or nil
    if combat ~= nil and combat.GetAttacked == inst._kei_recorder_antlion_combat_hook then
        combat.GetAttacked = inst._kei_recorder_antlion_old_combat_getattacked
    end

    inst._kei_recorder_antlion_health_hook = nil
    inst._kei_recorder_antlion_old_healthfn = nil
    inst._kei_recorder_antlion_dodelta_hook = nil
    inst._kei_recorder_antlion_old_dodelta = nil
    inst._kei_recorder_antlion_combat_hook = nil
    inst._kei_recorder_antlion_old_combat_getattacked = nil
end

local function InstallShieldHooks(inst)
    local health = inst.components ~= nil and inst.components.health or nil
    if health == nil then
        return
    end

    RemoveShieldHooks(inst)
    inst._kei_recorder_antlion_old_healthfn = health.deltamodifierfn
    inst._kei_recorder_antlion_health_hook = function(component, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
        local oldfn = inst._kei_recorder_antlion_old_healthfn
        if oldfn ~= nil then
            amount = oldfn(component, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
        end
        if HasLivingCastles(inst) and type(amount) == "number" and amount < 0 then
            OnShieldHit(inst, afflicter)
            return 0
        end
        return amount
    end
    health.deltamodifierfn = inst._kei_recorder_antlion_health_hook

    inst._kei_recorder_antlion_old_dodelta = health.DoDelta
    inst._kei_recorder_antlion_dodelta_hook = function(component, amount, ...)
        if HasLivingCastles(inst) and type(amount) == "number" and amount < 0 then
            local args = { ... }
            OnShieldHit(inst, args[4])
            return 0
        end
        return inst._kei_recorder_antlion_old_dodelta(component, amount, ...)
    end
    health.DoDelta = inst._kei_recorder_antlion_dodelta_hook

    local combat = inst.components ~= nil and inst.components.combat or nil
    if combat ~= nil then
        inst._kei_recorder_antlion_old_combat_getattacked = combat.GetAttacked
        inst._kei_recorder_antlion_combat_hook = function(component, attacker, damage, weapon, stimuli, spdamage, ...)
            local has_damage = type(damage) == "number" and damage > 0
            if HasLivingCastles(inst) and (has_damage or spdamage ~= nil) then
                OnShieldHit(inst, attacker)
                return 0
            end
            return inst._kei_recorder_antlion_old_combat_getattacked(
                component, attacker, damage, weapon, stimuli, spdamage, ...
            )
        end
        combat.GetAttacked = inst._kei_recorder_antlion_combat_hook
    end
end

local function PruneCastles(inst)
    local castles = inst.kei_recorder_antlion_castles or {}
    for i = #castles, 1, -1 do
        if not IsValid(castles[i]) then
            table.remove(castles, i)
        end
    end
    inst.kei_recorder_antlion_castles = castles
    if not HasLivingCastles(inst) then
        RemoveShieldHooks(inst)
    end
end

function RecorderAntlion.OnSandcastleDestroyed(inst, castle)
    if castle ~= nil and castle.kei_recorder_cleanup then
        return
    end
    PruneCastles(inst)
end

function RecorderAntlion.SpawnSandcastles(inst)
    inst.kei_recorder_antlion_castles = inst.kei_recorder_antlion_castles or {}
    if inst.kei_recorder_antlion_castle_positions == nil
        or #inst.kei_recorder_antlion_castle_positions < CASTLE_COUNT
    then
        RecorderAntlion.PrepareCastlePositions(inst)
    end

    for i = 1, CASTLE_COUNT do
        local position = inst.kei_recorder_antlion_castle_positions[i]
        local occupied = false
        for _, old_castle in ipairs(inst.kei_recorder_antlion_castles) do
            if IsValid(old_castle)
                and old_castle:GetDistanceSqToPoint(position.x, 0, position.z) <= 1
            then
                occupied = true
                break
            end
        end

        if not occupied then
            local castle = SpawnPrefab("kei_recorder_antlion_sandcastle")
            if castle ~= nil then
                castle.Transform:SetPosition(position.x, 0, position.z)
                castle.kei_recorder_antlion_owner = inst
                table.insert(inst.kei_recorder_antlion_castles, castle)
            end
        end
    end
    InstallShieldHooks(inst)
end

function RecorderAntlion.PrepareCastlePositions(inst)
    if inst.kei_recorder_antlion_castle_positions ~= nil
        and #inst.kei_recorder_antlion_castle_positions >= CASTLE_COUNT
    then
        return
    end

    local center_x, _, center_z = inst.Transform:GetWorldPosition()
    inst.kei_recorder_antlion_castle_positions = {}
    for i = 1, CASTLE_COUNT do
        local angle = (i - 1) * TWOPI / CASTLE_COUNT
        table.insert(inst.kei_recorder_antlion_castle_positions, {
            x = center_x + math.cos(angle) * CASTLE_RADIUS,
            z = center_z + math.sin(angle) * CASTLE_RADIUS,
        })
    end
end

function RecorderAntlion.CanCastSandwall(inst)
    return IsValid(inst)
        and (inst.kei_recorder_antlion_wall_ready_time or 0) <= GetTime()
end

function RecorderAntlion.CastSandwall(inst)
    if not RecorderAntlion.CanCastSandwall(inst) then
        return false
    end

    RecorderAntlion.SpawnSandcastles(inst)
    inst.kei_recorder_antlion_wall_ready_time = GetTime() + WALL_COOLDOWN
    return true
end

function RecorderAntlion.GetArenaPlayers(inst)
    local source = inst.kei_recorder_source
    if not IsValid(source) then
        return {}
    end
    return RecorderBoss.GetArenaPlayers(source)
end

function RecorderAntlion.Apply(inst)
    if not IsValid(inst) then
        return false
    end

    RecorderAntlion.Remove(inst)
    inst.kei_recorder_antlion_players = {}
    inst.kei_recorder_antlion_castles = {}
    RecorderAntlion.PrepareCastlePositions(inst)
    RecorderAntlion.SpawnSandcastles(inst)
    inst.kei_recorder_antlion_wall_ready_time = GetTime() + WALL_COOLDOWN
    UpdateArenaStorm(inst)
    inst.kei_recorder_antlion_storm_task = inst:DoPeriodicTask(STORM_UPDATE_PERIOD, UpdateArenaStorm)
    inst.kei_recorder_antlion_castle_task = inst:DoPeriodicTask(0.25, PruneCastles)
    return true
end

function RecorderAntlion.Remove(inst)
    if inst == nil then
        return
    end

    if inst.kei_recorder_antlion_storm_task ~= nil then
        inst.kei_recorder_antlion_storm_task:Cancel()
        inst.kei_recorder_antlion_storm_task = nil
    end
    if inst.kei_recorder_antlion_castle_task ~= nil then
        inst.kei_recorder_antlion_castle_task:Cancel()
        inst.kei_recorder_antlion_castle_task = nil
    end

    for player in pairs(inst.kei_recorder_antlion_players or {}) do
        RemoveForcedSandstorm(player, inst)
    end
    inst.kei_recorder_antlion_players = nil

    for _, castle in ipairs(inst.kei_recorder_antlion_castles or {}) do
        if IsValid(castle) then
            if castle.kei_recorder_antlion_keep_alive_task ~= nil then
                castle.kei_recorder_antlion_keep_alive_task:Cancel()
                castle.kei_recorder_antlion_keep_alive_task = nil
            end
            castle.kei_recorder_cleanup = true
            castle:Remove()
        end
    end
    inst.kei_recorder_antlion_castles = nil
    inst.kei_recorder_antlion_castle_positions = nil
    inst.kei_recorder_antlion_wall_ready_time = nil
    RemoveShieldHooks(inst)
end

return RecorderAntlion
