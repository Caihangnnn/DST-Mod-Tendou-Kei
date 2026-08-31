local RecorderBoss = require("kei/recorder_boss")
local WortoxSoulCommon = require("prefabs/wortox_soul_common")

local RecorderKlaus = {}

local HELL_CALL_TIMER = "kei_recorder_klaus_hell_call_cd"

local function IsActiveMinion(entity)
    local health = entity ~= nil and entity.components ~= nil and entity.components.health or nil
    return entity ~= nil
        and entity:IsValid()
        and not entity.inlimbo
        and not entity:HasTag("deadcreature")
        and not entity:HasTag("isdead")
        and not (entity.sg ~= nil and entity.sg:HasStateTag("dead"))
        and (health == nil or (not health:IsDead() and (health.currenthealth or 0) > 0))
end

-- Vanilla Wortox soul healing only searches for players. Extend that one
-- shared healing entry point so recorder souls can receive the same effect.
if not WortoxSoulCommon.kei_recorder_klaus_heal_patch then
    local vanilla_do_heal = WortoxSoulCommon.DoHeal
    WortoxSoulCommon.DoHeal = function(soul)
        vanilla_do_heal(soul)

        if soul == nil or not soul:IsValid() then
            return
        end

        local x, y, z = soul.Transform:GetWorldPosition()
        local range = TUNING.WORTOX_SOULHEAL_RANGE or 4
        for _, target in ipairs(TheSim:FindEntities(
            x,
            y,
            z,
            range,
            { "kei_recorder_klaus_soul_healable" },
            { "INLIMBO" }
        )) do
            if target:IsValid()
                and not target.kei_recorder_klaus_soul_resolved
                and target.kei_recorder_klaus_enemy ~= true
                and target.components ~= nil
                and target.components.health ~= nil
                and not target.components.health:IsDead()
            then
                target.components.health:DoDelta(
                    TUNING.KEI_RECORDER_KLAUS_SOUL_HEAL_AMOUNT or 25,
                    false,
                    "wortox_soul_heal",
                    true,
                    soul,
                    true
                )

                local fx = SpawnPrefab("wortox_soul_heal_fx")
                if fx ~= nil then
                    local tx, ty, tz = target.Transform:GetWorldPosition()
                    fx.Transform:SetPosition(tx, ty, tz)
                end
            end
        end
    end
    WortoxSoulCommon.kei_recorder_klaus_heal_patch = true
end

local function IsValidPlayer(player)
    return player ~= nil
        and player:IsValid()
        and player:HasTag("player")
        and not player:HasTag("playerghost")
        and player.components ~= nil
        and player.components.health ~= nil
        and not player.components.health:IsDead()
end

local function IsArenaPlayer(source, player)
    if source == nil or not source:IsValid() or not IsValidPlayer(player) then
        return false
    end

    for _, arena_player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        if arena_player == player then
            return true
        end
    end
    return false
end

local function RemoveTrackedRecord(owner, record)
    if owner == nil or owner.kei_recorder_klaus_entities == nil then
        return
    end

    for i = #owner.kei_recorder_klaus_entities, 1, -1 do
        if owner.kei_recorder_klaus_entities[i] == record then
            table.remove(owner.kei_recorder_klaus_entities, i)
            return
        end
    end
end

local function BindTrackedEntity(owner, record, entity)
    record.owner = owner
    record.entity = entity
    record.removefn = function()
        -- A soul record can be transferred to the replacement minion before
        -- the soul is removed, so an old onremove callback must be ignored.
        if record.owner == owner and record.entity == entity then
            RemoveTrackedRecord(owner, record)
            record.owner = nil
        end
    end
    entity:ListenForEvent("onremove", record.removefn)
end

local function TrackEntity(owner, entity, player)
    owner.kei_recorder_klaus_entities = owner.kei_recorder_klaus_entities or {}
    local record = {
        player = player,
        playerid = player ~= nil and player.userid or nil,
    }
    table.insert(owner.kei_recorder_klaus_entities, record)
    BindTrackedEntity(owner, record, entity)
    entity.kei_recorder_klaus_record = record
    return record
end

function RecorderKlaus.TransferTrackedEntity(record, entity)
    if record == nil or record.owner == nil or entity == nil or not entity:IsValid() then
        return false
    end

    BindTrackedEntity(record.owner, record, entity)
    entity.kei_recorder_klaus_record = record
    return true
end

