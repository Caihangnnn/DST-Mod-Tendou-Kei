-- 熊獾协议功能实现

local BeargerCommon = {}

local AREA_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }
local AREA_MUST_TAGS = { "_combat" }

function BeargerCommon.HasAdvanced(slots)
    return slots.active_combat ~= nil and slots.active_combat.bearger == true
end

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