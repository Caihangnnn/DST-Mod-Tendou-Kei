require("stategraphs/commonstates")

local POSING_MASS = 200
local DEFAULT_MASS = 50
local SIGN_ATTACK_RANGE = 2.5

local function HasSign(inst)
    return inst.kei_recorder_propsign ~= nil
        and inst.kei_recorder_propsign:IsValid()
        and inst.components.inventory ~= nil
        and inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == inst.kei_recorder_propsign
end

local function DoSignAttack(inst)
    local target = inst.sg.statemem.target
    if target == nil or not target:IsValid() or not target:HasTag("player")
        or target:HasTag("playerghost")
        or target.components.health == nil or target.components.health:IsDead()
        or not HasSign(inst)
    then
        return
    end

    local range = SIGN_ATTACK_RANGE + target:GetPhysicsRadius(.5)
    if inst:GetDistanceSqToInst(target) > range * range then
        return
    end

    target:PushEvent("knockback", {
        knocker = inst,
        radius = SIGN_ATTACK_RANGE,
        strengthmult = 1.4,
        forcelanded = true,
    })

    local sign = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    if sign ~= nil then
        sign:PushEvent("propsmashed", inst:GetPosition())
    end
end

local events = {
    CommonHandlers.OnAttack(),
    CommonHandlers.OnFreeze(),
    CommonHandlers.OnElectrocute(),
    CommonHandlers.OnSleepEx(),
    CommonHandlers.OnWakeEx(),
    CommonHandlers.OnLocomote(true, true),
    CommonHandlers.OnAttacked(),
    CommonHandlers.OnDeath(),
    CommonHandlers.OnHop(),
}

local states = {
    State{
        name = "idle",
        tags = { "idle", "canrotate" },

        onenter = function(inst)
            if inst.sg.mem.sleeping then
                inst.sg:GoToState("sleep")
            else
                inst.components.locomotor:Stop()
                inst.AnimState:PlayAnimation("idle_object_loop", true)
            end
        end,
    },

    State{
        name = "attack",
        tags = { "attack", "busy" },

        onenter = function(inst, target)
            if not HasSign(inst) then
                inst.sg:GoToState("idle")
                return
            end

            inst.components.combat:StartAttack()
            inst.components.locomotor:Stop()
            inst.AnimState:PlayAnimation("atk_object")
            inst.SoundEmitter:PlaySound("dontstarve/pig/attack")
            inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_whoosh")
            target = target or inst.components.combat.target
            if target ~= nil and target:IsValid() then
                inst:ForceFacePoint(target.Transform:GetWorldPosition())
                inst.sg.statemem.target = target
            end
        end,

        timeline = {
            TimeEvent(7 * FRAMES, DoSignAttack),
            TimeEvent(19 * FRAMES, function(inst)
                inst.sg:RemoveStateTag("attack")
                inst.sg:RemoveStateTag("busy")
            end),
        },

        events = {
            EventHandler("animover", function(inst)
                if inst.AnimState:AnimDone() then
                    inst.sg:GoToState("idle")
                end
            end),
        },
    },

    State{
        name = "hit",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/pig/oink")
            inst.AnimState:PlayAnimation("hit")
            inst.Physics:Stop()
        end,

        events = {
            EventHandler("animover", function(inst)
                inst.sg:GoToState("idle")
            end),
        },
    },

    State{
        name = "death",
        tags = { "busy" },

        onenter = function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/pig/grunt")
            inst.AnimState:PlayAnimation("death")
            inst.Physics:Stop()
            RemovePhysicsColliders(inst)
        end,

        events = {
            CommonHandlers.OnCorpseDeathAnimOver(),
        },
    },

    State{
        name = "spawnin",
        tags = { "intropose", "busy", "nofreeze", "nosleep", "noattack", "jumping", "noelectrocute" },

        onenter = function(inst, data)
            inst.AnimState:PlayAnimation(inst.sg.mem.variation == "3" and "side_lob" or "front_lob")
            inst.AnimState:PushAnimation("pose" .. inst.sg.mem.variation .. "_pre", false)
            inst.AnimState:PushAnimation("pose" .. inst.sg.mem.variation .. "_pst", false)
            inst.SoundEmitter:PlaySound("dontstarve/movement/twirl_LP", "twirl")
            if data ~= nil and data.dest ~= nil then
                ToggleOffAllObjectCollisions(inst)
                inst:ForceFacePoint(data.dest)
                inst.Physics:SetMotorVelOverride(math.sqrt(inst:GetDistanceSqToPoint(data.dest)) / (22 * FRAMES), 0, 0)
                inst.Physics:SetMass(POSING_MASS)
            end
            inst.sg:SetTimeout(
                (inst.sg.mem.variation == "1" and (21 + 15) * FRAMES) or
                (inst.sg.mem.variation == "2" and (21 + 15) * FRAMES) or
                (inst.sg.mem.variation == "3" and (21 + 13) * FRAMES) or
                (21 + 13) * FRAMES
            )
        end,

        timeline = {
            TimeEvent(20.5 * FRAMES, function(inst)
                inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
            end),
            TimeEvent(21.5 * FRAMES, PlayFootstep),
            TimeEvent(22 * FRAMES, function(inst)
                inst.SoundEmitter:KillSound("twirl")
                inst.Physics:ClearMotorVelOverride()
                inst.Physics:Stop()
                local x, _, z = inst.Transform:GetWorldPosition()
                ToggleOnAllObjectCollisionsAt(inst, x, z)
                inst.sg:RemoveStateTag("jumping")
            end),
        },

        ontimeout = function(inst)
            inst.components.talker:Chatter("PIG_ELITE_FIGHTER_INTRO", tonumber(inst.sg.mem.variation))
        end,

        events = {
            CommonHandlers.OnNoSleepAnimQueueOver("idle"),
        },

        onexit = function(inst)
            inst.SoundEmitter:KillSound("twirl")
            inst.Physics:ClearMotorVelOverride()
            inst.Physics:Stop()
            local x, _, z = inst.Transform:GetWorldPosition()
            ToggleOnAllObjectCollisionsAt(inst, x, z)
            inst.Physics:SetMass(DEFAULT_MASS)
        end,
    },
}

CommonStates.AddWalkStates(states, {
    walktimeline = {
        TimeEvent(0, PlayFootstep),
        TimeEvent(12 * FRAMES, PlayFootstep),
    },
})

CommonStates.AddRunStates(states)
CommonStates.AddSleepExStates(states, {
    starttimeline = {
        TimeEvent(13 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("caninterrupt")
        end),
    },
    sleeptimeline = {
        TimeEvent(35 * FRAMES, function(inst)
            inst.SoundEmitter:PlaySound("dontstarve/pig/sleep")
        end),
    },
}, {
    onsleep = function(inst)
        inst.sg:AddStateTag("caninterrupt")
    end,
})

CommonStates.AddFrozenStates(states)
CommonStates.AddElectrocuteStates(states)
CommonStates.AddHopStates(states, true, {
    pre = "boat_jump_pre",
    loop = "boat_jump_loop",
    pst = "boat_jump_pst",
})
CommonStates.AddInitState(states, "idle")
CommonStates.AddCorpseStates(states, nil, nil, "pigcorpse")

return StateGraph("kei_recorder_pigelitefighter", states, events, "init")
