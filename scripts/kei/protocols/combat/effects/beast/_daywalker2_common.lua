-- 拾荒疯猪协议公共实现：控制免疫、盾牌特效、伤害吸收。

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local DAYWALKER2_SHIELD_FOLLOW_PERIOD = FRAMES

local Daywalker2Common = {}

local function PositionShieldFx(slots)
    local fx = slots._kei_daywalker2_shield_fx
    if fx ~= nil and fx:IsValid() then
        local x, y, z = slots.inst.Transform:GetWorldPosition()
        fx.Transform:SetPosition(x, y + 1.5, z)
        fx.Transform:SetRotation(0)
    end
end

local function EnableShieldFx(slots, inst)
    if slots._kei_daywalker2_shield_fx ~= nil and slots._kei_daywalker2_shield_fx:IsValid() then
        return
    end

    local fx = SpawnPrefab("kei_daywalker2_shield_fx")
    if fx ~= nil then
        slots._kei_daywalker2_shield_fx = fx
        PositionShieldFx(slots)
        slots._kei_daywalker2_shield_follow_task = inst:DoPeriodicTask(DAYWALKER2_SHIELD_FOLLOW_PERIOD, function()
            PositionShieldFx(slots)
        end)
    end
end

local function DisableShieldFx(slots)
    if slots._kei_daywalker2_shield_follow_task ~= nil then
        slots._kei_daywalker2_shield_follow_task:Cancel()
        slots._kei_daywalker2_shield_follow_task = nil
    end
    if slots._kei_daywalker2_shield_fx ~= nil then
        if slots._kei_daywalker2_shield_fx:IsValid() then
            slots._kei_daywalker2_shield_fx:Remove()
        end
        slots._kei_daywalker2_shield_fx = nil
    end
end

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function Daywalker2Common.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "daywalker2")
end

function Daywalker2Common.EnableImmunity(slots, inst, source)
    source = source or "daywalker2"
    slots._kei_daywalker2_sources = slots._kei_daywalker2_sources or {}
    if slots._kei_daywalker2_sources[source] then
        return
    end

    if not BeastCommon.HasAnySource(slots._kei_daywalker2_sources) then
        inst:AddTag("kei_stagger_immune")
        inst:AddTag("kei_control_immune")
        EnableShieldFx(slots, inst)
    end

    slots._kei_daywalker2_sources[source] = true
end

function Daywalker2Common.DisableImmunity(slots, inst, source)
    source = source or "daywalker2"
    local sources = slots._kei_daywalker2_sources
    if sources ~= nil then
        sources[source] = nil
    end

    if BeastCommon.HasAnySource(sources) then
        return
    end

    inst:RemoveTag("kei_stagger_immune")
    inst:RemoveTag("kei_control_immune")
    DisableShieldFx(slots)

    slots._kei_daywalker2_sources = nil
end

function Daywalker2Common.SetAbsorb(inst, amount)
    if inst.components.health ~= nil then
        inst.components.health.externalabsorbmodifiers:SetModifier(inst, amount, "kei_daywalker2")
    end
end

function Daywalker2Common.ClearAbsorb(inst)
    if inst.components.health ~= nil then
        inst.components.health.externalabsorbmodifiers:SetModifier(inst, nil, "kei_daywalker2")
    end
end

return Daywalker2Common
