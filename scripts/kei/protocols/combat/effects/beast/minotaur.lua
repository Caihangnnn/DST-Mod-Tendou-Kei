-- 远古守卫者高级协议：攻击触发暗影囚笼和触手。
local MinotaurCommon = require("kei/protocols/combat/effects/beast/_minotaur_common")

local MinotaurEffect = {}

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
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
