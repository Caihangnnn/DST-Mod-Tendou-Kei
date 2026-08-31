local RecorderBoss = require("kei/recorder_boss")

local CHECK_PERIOD = 0.5
local ATTACK_SANITY_AMOUNT = TUNING.KEI_RECORDER_ALTERGUARDIAN_ATTACK_SANITY_AMOUNT or 50
local VANILLA_ATTACK_SANITY = TUNING.GESTALT_ATTACK_DAMAGE_SANITY or 10
local DAWN_TIMER = "kei_recorder_alterguardian_dawn_cd"
local DAWN_COOLDOWN = TUNING.KEI_RECORDER_ALTERGUARDIAN_DAWN_COOLDOWN or 30
local DAWN_FX_SCALE = TUNING.KEI_RECORDER_ALTERGUARDIAN_DAWN_FX_SCALE or 1.5
local DAWN_FX_DURATION = TUNING.KEI_RECORDER_ALTERGUARDIAN_DAWN_FX_DURATION or 4
local ENLIGHTENMENT_DRAIN_PERIOD = TUNING.KEI_RECORDER_ALTERGUARDIAN_ENLIGHTENMENT_DRAIN_PERIOD or 1
local ENLIGHTENMENT_DRAIN_AMOUNT = TUNING.KEI_RECORDER_ALTERGUARDIAN_ENLIGHTENMENT_DRAIN_AMOUNT or 10

local RecorderAlterguardian = {}

local function StopDawnFX(inst)
    if inst.kei_recorder_alterguardian_dawn_fx_task ~= nil then
        inst.kei_recorder_alterguardian_dawn_fx_task:Cancel()
        inst.kei_recorder_alterguardian_dawn_fx_task = nil
    end

    local fxs = inst.kei_recorder_alterguardian_dawn_fxs
    inst.kei_recorder_alterguardian_dawn_fxs = nil
    if fxs ~= nil then
        for _, fx in ipairs(fxs) do
            if fx ~= nil and fx:IsValid() then
                fx:Remove()
            end
        end
    end
end

local function IsValidRecorder(target)
    return target ~= nil
        and target:IsValid()
        and target.prefab == "kei_recorder_alterguardian"
        and target.kei_recorder_source ~= nil
        and target.kei_recorder_source:IsValid()
        and target.components ~= nil
        and target.components.health ~= nil
        and not target.components.health:IsDead()
end

local function IsArenaPlayer(target, player)
    if not IsValidRecorder(target) or player == nil or not player:IsValid() then
        return false
    end

    for _, arena_player in ipairs(RecorderBoss.GetArenaPlayers(target.kei_recorder_source)) do
        if arena_player == player then
            return true
        end
    end
    return false
end

local function GetRecorderFromAttacker(attacker, expected_recorder)
    local current = attacker
    for _ = 1, 4 do
        if current == nil or not current:IsValid() then
            return nil
        end

        if current.prefab == "kei_recorder_alterguardian" and IsValidRecorder(current) then
            return current
        end

        local next_attacker = current._guardian or current.caster
        if next_attacker == nil or next_attacker == current then
            break
        end
        current = next_attacker
    end

    -- The final laser blasts in the vanilla stategraph do not set caster.
    -- Resolve those only when a recorder boss is actually nearby, so vanilla
    -- laser attacks remain unchanged.
    if attacker ~= nil and attacker:IsValid() and attacker.prefab == "alterguardian_laser" then
        local x, _, z = attacker.Transform:GetWorldPosition()
        for _, candidate in ipairs(TheSim:FindEntities(
            x, 0, z, 20, nil, nil, { "kei_recorder_alterguardian" }
        )) do
            if IsValidRecorder(candidate)
                and (expected_recorder == nil or candidate == expected_recorder)
            then
                return candidate
            end
        end
    end

    return nil
end

