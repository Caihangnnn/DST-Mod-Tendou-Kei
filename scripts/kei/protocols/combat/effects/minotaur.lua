local MinotaurCommon = require("kei/protocols/combat/effects/_minotaur_common")

local MinotaurEffect = {}

function MinotaurEffect.OnHitOther(slots, inst, data)
    local target = data and data.target
    local weapon = data and data.weapon
    local now = GetTime()

    if (slots._kei_minotaur_tentacle_ready_time or 0) <= now
        and math.random() < (TUNING.KEI_MINOTAUR_TENTACLE_CHANCE or 0.30)
        and MinotaurCommon.SpawnMinotaurTentacle(inst, target)
    then
        slots._kei_minotaur_tentacle_ready_time = now + (TUNING.KEI_MINOTAUR_TENTACLE_COOLDOWN or 0.5)
    end
    if math.random() < (TUNING.KEI_MINOTAUR_SHADOW_PRISON_CHANCE or 0.15) then
        MinotaurCommon.SpawnShadowPrison(inst, target, weapon)
    end
end

return MinotaurEffect