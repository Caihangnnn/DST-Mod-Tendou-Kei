require("bufferedaction")
local old_BufferedAction_Do = BufferedAction.Do

function BufferedAction:Do(...)
    if self.doer ~= nil
        and self.doer:HasTag("kei_dormant")
        and self.action ~= ACTIONS.KEI_WAKE
    then
        self:Fail()
        return false, "KEI_DORMANT"
    end

    return old_BufferedAction_Do(self, ...)
end

AddComponentPostInit("temperature", function(self)
    local old_SetTemperature = self.SetTemperature

    function self:SetTemperature(value, ...)
        if self.inst:HasTag("kei_nooverheat") then
            value = math.min(value, TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE)
        end
        if self.inst:HasTag("kei_nofreezing") then
            value = math.max(value, TUNING.KEI_DEERCLOPS_MIN_TEMPERATURE)
        end

        return old_SetTemperature(self, value, ...)
    end
end)

