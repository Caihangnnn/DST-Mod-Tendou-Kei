require("bufferedaction")
local old_BufferedAction_Do = BufferedAction.Do

function BufferedAction:Do(...)
    if self.target ~= nil
        and self.invobject ~= nil
        and self.target:HasTag("kei_virtual_equipment")
    then
        self:Fail()
        return false
    end

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

-- Keep the vanilla freezable component intact and block only the Freeze call
-- while the Deerclops protocol's immunity tag is active.
AddComponentPostInit("freezable", function(self)
    local old_Freeze = self.Freeze

    function self:Freeze(...)
        if self.inst:HasTag("kei_nofreezing") then
            return
        end
        if old_Freeze ~= nil then
            return old_Freeze(self, ...)
        end
    end
end)

