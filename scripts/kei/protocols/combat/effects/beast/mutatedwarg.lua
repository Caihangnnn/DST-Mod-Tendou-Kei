-- 附身座狼协议：按 R 触发喷火技能，冷却 10 秒。

local MutatedwargEffect = {}

-- 启用协议效果，并注册该协议提供的持续能力。
function MutatedwargEffect.Enable(slots, inst)
    inst:AddTag("kei_mutatedwarg")
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function MutatedwargEffect.Disable(slots, inst)
    inst:RemoveTag("kei_mutatedwarg")
end

return MutatedwargEffect
