local MinotaurCommon = require("kei/protocols/combat/effects/_minotaur_common")

local MinotaurBasicEffect = {}

function MinotaurBasicEffect.OnHitOther(slots, inst, data)
    if MinotaurCommon.HasAdvanced(slots) then
        return
    end
    if (slots._kei_minotaur_basic_shadow_prison_ready_time or 0) > GetTime()
        or math.random() >= (TUNING.KEI_MINOTAUR_SHADOW_PRISON_CHANCE or 0.20)
    then
        return
    end

    MinotaurCommon.SpawnShadowPrison(inst, data and data.target, data and data.weapon)
    slots._kei_minotaur_basic_shadow_prison_ready_time = GetTime() + (TUNING.KEI_MINOTAUR_TENTACLE_COOLDOWN or 0.5)
end

return MinotaurBasicEffect