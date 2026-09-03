-- Kei's voice bank uses full Japanese interaction lines for talking and EX
-- animation lines for combat. The original weapon sound is kept intact.
local SOUND_ROOT = "tendou_kei_vc/tendou_kei_vc/"

local function Sound(name)
    return SOUND_ROOT .. name
end

local TALK_VOICE_CHANNEL = "kei_talk_voice"
local ATTACK_VOICE_CHANNEL = "kei_attack_voice"
local UPGRADE_VOICE_CHANNEL = "kei_upgrade_voice"
local HIT_VOICE_CHANNEL = "kei_hit_voice"
local DEATH_VOICE_CHANNEL = "kei_death_voice"
-- All Kei voice lines share one emitter channel so a new line always stops
-- the previous one, including a regular line interrupted by combat.
local VOICE_CHANNEL = "kei_voice"
local VOICE_PRIORITY_REGULAR = 1
local VOICE_PRIORITY_COMBAT = 2
local VOICE_PRIORITY_SPECIAL = 3
local COMBAT_VOICE_DELAY = 0.12
local COMBAT_VOICE_MIN_INTERVAL = 2
local COMBAT_VOICE_MAX_INTERVAL = 4
local COMBAT_VOICE_REGULAR_LOCK = 1.5
local REGULAR_VOICE_MIN_INTERVAL = 20
local REGULAR_VOICE_MAX_INTERVAL = 30
local REGULAR_TALK_VOICES = {
    "talk_1", "talk_2", "talk_3", "talk_4", "talk_5",
    "ghost_1", "ghost_2", "ghost_3", "ghost_5", "do_emote", "yawn",
}
local DEATH_VOICES = { "christmas_carol", "death" }
-- The extracted bank has four complete upgrade lines. Cycle them if the
-- server configuration allows more than four slot unlocks.
local UPGRADE_VOICES = { "drown_in_water", "feel_sleepy", "pose", "ghost_4" }

-- These are the three requested short battle lines.
local ATTACK_VOICES = { "attacked_1", "attacked_2", "attacked_3" }

local VOICE_DEFINITIONS = {
    { name = "talk_1", channel = TALK_VOICE_CHANNEL },
    { name = "talk_2", channel = TALK_VOICE_CHANNEL },
    { name = "talk_3", channel = TALK_VOICE_CHANNEL },
    { name = "talk_4", channel = TALK_VOICE_CHANNEL },
    { name = "talk_5", channel = TALK_VOICE_CHANNEL },
    { name = "ghost_1", channel = TALK_VOICE_CHANNEL },
    { name = "ghost_2", channel = TALK_VOICE_CHANNEL },
    { name = "ghost_3", channel = TALK_VOICE_CHANNEL },
    { name = "attacked_1", channel = ATTACK_VOICE_CHANNEL },
    { name = "attacked_2", channel = ATTACK_VOICE_CHANNEL },
    { name = "attacked_3", channel = ATTACK_VOICE_CHANNEL },
    { name = "christmas_carol", channel = DEATH_VOICE_CHANNEL },
    { name = "death", channel = DEATH_VOICE_CHANNEL },
    { name = "do_emote", channel = TALK_VOICE_CHANNEL },
    { name = "drown_in_water", channel = UPGRADE_VOICE_CHANNEL },
    { name = "feel_sleepy", channel = UPGRADE_VOICE_CHANNEL },
    { name = "pose", channel = UPGRADE_VOICE_CHANNEL },
    { name = "ghost_4", channel = UPGRADE_VOICE_CHANNEL },
    { name = "ghost_5", channel = TALK_VOICE_CHANNEL },
    { name = "yawn", channel = TALK_VOICE_CHANNEL },
}

local VOICE_IDS = {}
for id, definition in ipairs(VOICE_DEFINITIONS) do
    VOICE_IDS[definition.name] = id
end

local function IsKeiVoiceSide(inst)
    return inst ~= nil
        and inst:HasTag("kei")
        and TheWorld ~= nil
        and TheWorld.ismastersim
