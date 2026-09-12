-- 旋翼调查仪技能解锁状态。
-- 解锁进度属于玩家，不属于控制器物品；更换控制器后仍然保留。
local RotorSurveySkills = require("kei/drone/skills")

local KeiRotorSkills = Class(function(self, inst)
    self.inst = inst
    self.mask = RotorSurveySkills.DEFAULT_MASK
    self.collect_harvest_unlocked = false
    self.survey_cooldowns = {}
    self:SyncNetValues()
end)

function KeiRotorSkills:SyncNetValues()
    if self.inst._kei_rotor_skill_mask ~= nil then
        self.inst._kei_rotor_skill_mask:set(self.mask)
    end
    if self.inst._kei_rotor_collect_harvest ~= nil then
        self.inst._kei_rotor_collect_harvest:set(self.collect_harvest_unlocked == true)
    end
end

function KeiRotorSkills:HasSkill(skill)
    return RotorSurveySkills.HasSkill(self.inst, skill)
end

function KeiRotorSkills:UnlockSkill(skill)
    if skill == "collect_harvest" then
        if not self:HasSkill("collect") then
            return false, "KEI_ROTOR_SKILL_INVALID"
        end
        if self.collect_harvest_unlocked then
            return false, "KEI_ROTOR_SKILL_ALREADY_UNLOCKED"
        end

        self.collect_harvest_unlocked = true
        self:SyncNetValues()
        self.inst:PushEvent("kei_rotor_skills_changed", { skill = skill })
        return true
    end

    local bit = RotorSurveySkills.SKILLS[skill]
    if bit == nil then
        return false, "KEI_ROTOR_SKILL_INVALID"
    end
    if self:HasSkill(skill) then
        return false, "KEI_ROTOR_SKILL_ALREADY_UNLOCKED"
    end

    self.mask = self.mask + bit
    self:SyncNetValues()
    self.inst:PushEvent("kei_rotor_skills_changed", { skill = skill })
    return true
end

function KeiRotorSkills:GetSurveyCooldownRemaining(protocol)
    if protocol == nil then
        return 0
    end

    local expires_at = self.survey_cooldowns[protocol]
    if expires_at == nil then
        return 0
    end

    local remaining = expires_at - GetTime()
    if remaining <= 0 then
        self.survey_cooldowns[protocol] = nil
        return 0
    end
    return remaining
end

function KeiRotorSkills:CanSurvey(protocol)
    return self:GetSurveyCooldownRemaining(protocol) <= 0
end

function KeiRotorSkills:StartSurveyCooldown(protocol, duration)
    if protocol == nil then
        return false
    end

    duration = math.max(0, tonumber(duration) or 0)
    if duration <= 0 then
        self.survey_cooldowns[protocol] = nil
    else
        self.survey_cooldowns[protocol] = GetTime() + duration
    end
    return true
end

function KeiRotorSkills:OnSave()
    local survey_cooldowns = {}
    for protocol in pairs(self.survey_cooldowns) do
        local remaining = self:GetSurveyCooldownRemaining(protocol)
        if remaining > 0 then
            survey_cooldowns[protocol] = remaining
        end
    end

    return {
        mask = self.mask,
        collect_harvest_unlocked = self.collect_harvest_unlocked == true or nil,
        survey_cooldowns = survey_cooldowns,
    }
end

function KeiRotorSkills:OnLoad(data)
    local mask = data ~= nil and tonumber(data.mask) or nil
    self.mask = math.max(
        RotorSurveySkills.DEFAULT_MASK,
        math.min(65535, math.floor(mask or RotorSurveySkills.DEFAULT_MASK))
    )
    -- The first skill is always available, including old saves.
    self.mask = self.mask - (self.mask % 2) + 1
    self.collect_harvest_unlocked = data ~= nil
        and data.collect_harvest_unlocked == true
        and (self.mask % (RotorSurveySkills.SKILLS.collect * 2)) >= RotorSurveySkills.SKILLS.collect
        or false

    self.survey_cooldowns = {}
    for protocol, remaining in pairs(data ~= nil and data.survey_cooldowns or {}) do
        remaining = tonumber(remaining) or 0
        if remaining > 0 then
            self.survey_cooldowns[protocol] = GetTime() + remaining
        end
    end
    self:SyncNetValues()
end

function KeiRotorSkills:OnRemoveFromEntity()
    self.inst._kei_rotor_skill_mask = nil
end

return KeiRotorSkills
