-- 装甲熊獾协议：提供独立攻速强化。
local MutatedBeargerEffect = {}
local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local SOURCE = "mutatedbearger"

-- 启用协议效果，并注册该协议提供的持续能力。
function MutatedBeargerEffect.Enable(slots, inst)
    slots._kei_mutatedbearger_sources = slots._kei_mutatedbearger_sources or {}
    if not inst:HasTag("kei_attack_speed_boost") then
        inst:AddTag("kei_attack_speed_boost")
        slots._kei_mutatedbearger_added_tag = true
    end
    BeastCommon.AddSource(slots._kei_mutatedbearger_sources, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function MutatedBeargerEffect.Disable(slots, inst)
    local sources = slots._kei_mutatedbearger_sources
    if sources == nil or not BeastCommon.RemoveSource(sources, SOURCE) then
        if slots._kei_mutatedbearger_added_tag then
            inst:RemoveTag("kei_attack_speed_boost")
        end
        slots._kei_mutatedbearger_added_tag = nil
        slots._kei_mutatedbearger_sources = nil
    end
end

return MutatedBeargerEffect