end

local function IsKeiIdle(inst)
    return IsKeiVoiceSide(inst)
        and not inst:HasTag("playerghost")
        and inst.sg ~= nil
        and inst.sg:HasStateTag("idle")
        and not inst:HasTag("busy")
        and not inst:HasTag("notalking")
end

local function StopKeiVoices(inst)
    if inst ~= nil and inst.SoundEmitter ~= nil then
        inst.SoundEmitter:KillSound(VOICE_CHANNEL)
        -- Stop channels used by earlier versions after a hot reload.
        inst.SoundEmitter:KillSound(TALK_VOICE_CHANNEL)
        inst.SoundEmitter:KillSound(ATTACK_VOICE_CHANNEL)
        inst.SoundEmitter:KillSound(UPGRADE_VOICE_CHANNEL)
        inst.SoundEmitter:KillSound(HIT_VOICE_CHANNEL)
        inst.SoundEmitter:KillSound(DEATH_VOICE_CHANNEL)
    end
    if inst ~= nil then
        inst._kei_voice_kind = nil
        inst._kei_voice_priority = nil
    end
end

local function QueueVoice(inst, voice, channel, priority, kind)
    if not IsKeiVoiceSide(inst) or not inst:IsValid() then
        return
    end
    local voice_id = VOICE_IDS[voice]
    if voice_id == nil then
        return
    end

    if inst.SoundEmitter ~= nil then
        StopKeiVoices(inst)
        inst._kei_voice_kind = kind
        inst._kei_voice_priority = priority
        print("[Tendou-Kei] play voice event " .. tostring(Sound(voice))
            .. " priority " .. tostring(priority))
        inst.SoundEmitter:PlaySound(Sound(voice), VOICE_CHANNEL, 0.3)
    end
end

local function CancelCombatVoice(inst)
    if inst ~= nil and inst._kei_combat_voice_task ~= nil then
        inst._kei_combat_voice_task:Cancel()
        inst._kei_combat_voice_task = nil
    end
end

