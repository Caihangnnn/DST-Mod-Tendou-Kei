require("stategraphs/commonstates")

local events =
{
    EventHandler("locomote", function(inst)
        local is_moving = inst.sg:HasStateTag("moving")
        local is_running = inst.sg:HasStateTag("running")
        local is_idling = inst.sg:HasStateTag("idle")

        local should_move = inst.components.locomotor:WantsToMoveForward()
        local should_run = inst.components.locomotor:WantsToRun()
        if is_moving and not should_move then
            inst.sg:GoToState(is_running and "run_stop" or "walk_stop")
        elseif (is_idling and should_move) or (is_moving and should_move and is_running ~= should_run) then
            if should_run then
                inst.sg:GoToState(inst.sg:HasStateTag("empty") and "spawn" or "run_start")
            else
                inst.sg:GoToState("walk_start")
            end
        end
    end),
}

local TARGET_TAGS = { "_combat" }
local TARGET_IGNORE_TAGS = { "INLIMBO", "playerghost", "notarget", "noattack" }

local function DoTornadoDamage(inst, target)
    if target.components.health == nil
        or target.components.health:IsDead()
        or target.components.combat == nil
        or not target.components.combat:CanBeAttacked()
        or (not TheNet:GetPVPEnabled() and inst.WINDSTAFF_CASTER_ISPLAYER and target:HasTag("player"))
    then
        return
    end

    local base_damage = inst.KEI_DAMAGE_PER_HIT or 20
    if inst.WINDSTAFF_CASTER_ISPLAYER and target:HasTag("player") then
        base_damage = base_damage * TUNING.PVP_DAMAGE_MOD
    end

    target.components.combat:GetAttacked(inst, base_damage, nil, "wind")

    if target:IsValid() and target.components.health ~= nil and not target.components.health:IsDead() then
        local max_health = target.components.health.maxhealth or 0
        local percent_damage = max_health * (inst.KEI_MAX_HEALTH_DAMAGE_PERCENT or 0.0005)
        if percent_damage > 0 then
            target.components.health:DoDelta(-percent_damage, nil, "wind")
        end
    end

    inst:PushEvent("Tornado_Do_Attack", {
        target = target,
        damage = base_damage,
    })

    if target:IsValid()
        and inst.WINDSTAFF_CASTER ~= nil
        and inst.WINDSTAFF_CASTER:IsValid()
        and target.components.combat ~= nil
        and not (target.components.health ~= nil and target.components.health:IsDead())
        and not (target.components.follower ~= nil
            and target.components.follower.keepleaderonattacked
            and target.components.follower:GetLeader() == inst.WINDSTAFF_CASTER)
    then
        target.components.combat:SuggestTarget(inst.WINDSTAFF_CASTER)
    end
end

local function DamageNearby(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, inst.KEI_HIT_RADIUS or 3, nil, TARGET_IGNORE_TAGS, TARGET_TAGS)
    for _, target in ipairs(ents) do
        if target ~= inst.WINDSTAFF_CASTER and target:IsValid() then
            DoTornadoDamage(inst, target)
        end
    end
end

local states =
{
    State{
        name = "empty",
        tags = { "idle", "empty" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("empty")
        end,
    },

    State{
        name = "idle",
        tags = { "idle" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PushAnimation("tornado_loop", false)
            DamageNearby(inst)
        end,

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "spawn",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PlayAnimation("tornado_pre")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("walk")
            end),
        },
    },

    State{
        name = "despawn",
        tags = { "busy" },

        onenter = function(inst)
            inst.Physics:Stop()
            inst.AnimState:PlayAnimation("tornado_pst")
        end,

        events =
        {
            EventHandler("animover", function(inst)
                inst:Remove()
            end),
        },
    },

    State{
        name = "walk_start",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
            inst.sg:GoToState("walk")
        end,
    },

    State{
        name = "walk",
        tags = { "moving", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:WalkForward()
            inst.AnimState:PushAnimation("tornado_loop", false)
            DamageNearby(inst)
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, DamageNearby),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("walk")
            end),
        },
    },

    State{
        name = "walk_stop",
        tags = { "canrotate" },

        onenter = function(inst)
            inst.sg:GoToState("idle")
        end,
    },

    State{
        name = "run_start",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PushAnimation("tornado_loop", false)
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, DamageNearby),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("run")
            end),
        },
    },

    State{
        name = "run",
        tags = { "moving", "running", "canrotate" },

        onenter = function(inst)
            inst.components.locomotor:RunForward()
            inst.AnimState:PushAnimation("tornado_loop", false)
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, DamageNearby),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("run")
            end),
        },
    },

    State{
        name = "run_stop",
        tags = { "idle" },

        onenter = function(inst)
            inst.components.locomotor:StopMoving()
            inst.AnimState:PushAnimation("tornado_loop", false)
        end,

        timeline =
        {
            TimeEvent(5 * FRAMES, DamageNearby),
        },

        events =
        {
            EventHandler("animqueueover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },
}

return StateGraph("kei_moose_tornado", states, events, "empty")