local function SetRecorderLunacy(target, player, enabled)
    if player == nil then
        return
    end

    local players = target.kei_recorder_alterguardian_lunacy_players
    if not enabled then
        local was_tracked = players[player]
        players[player] = nil
        if not was_tracked
            or not player:IsValid()
            or player.components == nil
            or player.components.sanity == nil
        then
            return
        end

        player.components.sanity:EnableLunacy(false, target)
        return
    end

    if not player:IsValid()
        or player.components == nil
        or player.components.sanity == nil
    then
        return
    end

    if enabled then
        player.components.sanity:EnableLunacy(true, target)
        players[player] = true
    end
end

local function SyncRecorderLunacy(target)
    if not IsValidRecorder(target) then
        return
    end

    local in_arena = {}
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(target.kei_recorder_source)) do
        in_arena[player] = true
        SetRecorderLunacy(target, player, true)
    end

    local tracked_players = target.kei_recorder_alterguardian_lunacy_players
    for player in pairs(tracked_players) do
        if not in_arena[player] then
            SetRecorderLunacy(target, player, false)
        end
    end
end

local function IsFullEnlightenment(player)
    local sanity = player.components ~= nil and player.components.sanity or nil
    if sanity == nil or not sanity:IsLunacyMode() then
        return false
    end

    local max = sanity.GetMaxWithPenalty ~= nil
        and sanity:GetMaxWithPenalty()
        or sanity.max
    return max ~= nil and sanity.current >= max - 0.01
end

local function DrainFullEnlightenment(target)
    if not IsValidRecorder(target) then
        return
    end

    for player in pairs(target.kei_recorder_alterguardian_lunacy_players) do
        if IsArenaPlayer(target, player) then
            if IsFullEnlightenment(player)
                and player.components ~= nil
                and player.components.hunger ~= nil
            then
                player.components.hunger:DoDelta(-ENLIGHTENMENT_DRAIN_AMOUNT, nil, true)
            end
        else
            SetRecorderLunacy(target, player, false)
        end
    end
end

local function RestoreArenaSanity(inst)
    if not IsValidRecorder(inst) then
        return
    end

    for _, player in ipairs(RecorderBoss.GetArenaPlayers(inst.kei_recorder_source)) do
        local sanity = player.components ~= nil and player.components.sanity or nil
        if sanity ~= nil then
            local max_sanity = sanity.GetMaxWithPenalty ~= nil
                and sanity:GetMaxWithPenalty()
                or sanity.max
            local current = tonumber(sanity.current) or 0
            local amount = (tonumber(max_sanity) or 0) - current
            if amount > 0 then
                sanity:DoDelta(amount)
            end
        end
    end
end

function RecorderAlterguardian.ActivateDawn(inst)
    if not IsValidRecorder(inst) then
        return false
    end

    StopDawnFX(inst)
    local fxs = {}
    inst.kei_recorder_alterguardian_dawn_fxs = fxs
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(inst.kei_recorder_source)) do
        local fx = SpawnPrefab("archive_lockbox_player_fx")
        if fx ~= nil then
            fx.Transform:SetScale(DAWN_FX_SCALE, DAWN_FX_SCALE, DAWN_FX_SCALE)
            player:AddChild(fx)
            table.insert(fxs, fx)
        end
    end

    inst.kei_recorder_alterguardian_dawn_fx_task = inst:DoTaskInTime(DAWN_FX_DURATION, function(target)
        target.kei_recorder_alterguardian_dawn_fx_task = nil
        StopDawnFX(target)
    end)

    RestoreArenaSanity(inst)
    return true
end

function RecorderAlterguardian.CanUseDawn(inst)
    return IsValidRecorder(inst)
        and inst.components.timer ~= nil
        and not inst.components.timer:TimerExists(DAWN_TIMER)
        and inst.sg ~= nil
        and not inst.sg:HasStateTag("busy")
        and #RecorderBoss.GetArenaPlayers(inst.kei_recorder_source) > 0
end

function RecorderAlterguardian.TryUseDawn(inst)
    if not RecorderAlterguardian.CanUseDawn(inst) then
        return false
    end

    inst.components.timer:StartTimer(DAWN_TIMER, DAWN_COOLDOWN)
    inst.sg:GoToState("kei_recorder_dawn")
    return true
