require "behaviours/runaway"
require "behaviours/wander"
require "behaviours/findfarmplant"

local BrainCommon = require("brains/braincommon")
local RecorderBoss = require("kei/recorder/boss")

local MAX_WANDER_DIST = 15
local GO_HOME_DIST = 30
local SEE_DIST = 20
local RUN_AWAY_DIST = 20
local STOP_RUN_AWAY_DIST = 5
local MAX_RECORDER_DIST = 20
local RECORDER_EDGE_BUFFER = 1.5

local function CanSpawnChild(inst)
    return inst:GetTimeAlive() > 5
        and inst:NumFruitFliesToSpawn() > 0
        and inst.components.combat:HasTarget() or inst.planttarget or inst.soiltarget
end

local function GetFollowPos(inst)
    if inst.components.follower and inst.components.follower:GetLeader() then
        return inst.components.follower:GetLeader():GetPosition()
    elseif inst.components.knownlocations then
        return inst.components.knownlocations:GetLocation("home") or inst:GetPosition()
    end
    return inst:GetPosition()
end

local function GetLeader(inst)
    if inst.components.leader then
        return inst
    elseif inst.components.follower then
        return inst.components.follower:GetLeader()
    end
end

local function GoHomeAction(inst)
    if inst.components.combat.target ~= nil then
        return
    end
    local homePos = GetFollowPos(inst)
    return homePos ~= nil
        and BufferedAction(inst, nil, ACTIONS.WALKTO, nil, homePos, nil, .2)
        or nil
end

local function ShouldGoHome(inst)
    if inst.components.combat:HasTarget() then
        return false
    end
    local homePos = GetFollowPos(inst)
    return homePos ~= nil and inst:GetDistanceSqToPoint(homePos:Get()) > GO_HOME_DIST * GO_HOME_DIST
end

local function IsNearFollowPos(inst, soil)
    local followpos = GetFollowPos(inst)
    local soilpos = soil:GetPosition()
    return distsq(followpos.x, followpos.z, soilpos.x, soilpos.z) < SEE_DIST * SEE_DIST
end

local SOIL_MUSTTAGS = { "soil" }
local SOIL_CANTTAGS = { "NOCLICK" }

local function SowWeedsAction(inst)
    return inst.soiltarget
        and BufferedAction(inst, inst.soiltarget, ACTIONS.PLANTWEED, nil, nil, nil, 0.1)
        or nil
end

local function ShouldSowWeeds(inst)
    inst.soiltarget = FindEntity(inst, SEE_DIST, function(soil)
        local leader = GetLeader(inst)
        return IsNearFollowPos(inst, soil) and (leader == nil or not leader:IsTargetedByOther(inst, soil))
    end, SOIL_MUSTTAGS, SOIL_CANTTAGS)
    return inst.soiltarget ~= nil
end

local function ShouldTargetPlant(inst, plant)
    local leader = GetLeader(inst)
    return leader == nil or not leader:IsTargetedByOther(inst, plant)
end

local function GetNearestArenaPlayer(inst)
    local source = inst.kei_recorder_source
    local nearest
    local nearest_dist_sq = RUN_AWAY_DIST * RUN_AWAY_DIST
    local x, _, z = inst.Transform:GetWorldPosition()

    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        local px, _, pz = player.Transform:GetWorldPosition()
        local distance_sq = distsq(x, z, px, pz)
        if distance_sq <= nearest_dist_sq then
            nearest = player
            nearest_dist_sq = distance_sq
        end
    end
    return nearest
end

local function IsWithinRecorderFleeBoundary(inst)
    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        return true
    end

    return inst:IsNear(source, MAX_RECORDER_DIST - RECORDER_EDGE_BUFFER)
end

local function GetRecorderSafePoint(inst)
    local source = inst.kei_recorder_source
    return source ~= nil and source:IsValid() and source:GetPosition() or nil
end

local function ShouldKeepAway(inst)
    local within_boundary = IsWithinRecorderFleeBoundary(inst)
    if not within_boundary and inst.components.locomotor ~= nil then
        inst.components.locomotor:Stop()
    end

    return not inst.sg:HasStateTag("busy")
        and not inst.sg:HasStateTag("stunned")
        and within_boundary
end

local RecorderLordfruitflyBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function RecorderLordfruitflyBrain:OnStart()
    local brain = {
        BrainCommon.PanicTrigger(self.inst),
        BrainCommon.ElectricFencePanicTrigger(self.inst),
        MinPeriod(self.inst, TUNING.LORDFRUITFLY_SUMMONPERIOD, false,
            IfNode(function() return CanSpawnChild(self.inst) end, "needs follower",
                ActionNode(function()
                    self.inst.sg:GoToState("buzz")
                    return SUCCESS
                end, "Summon Mini Fruit Flies"))),
        WhileNode(function() return ShouldKeepAway(self.inst) end, "Keep Away From Arena Players",
            RunAway(
                self.inst,
                { getfn = GetNearestArenaPlayer },
                RUN_AWAY_DIST,
                STOP_RUN_AWAY_DIST,
                nil,
                nil,
                nil,
                nil,
                GetRecorderSafePoint
            )),
        WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome",
            DoAction(self.inst, GoHomeAction, "Go Home", true)),
        FindFarmPlant(self.inst, ACTIONS.ATTACKPLANT, false, GetFollowPos, ShouldTargetPlant),
        WhileNode(function() return ShouldSowWeeds(self.inst) end, "Should Sow Weeds",
            DoAction(self.inst, SowWeedsAction, "Sow Weeds", true)),
        Wander(self.inst, GetFollowPos, MAX_WANDER_DIST),
    }

    self.bt = BT(self.inst, PriorityNode(brain, .25))
end

return RecorderLordfruitflyBrain
