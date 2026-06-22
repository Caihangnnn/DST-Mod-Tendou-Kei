-- 麋鹿鹅协议：带电 buff + 潮湿免疫。

local MOOSE_ELECTRIC_BUFF_NAME = "kei_moose_electricattack"

local MooseEffect = {}

function MooseEffect.Enable(slots, inst)
    if not inst:HasDebuff(MOOSE_ELECTRIC_BUFF_NAME) then
        inst:AddDebuff(MOOSE_ELECTRIC_BUFF_NAME, "buff_electricattack")
    end

    if not inst:HasTag("wet") then
        if inst.components.moistureimmunity == nil then
            inst:AddComponent("moistureimmunity")
        end
        inst.components.moistureimmunity:AddSource(inst)
    end
end

function MooseEffect.Disable(slots, inst)
    inst:RemoveDebuff(MOOSE_ELECTRIC_BUFF_NAME)

    if inst.components.moistureimmunity ~= nil then
        inst.components.moistureimmunity:RemoveSource(inst)
    end
end

return MooseEffect
