local AntlionCommon = {}

local function HasAnySource(sources)
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

local function RefreshStormWatcher(inst)
    if inst.components ~= nil and inst.components.stormwatcher ~= nil then
        inst.components.stormwatcher:UpdateStormLevel()
    end
end

function AntlionCommon.EnableStormImmunity(slots, inst, source)
    source = source or "antlion"
    inst._kei_antlion_storm_immunity_sources = inst._kei_antlion_storm_immunity_sources or {}
    if inst._kei_antlion_storm_immunity_sources[source] then
        RefreshStormWatcher(inst)
        return
    end

    inst._kei_antlion_storm_immunity_sources[source] = true
    RefreshStormWatcher(inst)
end

function AntlionCommon.DisableStormImmunity(slots, inst, source)
    source = source or "antlion"
    local sources = inst._kei_antlion_storm_immunity_sources
    if sources ~= nil then
        sources[source] = nil
        if not HasAnySource(sources) then
            inst._kei_antlion_storm_immunity_sources = nil
        end
    end
    RefreshStormWatcher(inst)
end

function AntlionCommon.HasAdvanced(slots)
    return slots.active_combat ~= nil and slots.active_combat.antlion == true
end

local function IsValidTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and owner.components.combat ~= nil
        and target ~= nil
        and target:IsValid()
        and target.entity:IsVisible()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and target.components.combat ~= nil
        and owner.components.combat:IsValidTarget(target)
end

local function DoSandSpikeDamage(inst, owner, target, damage)
    if IsValidTarget(owner, target)
        and inst:IsValid()
        and target:GetDistanceSqToInst(inst) <= (TUNING.KEI_ANTLION_SANDSPIKE_DAMAGE_RADIUS or 1.1) ^ 2
    then
        target.components.combat:GetAttacked(owner, damage)
    end
end

local function ArmSandSpikeDamage(inst, owner, target, damage)
    inst:DoTaskInTime(2 * FRAMES, DoSandSpikeDamage, owner, target, damage)
end

function AntlionCommon.SpawnSandSpike(slots, inst, pt, target, prefab, damage)
    local spike = SpawnPrefab(prefab or "sandspike_tall")
    if spike == nil then
        return nil
    end

    damage = damage or TUNING.SANDSPIKE.DAMAGE.TALL
    spike.Transform:SetPosition(pt.x, 0, pt.z)
    if spike.components.combat ~= nil then
        spike.components.combat:SetDefaultDamage(0)
        spike.components.combat.playerdamagepercent = 0
    end
    spike:ListenForEvent("animover", function(s)
        if not s._kei_antlion_damage_armed then
            s._kei_antlion_damage_armed = true
            ArmSandSpikeDamage(s, inst, target, damage)
        end
    end)

    return spike
end

function AntlionCommon.SpawnSandSpikeTriangle(slots, inst, center, target)
    local radius = TUNING.KEI_ANTLION_SANDSPIKE_TRIANGLE_RADIUS or 1.6
    local theta = math.random() * TWOPI
    for i = 0, 2 do
        local angle = theta + i * TWOPI / 3
        AntlionCommon.SpawnSandSpike(slots, inst,
            Vector3(center.x + math.cos(angle) * radius, 0, center.z + math.sin(angle) * radius),
            target,
            "sandspike_short",
            TUNING.KEI_ANTLION_SANDSPIKE_SHORT_DAMAGE or TUNING.SANDSPIKE.DAMAGE.SHORT
        )
    end
end

function AntlionCommon.TrySpawnSandSpikes(slots, inst, data)
    local target = data ~= nil and data.target or nil
    local now = GetTime()
    if (slots._kei_antlion_sandspike_ready_time or 0) > now
        or math.random() >= (TUNING.KEI_ANTLION_SANDSPIKE_CHANCE or 0.30)
        or not IsValidTarget(inst, target)
    then
        return
    end

    local center = target:GetPosition()
    if AntlionCommon.SpawnSandSpike(slots, inst, center, target,
        "sandspike_tall",
        TUNING.KEI_ANTLION_SANDSPIKE_TALL_DAMAGE or TUNING.SANDSPIKE.DAMAGE.TALL
    ) == nil then
        return
    end

    slots._kei_antlion_sandspike_ready_time = now + (TUNING.KEI_ANTLION_SANDSPIKE_COOLDOWN or 0.5)
    inst:DoTaskInTime(TUNING.KEI_ANTLION_SANDSPIKE_VERTEX_DELAY or 8 * FRAMES, function()
        if IsValidTarget(inst, target) then
            AntlionCommon.SpawnSandSpikeTriangle(slots, inst, center, target)
        end
    end)
end

return AntlionCommon