-- Global experience hooks for sleep and nearby creature deaths.

local function IsExperienceTarget(inst)
    return inst ~= nil
        and inst:IsValid()
        and not inst:HasTag("player")
        and inst.components ~= nil
        and inst.components.health ~= nil
        and inst.components.combat ~= nil
        and (inst.components.locomotor ~= nil
            or inst:HasTag("monster")
            or inst:HasTag("animal"))
end

local function AwardNearbyCombatExperience(victim)
    if not IsExperienceTarget(victim) then
        return
    end

    local max_health = victim.components.health.maxhealth or 0
    if max_health <= 0 then
        return
    end

    local radius = TUNING.KEI_EXPERIENCE_COMBAT_RADIUS or 24
    local radius_sq = radius * radius
    for _, player in ipairs(AllPlayers or {}) do
        if player ~= nil
            and player:IsValid()
            and player:HasTag("kei")
            and not player:HasTag("playerghost")
            and player:GetDistanceSqToInst(victim) <= radius_sq
            and player.components ~= nil
            and player.components.kei_experience ~= nil
        then
            player.components.kei_experience:AddCombatExperience(victim.prefab, max_health)
        end
    end
end

AddComponentPostInit("health", function(self)
    if not TheWorld.ismastersim then
        return
    end

    self.inst:ListenForEvent("death", function(inst)
        AwardNearbyCombatExperience(inst)
    end)
end)

AddComponentPostInit("sleepingbaguser", function(self)
    if not TheWorld.ismastersim then
        return
    end

    local old_DoSleep = self.DoSleep
    function self:DoSleep(bed, ...)
        local result = old_DoSleep(self, bed, ...)
        local experience = self.inst.components ~= nil and self.inst.components.kei_experience or nil
        if experience ~= nil and bed ~= nil then
            experience:AddSleepExperience()
        end
        return result
    end
end)
