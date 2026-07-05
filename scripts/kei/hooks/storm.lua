local function HasKeiAntlionStormImmunity(inst)
    local sources = inst ~= nil and inst._kei_antlion_storm_immunity_sources or nil
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

local function ClearKeiStormSlow(inst)
    if inst.components ~= nil and inst.components.locomotor ~= nil then
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "sandstorm")
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "moonstorm")
    end
end

local function PushKeiStormImmunityEvents(inst)
    inst:PushEvent("sandstormlevel", { level = 0 })
    inst:PushEvent("moonstormlevel", { level = 0 })
end

AddComponentPostInit("stormwatcher", function(self)
    local old_UpdateStormLevel = self.UpdateStormLevel
    function self:UpdateStormLevel(...)
        if HasKeiAntlionStormImmunity(self.inst) then
            self.stormlevel = 0
            ClearKeiStormSlow(self.inst)
            PushKeiStormImmunityEvents(self.inst)
            self.laststorm = self.currentstorm
            return
        end
        return old_UpdateStormLevel(self, ...)
    end
end)