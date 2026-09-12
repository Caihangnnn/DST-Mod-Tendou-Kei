-- Shared rotor survey skill definitions and lookup helpers.

local RotorSurveySkills = {
    SKILLS = {
        enable_drone = 1,
        pilot = 2,
        follow = 256,
        teleport = 512,
        resurrection = 4,
        heal = 8,
        strengthen = 16,
        confinement = 32,
        dead = 64,
        survey = 128,
        -- pending_3 used this bit in older saves. Keep it as an alias so an
        -- old unlock also unlocks the replacement skill.
        collect = 1024,
        -- The second collect recipe is a separate persistent flag because
        -- all 16 bits of the legacy skill mask are already assigned.
        collect_harvest = nil,
        friendly = 2048,
        fishing = 16384,
        nature = 32768,
        pending_1 = 256,
        pending_2 = 512,
        pending_3 = 1024,
        pending_5 = 4096,
        pending_6 = 8192,
    },
    DEFAULT_MASK = 1,
}

local SKILL_BY_RECIPE = {
    kei_rotor_skill_pilot = "pilot",
    kei_rotor_skill_resurrection = "resurrection",
    kei_rotor_skill_heal = "heal",
    kei_rotor_skill_strengthen = "strengthen",
    kei_rotor_skill_confinement = "confinement",
    kei_rotor_skill_dead = "dead",
    kei_rotor_skill_survey = "survey",
    kei_rotor_skill_follow = "follow",
    kei_rotor_skill_teleport = "teleport",
    kei_rotor_skill_collect = "collect",
    kei_rotor_skill_friendly = "friendly",
    kei_rotor_skill_fishing = "fishing",
    kei_rotor_skill_nature = "nature",
    kei_rotor_skill_pending_1 = "pending_1",
    kei_rotor_skill_pending_2 = "pending_2",
    kei_rotor_skill_pending_3 = "pending_3",
}

local function GetNetMask(inst)
    return inst ~= nil
        and inst._kei_rotor_skill_mask ~= nil
        and inst._kei_rotor_skill_mask:value()
        or RotorSurveySkills.DEFAULT_MASK
end

function RotorSurveySkills.GetMask(inst)
    if inst ~= nil and inst.components ~= nil and inst.components["drone/skills"] ~= nil then
        return inst.components["drone/skills"].mask
    end
    return GetNetMask(inst)
end

function RotorSurveySkills.HasSkill(inst, skill)
    if skill == "collect_harvest" then
        local skills = inst ~= nil and inst.components ~= nil and inst.components["drone/skills"] or nil
        if skills ~= nil then
            return skills.collect_harvest_unlocked == true
        end
        return inst ~= nil
            and inst._kei_rotor_collect_harvest ~= nil
            and inst._kei_rotor_collect_harvest:value()
    end
    local bit = RotorSurveySkills.SKILLS[skill]
    return bit ~= nil and (RotorSurveySkills.GetMask(inst) % (bit * 2)) >= bit
end

function RotorSurveySkills.GetSkillLevel(inst, skill)
    if skill == "collect" then
        if RotorSurveySkills.HasSkill(inst, "collect_harvest") then
            return 2
        end
        return RotorSurveySkills.HasSkill(inst, "collect") and 1 or 0
    end
    return RotorSurveySkills.HasSkill(inst, skill) and 1 or 0
end

function RotorSurveySkills.IsSkillRecipe(recname)
    return SKILL_BY_RECIPE[recname] ~= nil
end

function RotorSurveySkills.GetSkillForRecipe(recname)
    return SKILL_BY_RECIPE[recname]
end

return RotorSurveySkills
