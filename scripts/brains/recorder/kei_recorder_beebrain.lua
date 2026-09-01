require "behaviours/chaseandattack"

local RecorderBeeBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function GetRecorderBearger(inst)
    local bearger = inst.kei_recorder_bearger
    return bearger ~= nil and bearger:IsValid() and bearger or nil
end

function RecorderBeeBrain:OnStart()
    local root = PriorityNode({
        ChaseAndAttack(self.inst, nil, nil, nil, GetRecorderBearger),
        StandStill(self.inst),
    }, 1)

    self.bt = BT(self.inst, root)
end

return RecorderBeeBrain