local function CountMinionsForPlayer(owner, player)
    local entities = owner.kei_recorder_klaus_entities or {}
    local count = 0
    local counted = {}
    for i = #entities, 1, -1 do
        local record = entities[i]
        local entity = record.entity
        local is_soul = entity ~= nil and entity:HasTag("soul")
        local is_gone = entity == nil
            or not entity:IsValid()
            or entity.inlimbo
            or (not is_soul and not IsActiveMinion(entity))
        if is_gone then
            table.remove(entities, i)
        elseif entity:HasTag("kei_recorder_klaus_minion")
            and IsActiveMinion(entity)
            and not counted[entity]
            and (record.player == player
                or entity.kei_recorder_klaus_player == player
                or (record.playerid ~= nil and player ~= nil and record.playerid == player.userid)
                or (entity.kei_recorder_klaus_player ~= nil
                    and player ~= nil
                    and entity.kei_recorder_klaus_player.userid == player.userid))
        then
            counted[entity] = true
            count = count + 1
        end
    end
    return count
end

local function GetPlayerAttackDamage(player, target)
    local combat = player ~= nil and player.components ~= nil and player.components.combat or nil
    if combat == nil then
        return 0
    end

    local weapon = combat.GetWeapon ~= nil and combat:GetWeapon() or nil
    -- Use the same damage calculation as the player's actual attack. This
    -- includes weapon functions, character multipliers and damage bonuses.
    if combat.CalcDamage ~= nil then
        local ok, damage = pcall(combat.CalcDamage, combat, target or player, weapon)
        if ok and type(damage) == "number" then
            return math.max(0, damage)
        end
    end

    local base_damage = combat.defaultdamage or 0
    if weapon ~= nil and weapon.components ~= nil and weapon.components.weapon ~= nil then
        local ok, weapon_damage = pcall(weapon.components.weapon.GetDamage, weapon.components.weapon, player, player)
        if ok and type(weapon_damage) == "number" then
            base_damage = weapon_damage
        end
    end

    local external_multiplier = combat.externaldamagemultipliers ~= nil
        and combat.externaldamagemultipliers:Get()
        or 1
    return math.max(0, base_damage * (combat.damagemultiplier or 1) * external_multiplier + (combat.damagebonus or 0))
end

local function StopSoulTasks(soul)
    if soul.kei_recorder_klaus_soul_update_task ~= nil then
        soul.kei_recorder_klaus_soul_update_task:Cancel()
        soul.kei_recorder_klaus_soul_update_task = nil
    end
    if soul.kei_recorder_klaus_soul_expire_task ~= nil then
        soul.kei_recorder_klaus_soul_expire_task:Cancel()
        soul.kei_recorder_klaus_soul_expire_task = nil
    end
    if soul.kei_recorder_klaus_healthdelta_fn ~= nil then
        soul:RemoveEventCallback("healthdelta", soul.kei_recorder_klaus_healthdelta_fn)
        soul.kei_recorder_klaus_healthdelta_fn = nil
    end
end

local function UpdateSoulColour(soul)
    if soul == nil or not soul:IsValid() or soul.kei_recorder_klaus_soul_start_time == nil then
        return
    end

    local lifetime = TUNING.KEI_RECORDER_KLAUS_SOUL_LIFETIME or 15
    local progress = math.clamp(
        (GetTime() - soul.kei_recorder_klaus_soul_start_time) / lifetime,
        0,
        1
    )
    local brightness = 1 - progress
    soul.AnimState:SetMultColour(brightness, brightness, brightness, 1)
end

local function ResolveSoul(soul, healed)
    if soul == nil or not soul:IsValid() or soul.kei_recorder_klaus_soul_resolved then
        return
    end
    soul.kei_recorder_klaus_soul_resolved = true
    StopSoulTasks(soul)

    local owner = soul.kei_recorder_klaus
    local player = soul.kei_recorder_klaus_player
    local record = soul.kei_recorder_klaus_record
    local spawn_x, spawn_y, spawn_z = soul.Transform:GetWorldPosition()
    local minion
    local limit = TUNING.KEI_RECORDER_KLAUS_MINION_LIMIT_PER_PLAYER or 5
    if owner ~= nil
        and owner:IsValid()
        and IsValidPlayer(player)
        and CountMinionsForPlayer(owner, player) < limit
    then
        minion = owner:SpawnHellCallMinion(
            player,
            healed,
            soul.kei_recorder_klaus_attack_damage,
            spawn_x,
            spawn_y,
            spawn_z
        )
        if minion ~= nil and record ~= nil then
            RecorderKlaus.TransferTrackedEntity(record, minion)
        end
    end

    if soul:IsValid() then
        soul:Remove()
    end
end

local function StartSoul(soul, owner, player)
    soul.kei_recorder_klaus = owner
    soul.kei_recorder_klaus_player = player
    soul.kei_recorder_klaus_soul_start_time = GetTime()
    soul.kei_recorder_klaus_attack_damage = GetPlayerAttackDamage(player, owner)
    soul.AnimState:SetMultColour(1, 1, 1, 1)
    soul.kei_recorder_klaus_soul_update_task = soul:DoPeriodicTask(
        TUNING.KEI_RECORDER_KLAUS_SOUL_UPDATE_PERIOD or 0.1,
        UpdateSoulColour
    )

    soul.kei_recorder_klaus_healthdelta_fn = function(inst)
        if inst.components.health ~= nil
            and inst.components.health.currenthealth >= inst.components.health.maxhealth
        then
            ResolveSoul(inst, true)
        end
    end
    soul:ListenForEvent("healthdelta", soul.kei_recorder_klaus_healthdelta_fn)

    soul.kei_recorder_klaus_soul_expire_task = soul:DoTaskInTime(
        TUNING.KEI_RECORDER_KLAUS_SOUL_LIFETIME or 15,
        ResolveSoul,
        false
    )
