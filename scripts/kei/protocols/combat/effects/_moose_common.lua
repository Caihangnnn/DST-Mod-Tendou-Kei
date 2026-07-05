-- 麋鹿鹅协议功能实现

local MooseCommon = {}

local function HasAnySource(sources)
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

function MooseCommon.EnableMoistureImmunity(slots, inst, source)
    source = source or "moose"
    slots._kei_moose_moisture_sources = slots._kei_moose_moisture_sources or {}
    if slots._kei_moose_moisture_sources[source] then
        return
    end

    if inst.components.moistureimmunity == nil then
        inst:AddComponent("moistureimmunity")
    end

    if not HasAnySource(slots._kei_moose_moisture_sources) then
        inst.components.moistureimmunity:AddSource(inst)
    end
    slots._kei_moose_moisture_sources[source] = true
end

function MooseCommon.DisableMoistureImmunity(slots, inst, source)
    source = source or "moose"
    local sources = slots._kei_moose_moisture_sources
    if sources ~= nil then
        sources[source] = nil
    end

    if HasAnySource(sources) then
        return
    end

    if inst.components.moistureimmunity ~= nil then
        inst.components.moistureimmunity:RemoveSource(inst)
    end
    slots._kei_moose_moisture_sources = nil
end

function MooseCommon.GetTornadoSpawnLocation(inst, target)
    local x1, y1, z1 = inst.Transform:GetWorldPosition()
    local x2, y2, z2 = target.Transform:GetWorldPosition()
    return x1 + 0.15 * (x2 - x1), 0, z1 + 0.15 * (z2 - z1)
end

function MooseCommon.TrySpawnTornado(slots, inst, data)
    local target = data ~= nil and data.target or nil
    local now = GetTime()
    if target == nil
        or not target:IsValid()
        or target.components.health == nil
        or target.components.health:IsDead()
        or (inst._kei_moose_tornado_cd_time ~= nil and inst._kei_moose_tornado_cd_time > now)
        or math.random() >= (TUNING.KEI_MOOSE_TORNADO_CHANCE or 0.2)
    then
        return
    end

    inst._kei_moose_tornado_cd_time = now + (TUNING.KEI_MOOSE_TORNADO_COOLDOWN or 0.5)

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