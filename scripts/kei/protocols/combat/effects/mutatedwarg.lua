-- 附身座狼协议：按 R 触发喷火技能，冷却 10 秒。

local MutatedwargEffect = {}

function MutatedwargEffect.Enable(slots, inst)
    inst:AddTag("kei_mutatedwarg")
end

function MutatedwargEffect.Disable(slots, inst)
    inst:RemoveTag("kei_mutatedwarg")
end

return MutatedwargEffect