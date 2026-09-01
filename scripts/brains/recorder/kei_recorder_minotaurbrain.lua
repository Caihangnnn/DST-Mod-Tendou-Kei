require "behaviours/standstill"
require "behaviours/runaway"
require "behaviours/doaction"
require "behaviours/chaseandattack"

local BrainCommon = require("brains/braincommon")
local RecorderChaseAndRam = require("behaviours/recorder/kei_recorder_chaseandram")

local START_FACE_DIST = 14
local KEEP_FACE_DIST = 16
local GO_HOME_DIST = 40
local MAX_CHASE_TIME = 5
local RUN_AWAY_DIST = 5
local STOP_RUN_AWAY_DIST = 15
local MAX_JUMP_ATTACK_RANGE = 15

local RecorderMinotaurBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GoHomeAction(inst)
    if inst.components.combat.target ~= nil then
        return
    end
    local homePos = inst.components.knownlocations:GetLocation("home")
    return homePos ~= nil
        and BufferedAction(inst, nil, ACTIONS.WALKTO, nil, homePos, nil, .2)
        or nil
end

local function GetFaceTargetFn(inst)
    local homePos = inst.components.knownlocations:GetLocation("home")
    if homePos ~= nil and inst:GetDistanceSqToPoint(homePos:Get()) > GO_HOME_DIST * GO_HOME_DIST then
        return
    end
    local target = FindClosestPlayerToInst(inst, START_FACE_DIST, true)
    return target ~= nil and not target:HasTag("notarget") and target or nil
end

local function KeepFaceTargetFn(inst, target)
    local homePos = inst.components.knownlocations:GetLocation("home")
    return (homePos == nil or
            inst:GetDistanceSqToPoint(homePos:Get()) <= GO_HOME_DIST * GO_HOME_DIST)
        and not target:HasTag("notarget")
        and inst:IsNear(target, KEEP_FACE_DIST)
end

local function ShouldGoHome(inst)
    local homePos = inst.components.knownlocations:GetLocation("home")
    if homePos == nil then
        return false
    end
    local dist_sq = inst:GetDistanceSqToPoint(homePos:Get())
    return dist_sq > GO_HOME_DIST * GO_HOME_DIST
        or (dist_sq > 10 * 10 and inst.components.combat.target == nil)
end

local function ShouldRam(inst)
    if inst.sg:HasStateTag("recorder_ram") then
        return true
    end

    local target = inst.components.combat.target
    if target == nil or not target:IsValid()
        or (target.components.health ~= nil and target.components.health:IsDead())
    then
        return false
    end

    if inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("stunned")
        or inst.sg:HasStateTag("leapattack")
    then
        return false
    end

    return not inst.components.timer:TimerExists("kei_recorder_ram_cd")
end

local function ShouldJumpAttack(inst)
    if inst.components.health:GetPercent() > 0.6 then
        return false
    end

    if inst.sg:HasStateTag("busy") or inst.sg:HasStateTag("running") then
        return false
    end

    if inst.components.timer:TimerExists("stunned") then
        return false
    end

    local target = inst.components.combat.target
    if target ~= nil and target:IsValid() then
        local x, y, z = inst.Transform:GetWorldPosition()
        local targx, targy, targz = target.Transform:GetWorldPosition()
        local targetdist = distsq(x, z, targx, targz)
        if targetdist >= MAX_JUMP_ATTACK_RANGE * MAX_JUMP_ATTACK_RANGE then
            return false
        end

        if inst.components.timer:TimerExists("leapattack_cooldown") and
            targetdist < inst.components.combat:CalcAttackRangeSq(target)
        then
            return false
        end

        return true
    end
    return false
end

local function DoJumpAttack(inst)
    local target = inst.components.combat.target
    if target ~= nil and not inst.sg:HasStateTag("leapattack") then
        inst:FacePoint(target.Transform:GetWorldPosition())
        inst:PushEventImmediate("doleapattack")
    end
end

function RecorderMinotaurBrain:OnStart()
    local root = PriorityNode({
        WhileNode(function() return not self.inst.sg:HasStateTag("leapattack") end, "not jumping",
            PriorityNode({
                WhileNode(function() return ShouldJumpAttack(self.inst) end, "JumpAttack",
                    DoAction(self.inst, function() return DoJumpAttack(self.inst) end, "jump", true)),

                WhileNode(function() return ShouldRam(self.inst) end, "RecorderRam",
                    RecorderChaseAndRam(self.inst, MAX_CHASE_TIME)),

                ChaseAndAttack(self.inst, 3, 30, nil, nil, true),

                WhileNode(function()
                    return self.inst.components.combat.target ~= nil
                        and self.inst.components.combat:InCooldown()
                end, "Rest", StandStill(self.inst)),

                BrainCommon.PanicTrigger(self.inst),

                WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome",
                    DoAction(self.inst, GoHomeAction, "Go Home", false)),

                FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
                StandStill(self.inst),
            }, 1)
        ),
    }, .25)

    self.bt = BT(self.inst, root)
end

return RecorderMinotaurBrain
