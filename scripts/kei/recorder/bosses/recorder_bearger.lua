local RecorderBearger = {}

local BEE_PREFAB = "kei_recorder_bee"
local BEE_TAG = "kei_recorder_bee"

local function IsLiving(inst)
    return inst ~= nil
        and inst:IsValid()
        and not inst:IsInLimbo()
        and (inst.components.health == nil or not inst.components.health:IsDead())
end

local function CleanupBees(inst)
    local bees = inst.kei_recorder_bees
    if bees == nil then
        return
    end

    for _, bee in ipairs(bees) do
        if bee ~= nil and bee:IsValid() then
            bee:Remove()
        end
    end
    inst.kei_recorder_bees = {}
end

local function PruneBees(inst)
    local bees = inst.kei_recorder_bees
    if bees == nil then
        return
    end

    for i = #bees, 1, -1 do
        local bee = bees[i]
        if bee == nil or not bee:IsValid() or bee:IsInLimbo() then
            table.remove(bees, i)
        end
    end
end

local function SpawnBee(inst, x, z)
    local bee = SpawnPrefab(BEE_PREFAB)
    if bee == nil then
        return
    end

    bee.Transform:SetPosition(x, 0, z)
    if bee.SetRecorderBearger ~= nil then
        bee:SetRecorderBearger(inst)
    else
        bee.kei_recorder_bearger = inst
    end

    table.insert(inst.kei_recorder_bees, bee)
end

local function SpawnBees(inst)
    if not IsLiving(inst) then
        return
    end

    PruneBees(inst)
    local x, _, z = inst.Transform:GetWorldPosition()
    local base_rotation = inst.Transform:GetRotation() * DEGREES
    local distance = TUNING.KEI_RECORDER_BEARGER_BEE_SPAWN_DISTANCE or 20
    local count = TUNING.KEI_RECORDER_BEARGER_BEE_COUNT_PER_POINT or 6

    for direction = 0, 2 do
        local angle = base_rotation + direction * (TWOPI / 3)
        local point_x = x + math.cos(angle) * distance
        local point_z = z - math.sin(angle) * distance
        for i = 1, count do
            -- A small spread prevents the six bees at one summon point from
            -- sharing exactly the same physics position.
            local spread_angle = math.random() * TWOPI
            local spread_distance = math.sqrt(math.random()) * 1.5
            SpawnBee(
                inst,
                point_x + math.cos(spread_angle) * spread_distance,
                point_z + math.sin(spread_angle) * spread_distance
            )
        end
    end
end

function RecorderBearger.GetNextBee(inst)
    if inst == nil or not inst:IsValid() then
        return nil
    end

    PruneBees(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local closest = nil
    local closest_dist_sq = math.huge
    for _, bee in ipairs(inst.kei_recorder_bees or {}) do
        if bee:HasTag(BEE_TAG)
            and bee.components.health ~= nil
            and not bee.components.health:IsDead()
        then
            local bx, by, bz = bee.Transform:GetWorldPosition()
            local dx = bx - x
            local dy = by - y
            local dz = bz - z
            local dist_sq = dx * dx + dy * dy + dz * dz
            if dist_sq < closest_dist_sq then
                closest = bee
                closest_dist_sq = dist_sq
            end
        end
    end
    return closest
end

function RecorderBearger.Apply(inst)
    if not IsLiving(inst) then
        return false
    end

    RecorderBearger.Remove(inst)
    inst.kei_recorder_bees = {}
    inst.kei_recorder_bee_spawn_task = inst:DoPeriodicTask(
        TUNING.KEI_RECORDER_BEARGER_BEE_COOLDOWN or 20,
        SpawnBees
    )
    return true
end

function RecorderBearger.Remove(inst)
    if inst == nil then
        return
    end

    if inst.kei_recorder_bee_spawn_task ~= nil then
        inst.kei_recorder_bee_spawn_task:Cancel()
        inst.kei_recorder_bee_spawn_task = nil
    end

    CleanupBees(inst)
    inst.kei_recorder_bees = nil
end

return RecorderBearger
