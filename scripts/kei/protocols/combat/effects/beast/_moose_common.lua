-- 麋鹿鹅协议公共实现：潮湿免疫与攻击触发旋风。

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local MooseCommon = {}

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function MooseCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "moose")
end

-- 添加潮湿免疫来源。
function MooseCommon.EnableMoistureImmunity(slots, inst, source)
    source = source or "moose"
    slots._kei_moose_moisture_sources = slots._kei_moose_moisture_sources or {}
    if slots._kei_moose_moisture_sources[source] then
        return
    end

    if inst.components.moistureimmunity == nil then
        inst:AddComponent("moistureimmunity")
    end

    if not BeastCommon.HasAnySource(slots._kei_moose_moisture_sources) then
        inst.components.moistureimmunity:AddSource(inst)
    end
    slots._kei_moose_moisture_sources[source] = true
end

-- 移除潮湿免疫来源。
function MooseCommon.DisableMoistureImmunity(slots, inst, source)
    source = source or "moose"
    local sources = slots._kei_moose_moisture_sources
    if sources ~= nil then
        sources[source] = nil
    end

    if BeastCommon.HasAnySource(sources) then
        return
    end

    if inst.components.moistureimmunity ~= nil then
        inst.components.moistureimmunity:RemoveSource(inst)
    end
    slots._kei_moose_moisture_sources = nil
end

-- 计算旋风生成位置，使其出现在攻击者到目标之间。
function MooseCommon.GetTornadoSpawnLocation(inst, target)
    local x1, y1, z1 = inst.Transform:GetWorldPosition()
    local x2, y2, z2 = target.Transform:GetWorldPosition()
    return x1 + 0.15 * (x2 - x1), 0, z1 + 0.15 * (z2 - z1)
end

-- 尝试在命中时生成旋风，并写入触发冷却。
function MooseCommon.TrySpawnTornado(slots, inst, data)
    local target = data ~= nil and data.target or nil
    if not BeastCommon.IsVisibleLivingTarget(target)
        or not BeastCommon.CooldownReady(inst, "_kei_moose_tornado_cd_time")
        or math.random() >= (TUNING.KEI_MOOSE_TORNADO_CHANCE or 0.2)
    then
        return
    end

    BeastCommon.StartCooldown(inst, "_kei_moose_tornado_cd_time", TUNING.KEI_MOOSE_TORNADO_COOLDOWN or 0.5)

    local tornado = SpawnPrefab("kei_moose_tornado")
    if tornado == nil then
        return
    end

    tornado.WINDSTAFF_CASTER = inst
    tornado.WINDSTAFF_CASTER_ISPLAYER = inst:HasTag("player")
    tornado.Transform:SetPosition(MooseCommon.GetTornadoSpawnLocation(inst, target))
    if tornado.components.knownlocations ~= nil then
        tornado.components.knownlocations:RememberLocation("target", target:GetPosition())
    end
    if tornado.WINDSTAFF_CASTER_ISPLAYER then
        tornado.overridepkname = inst:GetDisplayName()
        tornado.overridepkpet = true
    end
    tornado.KEI_DAMAGE_PER_HIT = TUNING.KEI_MOOSE_TORNADO_DAMAGE or 20
    tornado.KEI_MAX_HEALTH_DAMAGE_PERCENT = TUNING.KEI_MOOSE_TORNADO_MAX_HEALTH_PERCENT or 0.0005
end

return MooseCommon
