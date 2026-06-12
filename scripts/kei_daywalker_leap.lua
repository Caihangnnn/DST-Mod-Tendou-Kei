local DaywalkerLeap = {}

local function HasServerProtocol(inst)
    return inst.components.kei_protocolslots ~= nil and inst.components.kei_protocolslots:HasCombatProtocol("daywalker")
end

local function HasClientProtocol(inst)
    return inst._kei_daywalker_protocol_active ~= nil and inst._kei_daywalker_protocol_active:value()
end

function DaywalkerLeap.HasProtocol(inst)
    if inst == nil then
        return false
    end
    return HasServerProtocol(inst) or HasClientProtocol(inst)
end

function DaywalkerLeap.IsAiming(inst)
    if inst == nil then
        return false
    end
    return inst.kei_daywalker_aiming == true
        or (inst._kei_daywalker_aiming ~= nil and inst._kei_daywalker_aiming:value())
end

function DaywalkerLeap.GetTargetPoint(inst, targetpos)
    if inst == nil or targetpos == nil then
        return nil
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local dx = targetpos.x - x
    local dz = targetpos.z - z
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist <= 0 then
        return nil
    end

    local maxdist = TUNING.KEI_DAYWALKER_LEAP_DISTANCE or 7
    local map = TheWorld.Map
    local dirx = dx / dist
    local dirz = dz / dist
    local pt = Vector3(0, 0, 0)

    for d = math.min(dist, maxdist), 0.5, -0.25 do
        pt.x = x + dirx * d
        pt.z = z + dirz * d
        if map:IsPassableAtPoint(pt:Get())
            and not map:IsGroundTargetBlocked(pt)
            and not map:IsPointNearHole(pt)
        then
            return pt
        end
    end

    return nil
end

function DaywalkerLeap.ReticuleTargetFn(inst)
    local distance = TUNING.KEI_DAYWALKER_LEAP_DISTANCE or 7
    return DaywalkerLeap.GetTargetPoint(inst, Vector3(inst.entity:LocalToWorldSpace(distance, 0, 0)))
end

function DaywalkerLeap.ReticuleMouseTargetFn(inst, mousepos)
    return DaywalkerLeap.GetTargetPoint(inst, mousepos)
end

return DaywalkerLeap
