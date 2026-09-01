local RecorderDaywalker2 = {}

local JUNK_PREFAB = "kei_recorder_junk_pile_big"
local ELITE_PREFABS = {
    "kei_recorder_pigelitefighter1",
    "kei_recorder_pigelitefighter2",
    "kei_recorder_pigelitefighter3",
    "kei_recorder_pigelitefighter4",
}

local function IsValid(inst)
    return inst ~= nil and inst:IsValid() and not inst:IsInLimbo()
end

local function RegisterSupport(owner, entity)
    if owner == nil or entity == nil then
        return
    end
    owner.kei_target_support_entities = owner.kei_target_support_entities or {}
    table.insert(owner.kei_target_support_entities, entity)
end

local function FindJunkPosition(target)
    local center = target:GetPosition()
    local distance = 8
    for _ = 1, 16 do
        local angle = math.random() * TWOPI
        local offset = FindWalkableOffset(center, angle, distance, 8, false, true)
        if offset ~= nil then
            return center.x + offset.x, center.z + offset.z
        end
    end
    return center.x + distance, center.z
end

local function SpawnElite(target, junk, variation, support_owner)
    local elite = SpawnPrefab(ELITE_PREFABS[variation])
    if elite == nil then
        return
    end

    local x, _, z = junk.Transform:GetWorldPosition()
    local angle = (variation - 1) * (TWOPI / 4) + math.random() * 0.2
    elite.Transform:SetPosition(x + math.cos(angle) * 4.5, 0, z + math.sin(angle) * 4.5)
    elite.kei_recorder_daywalker = target
    elite.kei_recorder_source = target.kei_recorder_source
    elite.kei_recorder_junk = junk
    elite.kei_recorder_support_owner = support_owner

    if elite.components.follower ~= nil then
        elite.components.follower:SetLeader(target)
    end

    if elite.EquipRecorderSign ~= nil then
        elite:EquipRecorderSign(junk)
    end

    RegisterSupport(support_owner, elite)
    table.insert(target.kei_recorder_pigelitefighters, elite)

    if elite.sg ~= nil then
        elite.sg:GoToState("spawnin", { dest = target:GetPosition() })
    end
end

function RecorderDaywalker2.Apply(target, support_owner)
    if not IsValid(target) then
        return false
    end

    RecorderDaywalker2.Remove(target)
    target.kei_recorder_pigelitefighters = {}

    local junk = SpawnPrefab(JUNK_PREFAB)
    if junk == nil then
        return false
    end

    local x, z = FindJunkPosition(target)
    junk.persists = false
    junk.kei_recorder_source = target.kei_recorder_source
    junk.daywalker_side = 1
    junk.Transform:SetPosition(x, 0, z)

    if junk.CanBuryDaywalker == nil
        or not junk:CanBuryDaywalker(target)
        or junk.TryBuryDaywalker == nil
        or not junk:TryBuryDaywalker(target)
    then
        junk:Remove()
        return false
    end

    if junk.TryReleaseDaywalker ~= nil then
        junk:TryReleaseDaywalker(target)
    end

    target.kei_recorder_daywalker_junk = junk
    RegisterSupport(support_owner, junk)

    for variation = 1, #ELITE_PREFABS do
        SpawnElite(target, junk, variation, support_owner)
    end

    return true
end

function RecorderDaywalker2.Remove(target)
    if target == nil then
        return
    end

    if target.kei_recorder_pigelitefighters ~= nil then
        for _, elite in ipairs(target.kei_recorder_pigelitefighters) do
            if IsValid(elite) then
                elite:Remove()
            end
        end
        target.kei_recorder_pigelitefighters = nil
    end

    local junk = target.kei_recorder_daywalker_junk
    if IsValid(junk) then
        junk:Remove()
    end
    target.kei_recorder_daywalker_junk = nil
end

return RecorderDaywalker2
