require("behaviours/chaseandattack")
require("behaviours/follow")
require("behaviours/wander")
require("behaviours/standstill")

local RecorderPigEliteBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function HasSign(inst)
    return inst.kei_recorder_propsign ~= nil
        and inst.kei_recorder_propsign:IsValid()
end

local function GetJunk(inst)
    local junk = inst.kei_recorder_junk
    return junk ~= nil and junk:IsValid() and junk or nil
end

function RecorderPigEliteBrain:OnStart()
    local root = PriorityNode({
        WhileNode(function() return self.inst.sg:HasStateTag("jumping") end, "Spawn or jump",
            StandStill(self.inst)),

        WhileNode(function()
            return not HasSign(self.inst) and GetJunk(self.inst) ~= nil
        end, "Return to junk pile",
            Follow(self.inst, GetJunk, 0, 3.5, 6)),

        ChaseAndAttack(self.inst),
        Wander(self.inst),
    }, .25)

    self.bt = BT(self.inst, root)
end

return RecorderPigEliteBrain
