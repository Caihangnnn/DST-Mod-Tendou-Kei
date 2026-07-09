-- 远古守卫者初级协议：攻击触发暗影触手。
local MinotaurCommon = require("kei/protocols/combat/effects/beast/_minotaur_common")

local MinotaurBasicEffect = {}

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
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
