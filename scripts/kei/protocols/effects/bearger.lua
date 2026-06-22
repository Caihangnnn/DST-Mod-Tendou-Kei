-- 熊獾协议：攻击命中时触发 AOE 衰减伤害。

local AREA_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }
local AREA_MUST_TAGS = { "_combat" }

local BeargerEffect = {}

function BeargerEffect.OnHitOther(slots, inst, data)
    if slots._doing_aoe then
        return
    end
    local target = data and data.target
    if target == nil or target.components == nil or target.components.combat == nil then
        return
    end

    slots._doing_aoe = true
    local x, y, z = target.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 3, AREA_MUST_TAGS, AREA_EXCLUDE_TAGS)
    for _, ent in ipairs(ents) do
        if ent ~= target
            and ent ~= inst
            and ent.components.combat ~= nil
            and inst.components.combat ~= nil
            and inst.components.combat:IsValidTarget(ent)
        then
            local damage = inst.components.combat:CalcDamage(ent, data.weapon, 0.35)
            ent.components.combat:GetAttacked(inst, damage, data.weapon)
        end
    end
    slots._doing_aoe = false
end

return BeargerEffect
