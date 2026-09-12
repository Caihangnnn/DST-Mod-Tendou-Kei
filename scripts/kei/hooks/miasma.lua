local function HasKeiAntlionMiasmaImmunity(inst)
    local sources = inst ~= nil and inst._kei_antlion_miasma_immunity_sources or nil
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

AddComponentPostInit("miasmawatcher", function(self)
    local old_UpdateMiasmaWalkSpeed = self.UpdateMiasmaWalkSpeed
    function self:UpdateMiasmaWalkSpeed(...)
        if HasKeiAntlionMiasmaImmunity(self.inst) then
            if self.inst.components ~= nil and self.inst.components.locomotor ~= nil then
                self.inst.components.locomotor:RemoveExternalSpeedMultiplier(self.inst, "miasma")
            end
            return
        end
        return old_UpdateMiasmaWalkSpeed(self, ...)
    end
end)
