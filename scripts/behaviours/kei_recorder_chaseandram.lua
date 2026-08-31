local RecorderChaseAndRam = Class(BehaviourNode, function(self, inst, max_chase_time)
    BehaviourNode._ctor(self, "RecorderChaseAndRam")
    self.inst = inst
    self.max_chase_time = max_chase_time
end)

function RecorderChaseAndRam:__tostring()
    return string.format("target %s", tostring(self.inst.components.combat.target))
end

function RecorderChaseAndRam:Visit()
    local combat = self.inst.components.combat

    if self.status == READY then
        combat:ValidateTarget()
        local target = combat.target
        if target ~= nil and target.entity:IsValid() then
            combat:BattleCry()
            self.startruntime = GetTime()
            self.status = RUNNING
            self.inst.sg:GoToState("run_start")
        else
            self.status = FAILED
        end
    end

    if self.status == RUNNING then
        local target = combat.target
        if target == nil or not target.entity:IsValid() then
            combat:SetTarget(nil)
            self.inst.components.locomotor:Stop()
            if self.inst.sg:HasStateTag("recorder_ram") then
                self.inst.sg:GoToState("idle")
            end
            self.status = FAILED
        elseif target.components.health ~= nil and target.components.health:IsDead() then
            combat:SetTarget(nil)
            self.inst.components.locomotor:Stop()
            if self.inst.sg:HasStateTag("recorder_ram") then
                self.inst.sg:GoToState("idle")
            end
            self.status = SUCCESS
        elseif not self.inst.sg:HasStateTag("recorder_ram") then
            self.status = SUCCESS
        elseif self.max_chase_time ~= nil and GetTime() - self.startruntime > self.max_chase_time + 2 then
            -- The state has its own normal timeout. This is only a recovery
            -- guard in case an interrupted animation leaves it running.
            self.inst.sg:GoToState("run_stop")
            self.status = SUCCESS
        else
            self:Sleep(.1)
        end
    end
end

return RecorderChaseAndRam