local function PlayUpgradeVoice(inst, unlock_count)
    if IsKeiVoiceSide(inst) then
        CancelCombatVoice(inst)
        QueueVoice(
            inst,
            UPGRADE_VOICES[((unlock_count - 1) % #UPGRADE_VOICES) + 1],
            UPGRADE_VOICE_CHANNEL,
            VOICE_PRIORITY_SPECIAL,
            "special"
        )
    end
end

local function PlayRegularTalk(inst)
    if IsKeiIdle(inst)
        and inst._kei_combat_voice_task == nil
        and (inst._kei_combat_voice_lock_until == nil
            or GetTime() >= inst._kei_combat_voice_lock_until) then
        QueueVoice(
            inst,
            REGULAR_TALK_VOICES[math.random(#REGULAR_TALK_VOICES)],
            TALK_VOICE_CHANNEL,
            VOICE_PRIORITY_REGULAR,
            "regular"
        )
    end
end

local function ScheduleCombatVoice(inst, voice)
    if not IsKeiVoiceSide(inst) or inst:HasTag("playerghost") then
        return
    end
    if inst._kei_combat_voice_task ~= nil then
        return
    end

    -- Combat has priority over regular speech, so silence a regular line as
    -- soon as combat starts. Keep an existing combat line until its interval
    -- expires instead of cutting it off for every rapid attack event.
    if inst._kei_voice_kind == "regular" then
        StopKeiVoices(inst)
    end

    local delay = COMBAT_VOICE_DELAY
    local last_played = inst._kei_last_combat_voice_time
    if last_played ~= nil then
        local next_allowed = inst._kei_next_combat_voice_time
            or (last_played + COMBAT_VOICE_MIN_INTERVAL)
        delay = math.max(delay, next_allowed - GetTime())
    end

    inst._kei_combat_voice_task = inst:DoTaskInTime(delay, function()
        inst._kei_combat_voice_task = nil
        if not IsKeiVoiceSide(inst) or not inst:IsValid() or inst:HasTag("playerghost") then
            return
        end
        inst._kei_last_combat_voice_time = GetTime()
        inst._kei_next_combat_voice_time = GetTime()
            + COMBAT_VOICE_MIN_INTERVAL
            + math.random() * (COMBAT_VOICE_MAX_INTERVAL - COMBAT_VOICE_MIN_INTERVAL)
        inst._kei_combat_voice_lock_until = GetTime() + COMBAT_VOICE_REGULAR_LOCK
        QueueVoice(inst, voice, ATTACK_VOICE_CHANNEL, VOICE_PRIORITY_COMBAT, "combat")
    end)
end

local function PlayHitVoice(inst)
    if IsKeiVoiceSide(inst) and not inst:HasTag("playerghost") then
        -- Reuse the short battle bank entries for the vanilla hit event.
        ScheduleCombatVoice(inst, ({ "attacked_1", "attacked_2", "attacked_3" })[math.random(3)])
    end
end

local function PlayDeathVoice(inst)
    if IsKeiVoiceSide(inst) then
        CancelCombatVoice(inst)
        QueueVoice(
            inst,
            DEATH_VOICES[math.random(#DEATH_VOICES)],
            DEATH_VOICE_CHANNEL,
            VOICE_PRIORITY_SPECIAL,
            "special"
        )
    end
end

local function ScheduleIdleTalk(inst)
    if not IsKeiVoiceSide(inst) or not inst:IsValid() then
        return
    end
    local interval = REGULAR_VOICE_MIN_INTERVAL
        + math.random() * (REGULAR_VOICE_MAX_INTERVAL - REGULAR_VOICE_MIN_INTERVAL)
    inst:DoTaskInTime(interval, function()
        if not IsKeiVoiceSide(inst) or not inst:IsValid() then
            return
        end
        print("[Tendou-Kei] idle voice task fired")
        if IsKeiIdle(inst) then
            PlayRegularTalk(inst)
        end
        ScheduleIdleTalk(inst)
    end)
end

local function WrapStateOnEnter(sg, state_name, after_enter)
    local state = sg.states ~= nil and sg.states[state_name] or nil
    if state == nil or state.onenter == nil or state.__kei_voice_wrapped then
        return
    end
    local old_onenter = state.onenter
    state.onenter = function(inst, ...)
        old_onenter(inst, ...)
        after_enter(inst, ...)
    end
    state.__kei_voice_wrapped = true
end

local function AddKeiVoiceStategraphHooks(sg)
    WrapStateOnEnter(sg, "attack", function(inst)
        if IsKeiVoiceSide(inst) and inst.sg:HasStateTag("attack") then
            ScheduleCombatVoice(
                inst,
                ATTACK_VOICES[math.random(#ATTACK_VOICES)]
            )
        end
    end)

end

AddStategraphPostInit("wilson", AddKeiVoiceStategraphHooks)
AddStategraphPostInit("wilson_client", AddKeiVoiceStategraphHooks)

AddPrefabPostInit("kei", function(inst)
    if TheWorld ~= nil and TheWorld.ismastersim then
        -- Kei's regular lines are also ambient voice lines, so they do not
        -- depend on another system happening to call Talker:Say first.
        ScheduleIdleTalk(inst)
        print("[Tendou-Kei] voice initialization scheduled")

        -- This is the same hook used by the reference character. It runs on
        -- the master and PlaySound is replicated by the native SoundEmitter.
        if inst.components.talker ~= nil then
            inst.components.talker.ontalkfn = function(owner)
                if not owner:HasTag("playerghost") then
                    PlayRegularTalk(owner)
                end
            end
        end

        inst:ListenForEvent("attacked", PlayHitVoice)
        inst:ListenForEvent("death", PlayDeathVoice)

        local unlock_voice_count = 0
        inst:ListenForEvent("kei_protocol_slot_unlocked", function()
            unlock_voice_count = unlock_voice_count + 1
            PlayUpgradeVoice(inst, unlock_voice_count)
        end)
    end
end)
