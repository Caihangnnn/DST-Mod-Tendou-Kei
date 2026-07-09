-- 熊獾协议公共实现：攻击命中时造成范围震击。

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local BeargerCommon = {}

local AREA_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }
local AREA_MUST_TAGS = { "_combat" }

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function BeargerCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "bearger")
end

-- 对命中目标周围的合法敌人造成范围伤害。
function BeargerCommon.DoAreaDamage(slots, inst, data, multiplier)
    if slots._doing_bearger_aoe then
        return
    end

    local target = data ~= nil and data.target or nil
    if target == nil or target.components == nil or target.components.combat == nil then
        return
    end

    slots._doing_bearger_aoe = true
    local x, y, z = target.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.KEI_BEARGER_AOE_RADIUS or 3, AREA_MUST_TAGS, AREA_EXCLUDE_TAGS)
    for _, ent in ipairs(ents) do
        if ent ~= target
            and ent ~= inst
            and ent.components.combat ~= nil
            and inst.components.combat ~= nil
            and inst.components.combat:IsValidTarget(ent)
        then
            local damage = inst.components.combat:CalcDamage(ent, data.weapon, multiplier or 1)
            ent.components.combat:GetAttacked(inst, damage, data.weapon)
        end
    end
    slots._doing_bearger_aoe = false
end

return BeargerCommon
