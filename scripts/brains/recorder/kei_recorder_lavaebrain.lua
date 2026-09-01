require("behaviours/chaseandattack")

local RecorderLavaeBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

local function FindTarget(inst)
    local mother = inst.components.entitytracker:GetEntity("mother")
    if mother == nil then
        return nil
    end

    if mother.components.grouptargeter ~= nil then
        local targets = {}
        for target in pairs(mother.components.grouptargeter:GetTargets()) do
            table.insert(targets, target)
        end
        return GetClosest(inst, targets)
    end
end

function RecorderLavaeBrain:OnStart()
    local root = PriorityNode({
        ChaseAndAttack(self.inst, nil, nil, nil, FindTarget),
        StandStill(self.inst),
    }, 1)

    self.bt = BT(self.inst, root)
end

return RecorderLavaeBrain