end

local function SpawnSoul(owner, player)
    local soul = SpawnPrefab("kei_recorder_klaus_soul")
    if soul == nil then
        return nil
    end

    local x, y, z = player.Transform:GetWorldPosition()
    soul.Transform:SetPosition(x, y, z)
    StartSoul(soul, owner, player)
    TrackEntity(owner, soul, player)
    return soul
end

function RecorderKlaus.SpawnHellCallSouls(inst)
    if inst == nil or not inst:IsValid() then
        return
    end

    for _, player in ipairs(RecorderBoss.GetArenaPlayers(inst.kei_recorder_source)) do
        -- Existing NPCs limit only a soul's later conversion. Every Hell Call
        -- cast still creates a new soul for each arena player.
        if IsValidPlayer(player) then
            SpawnSoul(inst, player)
        end
        if IsValidPlayer(player) then
            player.components.health:DoDelta(
                -(TUNING.KEI_RECORDER_KLAUS_HELL_CALL_HEALTH_COST or 25),
                false,
                "kei_recorder_klaus_hell_call",
                true,
                inst,
                true
            )
        end
    end
end

function RecorderKlaus.CanUseHellCall(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst.components.health ~= nil
        and not inst.components.health:IsDead()
        and inst.sg ~= nil
        and not inst.sg:HasStateTag("busy")
        and inst.components.timer ~= nil
        and not inst.components.timer:TimerExists(HELL_CALL_TIMER)
        and inst.kei_recorder_source ~= nil
        and #RecorderBoss.GetArenaPlayers(inst.kei_recorder_source) > 0
end

function RecorderKlaus.TryHellCall(inst)
    if not RecorderKlaus.CanUseHellCall(inst) then
        return false
    end

    inst.components.timer:StartTimer(
        HELL_CALL_TIMER,
        TUNING.KEI_RECORDER_KLAUS_HELL_CALL_COOLDOWN or 30
    )
    inst.sg:GoToState("kei_recorder_hell_call")
    return true
end

function RecorderKlaus.Apply(inst)
    if inst == nil or not inst:IsValid() or not TheWorld.ismastersim then
        return false
    end

    RecorderKlaus.Remove(inst)
    inst.kei_recorder_klaus_entities = {}
    inst.SpawnHellCallMinion = RecorderKlaus.SpawnHellCallMinion
    inst.kei_recorder_klaus_skill_task = inst:DoPeriodicTask(.25, function(klaus)
        RecorderKlaus.TryHellCall(klaus)
    end)
    return true
end

function RecorderKlaus.Remove(inst)
    if inst == nil then
        return
    end

    if inst.kei_recorder_klaus_skill_task ~= nil then
        inst.kei_recorder_klaus_skill_task:Cancel()
        inst.kei_recorder_klaus_skill_task = nil
    end

    local records = inst.kei_recorder_klaus_entities
    inst.kei_recorder_klaus_entities = nil
    if records ~= nil then
        for _, record in ipairs(records) do
            record.owner = nil
            if record.entity ~= nil and record.entity:IsValid() then
                record.entity:Remove()
            end
        end
    end
end

-- The custom minion prefab calls this after it has copied its player's skin.
function RecorderKlaus.SpawnHellCallMinion(inst, player, healed, attack_damage, spawn_x, spawn_y, spawn_z)
    local minion = SpawnPrefab("kei_recorder_klaus_minion")
    if minion == nil then
        return nil
    end

    if spawn_x == nil or spawn_y == nil or spawn_z == nil then
        spawn_x, spawn_y, spawn_z = player.Transform:GetWorldPosition()
    end
    if minion.Physics ~= nil then
        minion.Physics:Teleport(spawn_x, spawn_y, spawn_z)
    else
        minion.Transform:SetPosition(spawn_x, spawn_y, spawn_z)
    end
    minion.kei_recorder_source = inst.kei_recorder_source
    minion.kei_recorder_klaus = inst
    minion.kei_recorder_klaus_player = player
    minion.kei_recorder_klaus_enemy = not healed
    minion.kei_recorder_klaus_attack_damage = TUNING.KEI_RECORDER_KLAUS_MINION_ATTACK_DAMAGE or 100
    minion:ConfigureRecorderKlausMinion(player, healed, minion.kei_recorder_klaus_attack_damage)
    return minion
end

return RecorderKlaus
