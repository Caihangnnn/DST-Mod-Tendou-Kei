-- 梦魇疯猪协议：护盾特效 + 硬直/控制免疫。

local DAYWALKER2_SHIELD_FOLLOW_PERIOD = FRAMES

local Daywalker2Effect = {}

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

function Daywalker2Effect.Enable(slots, inst)
    inst:AddTag("kei_stagger_immune")
    inst:AddTag("kei_control_immune")
    EnableShieldFx(slots, inst)
end

function Daywalker2Effect.Disable(slots, inst)
    inst:RemoveTag("kei_stagger_immune")
    inst:RemoveTag("kei_control_immune")
    DisableShieldFx(slots)
end

return Daywalker2Effect