end

local function DrainPowerForStabilityRecovery(target, player, data, listener)
    if data == nil
        or player.components == nil
        or player.components.sanity == nil
        or player.components.hunger == nil
    then
        return
    end

    local sanity = player.components.sanity
    local current = tonumber(sanity.current) or 0
    local previous = listener.last_current
    listener.last_current = current

    if previous == nil then
        return
    end

    local recovered = current - previous
    local owned_sanity_delta = listener.owned_sanity_delta
    listener.owned_sanity_delta = nil

    if recovered > 0 then
        listener.last_positive_sanity_delta = recovered
        listener.last_positive_sanity_delta_time = GetTime()
    end

    -- Laser and trap pulses in the vanilla attack effects grant 10 SAN after
    -- their attacked event. Remove that old grant for recorder attacks after
    -- the recorder's replacement reward has been applied. The recorder's own
    -- SAN reward is deliberately not suppressed: it also consumes equal power.
    if recovered > 0
        and owned_sanity_delta == nil
        and (listener.pending_vanilla_sanity_hits or 0) > 0
        and recovered <= VANILLA_ATTACK_SANITY + 0.01
    then
        listener.pending_vanilla_sanity_hits = listener.pending_vanilla_sanity_hits - 1
        listener.last_positive_sanity_delta = nil
        listener.suppressing_vanilla_sanity = true
        player.components.sanity:DoDelta(-recovered)
        listener.suppressing_vanilla_sanity = nil
        listener.last_current = player.components.sanity.current
        return
    end

    if listener.suppressing_vanilla_sanity then
        return
    end

    if recovered > 0 and IsArenaPlayer(target, player) then
        player.components.hunger:DoDelta(-recovered, nil, true)
    end
end

local function IsPreEventSanityAttacker(attacker)
    return attacker ~= nil
        and attacker:IsValid()
        and (attacker.prefab == "gestalt_alterguardian_projectile"
            or attacker.prefab == "largeguard_alterguardian_projectile")
end

local function CancelPreEventVanillaSanity(player, listener)
    local delta = listener.last_positive_sanity_delta
    local delta_time = listener.last_positive_sanity_delta_time
    if delta == nil
        or delta_time == nil
        or GetTime() - delta_time > 0.01
        or delta > VANILLA_ATTACK_SANITY + 0.01
    then
        return
    end

    listener.last_positive_sanity_delta = nil
    listener.suppressing_vanilla_sanity = true
    player.components.sanity:DoDelta(-delta)
    listener.suppressing_vanilla_sanity = nil
    listener.last_current = player.components.sanity.current
end

local function GrantRecorderAttackSanity(target, player, listener)
    if not IsArenaPlayer(target, player)
        or player.components == nil
        or player.components.sanity == nil
    then
        return
    end

    local sanity = player.components.sanity
    local amount = ATTACK_SANITY_AMOUNT
    if amount <= 0 then
        return
    end

    listener.pending_vanilla_sanity_hits = (listener.pending_vanilla_sanity_hits or 0) + 1
    listener.owned_sanity_delta = amount
    sanity:DoDelta(amount)
    listener.owned_sanity_delta = nil

    -- A direct hit has no vanilla 10 SAN follow-up. Keep the cancellation
    -- window to the current simulation tick so later normal SAN recovery is
    -- never mistaken for an attack bonus.
    player:DoTaskInTime(0, function()
        if listener.pending_vanilla_sanity_hits ~= nil then
            listener.pending_vanilla_sanity_hits = math.max(
                0,
                listener.pending_vanilla_sanity_hits - 1
            )
        end
    end)
end

local function OnPlayerAttacked(target, player, data, listener)
    if data == nil or data.attacker == nil then
        return
    end

    local recorder = GetRecorderFromAttacker(data.attacker, target)
    if recorder == target then
        if IsPreEventSanityAttacker(data.attacker) then
            CancelPreEventVanillaSanity(player, listener)
        end
        GrantRecorderAttackSanity(target, player, listener)
    end
