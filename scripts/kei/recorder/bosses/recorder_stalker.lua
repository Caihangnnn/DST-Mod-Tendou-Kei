local RecorderBoss = require("kei/recorder/boss")

local NIGHTMARE_TIMER = "kei_recorder_stalker_nightmare_cd"
local NIGHTMARE_COOLDOWN = TUNING.KEI_RECORDER_STALKER_NIGHTMARE_COOLDOWN or 30
local NIGHTMARE_TICK = 0.25
local SANITY_STEP = 0.20

local SHADOW_PREFABS = {
    { prefab = "crawlinghorror", chance = 0.50 },
    { prefab = "terrorbeak", chance = 0.30 },
    { prefab = "ruinsnightmare", chance = 0.20 },
}

local RecorderStalker = {}

local function IsLiving(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst.components ~= nil
        and inst.components.health ~= nil
        and not inst.components.health:IsDead()
end

local function IsLivingPlayer(player)
    return player ~= nil
        and player:IsValid()
        and player:HasTag("player")
        and not player:HasTag("playerghost")
        and player.components ~= nil
        and player.components.health ~= nil
        and not player.components.health:IsDead()
end

local function SpawnFXAt(prefab, target)
    if target == nil or not target:IsValid() then
        return
    end

    local fx = SpawnPrefab(prefab)
    if fx ~= nil then
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
    end
end

local function PickShadowPrefab()
    local roll = math.random()
    local accumulated = 0
    for _, entry in ipairs(SHADOW_PREFABS) do
        accumulated = accumulated + entry.chance
        if roll <= accumulated then
            return entry.prefab
        end
    end
    return SHADOW_PREFABS[#SHADOW_PREFABS].prefab
end

local function IsAssignedTarget(shadow, target)
    return target ~= nil
        and target:IsValid()
        and IsLivingPlayer(target)
        and target == shadow.kei_recorder_stalker_target
        and shadow.kei_recorder_source ~= nil
        and shadow.kei_recorder_source:IsValid()
end

local function TrackShadow(inst, shadow)
    inst.kei_recorder_stalker_shadows = inst.kei_recorder_stalker_shadows or {}
    table.insert(inst.kei_recorder_stalker_shadows, shadow)

    shadow.kei_recorder_stalker_owner = inst
    shadow:ListenForEvent("onremove", function(entity)
        local owner = entity.kei_recorder_stalker_owner
        if owner == nil or owner.kei_recorder_stalker_shadows == nil then
            return
        end
        for i = #owner.kei_recorder_stalker_shadows, 1, -1 do
            if owner.kei_recorder_stalker_shadows[i] == entity then
                table.remove(owner.kei_recorder_stalker_shadows, i)
                break
            end
        end
    end)
end

local function SpawnShadow(inst, player)
    local prefab = PickShadowPrefab()
    local shadow = SpawnPrefab(prefab)
    if shadow == nil then
        return
    end

    local x, y, z = player.Transform:GetWorldPosition()
    shadow.Transform:SetPosition(x, y, z)
    shadow.kei_recorder_source = inst.kei_recorder_source
    shadow.kei_recorder_stalker_target = player

    -- Keep each summoned nightmare creature focused on the player whose SAN
    -- created it instead of letting the vanilla retarget function switch it.
    if shadow.components ~= nil and shadow.components.combat ~= nil then
        shadow.components.combat:SetRetargetFunction(0.5, function(entity)
            local target = entity.kei_recorder_stalker_target
            return IsAssignedTarget(entity, target) and target or nil
        end)
        shadow.components.combat:SetKeepTargetFunction(function(entity, target)
            return IsAssignedTarget(entity, target)
        end)
        shadow.components.combat:SetTarget(player)
    end

    -- The shadow creature has its own appear animation; this portal effect
    -- makes the reverse of the player's despawn effect visible at the spawn.
    SpawnFXAt("shadow_teleport_in", shadow)
    TrackShadow(inst, shadow)
end

local function GetPlayerSanityValues(player)
    local sanity = player.components ~= nil and player.components.sanity or nil
    if sanity == nil then
        return 0, 0
    end

    local maximum = sanity.GetMaxWithPenalty ~= nil
        and sanity:GetMaxWithPenalty()
        or sanity.max
    maximum = math.max(0, tonumber(maximum) or 0)
    local current = math.max(0, tonumber(sanity.current) or 0)
    return current, maximum
end

local function CastAtPlayer(inst, player)
    local current, maximum = GetPlayerSanityValues(player)
    if current <= 0 or maximum <= 0 then
        return
    end

    local summon_count = math.floor(current / (maximum * SANITY_STEP) + 0.00001)
    SpawnFXAt("shadow_despawn", player)
    player.components.sanity:DoDelta(-current)

    for _ = 1, summon_count do
        SpawnShadow(inst, player)
    end
end

function RecorderStalker.CastNightmare(inst)
    if not IsLiving(inst) then
        return false
    end

    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        return false
    end

    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        if IsLivingPlayer(player) then
            CastAtPlayer(inst, player)
        end
    end
    return true
end

function RecorderStalker.TryNightmare(inst)
    if not IsLiving(inst)
        or inst.components.timer == nil
        or inst.components.timer:TimerExists(NIGHTMARE_TIMER)
        or inst.sg == nil
        or inst.sg:HasStateTag("busy")
        or inst.kei_recorder_source == nil
        or not inst.kei_recorder_source:IsValid()
        or #RecorderBoss.GetArenaPlayers(inst.kei_recorder_source) <= 0
    then
        return false
    end

    inst.components.timer:StartTimer(NIGHTMARE_TIMER, NIGHTMARE_COOLDOWN)
    inst:PushEvent("kei_recorder_nightmare")
    return true
end

function RecorderStalker.Apply(inst)
    if not IsLiving(inst) or not TheWorld.ismastersim then
        return false
    end

    RecorderStalker.Remove(inst)
    inst.kei_recorder_stalker_shadows = {}
    inst.kei_recorder_stalker_nightmare_task = inst:DoPeriodicTask(
        NIGHTMARE_TICK,
        RecorderStalker.TryNightmare
    )
    return true
end

function RecorderStalker.Remove(inst)
    if inst == nil then
        return
    end

    if inst.kei_recorder_stalker_nightmare_task ~= nil then
        inst.kei_recorder_stalker_nightmare_task:Cancel()
        inst.kei_recorder_stalker_nightmare_task = nil
    end

    for _, shadow in ipairs(inst.kei_recorder_stalker_shadows or {}) do
        if shadow ~= nil and shadow:IsValid() then
            shadow:Remove()
        end
    end
    inst.kei_recorder_stalker_shadows = nil
end

return RecorderStalker
