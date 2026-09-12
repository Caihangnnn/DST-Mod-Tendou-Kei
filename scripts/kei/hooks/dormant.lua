require("bufferedaction")
local DeerclopsCommon = require("kei/protocols/combat/effects/beast/_deerclops_common")
local DragonflyCommon = require("kei/protocols/combat/effects/beast/_dragonfly_common")
local old_BufferedAction_Do = BufferedAction.Do

local function HasKeiDeerclopsFreezeImmunity(inst)
    local slots = inst ~= nil
        and inst.components ~= nil
        and inst.components.kei_protocolslots
        or nil
    if slots ~= nil and slots.HasFreezeImmunity ~= nil then
        return slots:HasFreezeImmunity()
    end
    return DeerclopsCommon.HasFreezeImmunity(slots)
end

local function HasKeiDragonflyOverheatImmunity(inst)
    local slots = inst ~= nil
        and inst.components ~= nil
        and inst.components.kei_protocolslots
        or nil
    if slots ~= nil and slots.HasOverheatImmunity ~= nil then
        return slots:HasOverheatImmunity()
    end
    return DragonflyCommon.HasOverheatImmunity(slots)
end

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
    local old_DoDelta = self.DoDelta

    function self:SetTemperature(value, ...)
        if type(value) == "number" and HasKeiDragonflyOverheatImmunity(self.inst) then
            value = math.min(value, TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE)
        end
        if type(value) == "number" and HasKeiDeerclopsFreezeImmunity(self.inst) then
            local safe_temperature = DeerclopsCommon.GetSafeTemperature(self.inst)
            if safe_temperature ~= nil then
                value = math.max(value, safe_temperature)
            end
        end

        return old_SetTemperature(self, value, ...)
    end

    -- DoDelta normally delegates to SetTemperature, but keeping the guard at
    -- this entry point also covers mods which replace or cache SetTemperature.
    function self:DoDelta(delta, ...)
        if type(delta) == "number" and HasKeiDeerclopsFreezeImmunity(self.inst) then
            local safe_temperature = DeerclopsCommon.GetSafeTemperature(self.inst)
            if safe_temperature ~= nil then
                local current = self:GetCurrent()
                if current + delta < safe_temperature then
                    delta = safe_temperature - current
                end
            end
        end
        return old_DoDelta(self, delta, ...)
    end
end)

-- Keep the vanilla freezable component intact and block only the Freeze call
-- while the Deerclops protocol still provides freeze immunity.
AddComponentPostInit("freezable", function(self)
    local old_Freeze = self.Freeze
    local old_AddColdness = self.AddColdness

    function self:Freeze(...)
        if HasKeiDeerclopsFreezeImmunity(self.inst) then
            -- A direct Freeze call does not pass through AddColdness. Clear any
            -- residual coldness as well, otherwise the frozen tint can remain
            -- even though the actual freeze was blocked.
            self.coldness = 0
            if self.UpdateTint ~= nil then
                self:UpdateTint()
            end
            return
        end
        if old_Freeze ~= nil then
            return old_Freeze(self, ...)
        end
    end

    function self:AddColdness(coldness, ...)
        if HasKeiDeerclopsFreezeImmunity(self.inst) then
            self.coldness = 0
            if self.UpdateTint ~= nil then
                self:UpdateTint()
            end
            return
        end
        if old_AddColdness ~= nil then
            return old_AddColdness(self, coldness, ...)
        end
    end
end)

