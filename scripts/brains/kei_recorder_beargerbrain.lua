require "behaviours/doaction"

local OriginalBrain = require("brains/beargerbrain")
local RecorderBearger = require("kei/recorder_bearger")

local function EatRecorderBeeAction(inst)
    if inst.sg:HasStateTag("busy") and not inst.sg:HasStateTag("wantstoeat") then
        return
    end

    local bee = RecorderBearger.GetNextBee(inst)
    if bee ~= nil then
        return BufferedAction(inst, bee, ACTIONS.EAT)
    end
end

local RecorderBeargerBrain = Class(OriginalBrain, function(self, inst)
    OriginalBrain._ctor(self, inst)
end)

function RecorderBeargerBrain:OnStart()
    OriginalBrain.OnStart(self)

    -- Keep the complete original Bearger tree underneath the recorder-only
    -- food behaviour so the summoned entity retains its normal AI.
    local original_root = self.bt.root
    self.bt = BT(self.inst, PriorityNode({
        DoAction(self.inst, EatRecorderBeeAction, "Eat recorder bee"),
        original_root,
    }, 0.25))
end

return RecorderBeargerBrain
