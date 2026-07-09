-- 装甲熊獾协议：提供独立攻速强化。
local MutatedBeargerEffect = {}

-- 启用协议效果，并注册该协议提供的持续能力。
function MutatedBeargerEffect.Enable(slots, inst)
    inst:AddTag("kei_attack_speed_boost")
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function MutatedBeargerEffect.Disable(slots, inst)
    inst:RemoveTag("kei_attack_speed_boost")
end

return MutatedBeargerEffect