end

local function AddPlayerListener(target, player)
    if player == nil or not player:IsValid() then
        return
    end

    local listeners = target.kei_recorder_alterguardian_sanity_listeners
    if listeners[player] ~= nil then
        return
    end

    local sanity = player.components ~= nil and player.components.sanity or nil
    if sanity == nil then
        return
    end

    local listener = {
        last_current = sanity.current,
        pending_vanilla_sanity_hits = 0,
    }
    listener.fn = function(inst, data)
        DrainPowerForStabilityRecovery(target, inst, data, listener)
    end
    listener.attacked_fn = function(inst, data)
        OnPlayerAttacked(target, inst, data, listener)
    end
    listeners[player] = listener
    player:ListenForEvent("sanitydelta", listener.fn)
    player:ListenForEvent("attacked", listener.attacked_fn)
end

local function RemovePlayerListener(target, player, listener)
    if player ~= nil and player:IsValid() and listener ~= nil then
        player:RemoveEventCallback("sanitydelta", listener.fn)
        player:RemoveEventCallback("attacked", listener.attacked_fn)
    end
    if target.kei_recorder_alterguardian_sanity_listeners ~= nil then
        target.kei_recorder_alterguardian_sanity_listeners[player] = nil
    end
end

local function SyncPlayerListeners(target)
    if not IsValidRecorder(target) then
        return
    end

    for _, player in ipairs(AllPlayers or {}) do
        AddPlayerListener(target, player)
    end
end

function RecorderAlterguardian.Apply(target)
    if target == nil
        or not target:IsValid()
        or target.prefab ~= "kei_recorder_alterguardian"
        or target.kei_recorder_spawned ~= true
    then
        return false
    end

    RecorderAlterguardian.Remove(target)
    target.kei_recorder_alterguardian_sanity_listeners = {}
    target.kei_recorder_alterguardian_lunacy_players = {}
    SyncRecorderLunacy(target)
    SyncPlayerListeners(target)
    target.kei_recorder_alterguardian_listener_task = target:DoPeriodicTask(
        CHECK_PERIOD,
        function(inst)
            SyncRecorderLunacy(inst)
            SyncPlayerListeners(inst)
            RecorderAlterguardian.TryUseDawn(inst)
        end
    )
    target.kei_recorder_alterguardian_enlightenment_drain_task = target:DoPeriodicTask(
        ENLIGHTENMENT_DRAIN_PERIOD,
        function(inst)
            DrainFullEnlightenment(inst)
        end
    )
    return true
end

function RecorderAlterguardian.Remove(target)
    if target == nil then
        return
    end

    if target.kei_recorder_alterguardian_listener_task ~= nil then
        target.kei_recorder_alterguardian_listener_task:Cancel()
        target.kei_recorder_alterguardian_listener_task = nil
    end

    if target.kei_recorder_alterguardian_enlightenment_drain_task ~= nil then
        target.kei_recorder_alterguardian_enlightenment_drain_task:Cancel()
        target.kei_recorder_alterguardian_enlightenment_drain_task = nil
    end

    StopDawnFX(target)

    local lunacy_players = target.kei_recorder_alterguardian_lunacy_players
    target.kei_recorder_alterguardian_lunacy_players = nil
    if lunacy_players ~= nil then
        for player in pairs(lunacy_players) do
            if player ~= nil
                and player:IsValid()
                and player.components ~= nil
                and player.components.sanity ~= nil
            then
                player.components.sanity:EnableLunacy(false, target)
            end
        end
    end

    local listeners = target.kei_recorder_alterguardian_sanity_listeners
    target.kei_recorder_alterguardian_sanity_listeners = nil
    if listeners ~= nil then
        for player, listener in pairs(listeners) do
            RemovePlayerListener(target, player, listener)
        end
    end
end

return RecorderAlterguardian
