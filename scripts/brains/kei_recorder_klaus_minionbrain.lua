require("behaviours/chaseandattack")

local RecorderKlausMinionBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function RecorderKlausMinionBrain:OnStart()
    self.bt = BT(self.inst, PriorityNode({
        ChaseAndAttack(self.inst),
    }, .25))
end

return RecorderKlausMinionBrain
