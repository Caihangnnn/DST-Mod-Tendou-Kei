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

local function GetNetMask(inst)
    return inst ~= nil
        and inst._kei_rotor_skill_mask ~= nil
        and inst._kei_rotor_skill_mask:value()
        or RotorSurveySkills.DEFAULT_MASK
end

function RotorSurveySkills.GetMask(inst)
    if inst ~= nil and inst.components ~= nil and inst.components.kei_rotor_skills ~= nil then
        return inst.components.kei_rotor_skills.mask
    end
    return GetNetMask(inst)
end

function RotorSurveySkills.HasSkill(inst, skill)
    local bit = RotorSurveySkills.SKILLS[skill]
    return bit ~= nil and (RotorSurveySkills.GetMask(inst) % (bit * 2)) >= bit
end

function RotorSurveySkills.IsSkillRecipe(recname)
    return recname == "kei_rotor_skill_pilot"
        or recname == "kei_rotor_skill_resurrection"
        or recname == "kei_rotor_skill_heal"
        or recname == "kei_rotor_skill_strengthen"
        or recname == "kei_rotor_skill_confinement"
        or recname == "kei_rotor_skill_dead"
        or recname == "kei_rotor_skill_survey"
        or recname == "kei_rotor_skill_follow"
        or recname == "kei_rotor_skill_teleport"
        or recname == "kei_rotor_skill_collect"
        or recname == "kei_rotor_skill_friendly"
        or recname == "kei_rotor_skill_fishing"
        or recname == "kei_rotor_skill_nature"
        or recname == "kei_rotor_skill_pending_1"
        or recname == "kei_rotor_skill_pending_2"
        or recname == "kei_rotor_skill_pending_3"
end

function RotorSurveySkills.GetSkillForRecipe(recname)
    local skills = {
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
    return skills[recname]
end

return RotorSurveySkills
