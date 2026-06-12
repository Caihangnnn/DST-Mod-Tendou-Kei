local EyeOfTerrorDash = {}

function EyeOfTerrorDash.HasProtocol(inst)
    if inst == nil then
        return false
    end
    if inst.components.kei_protocolslots ~= nil then
        return inst.components.kei_protocolslots:HasCombatProtocol("eyeofterror")
    end
    return inst._kei_eyeofterror_protocol_active ~= nil and inst._kei_eyeofterror_protocol_active:value()
end

function EyeOfTerrorDash.GetTargetPoint(inst, targetpos)
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

    local maxdist = TUNING.KEI_EYEOFTERROR_DASH_DISTANCE or 12
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

function EyeOfTerrorDash.ReticuleTargetFn(inst)
    local distance = TUNING.KEI_EYEOFTERROR_DASH_DISTANCE or 12
    return EyeOfTerrorDash.GetTargetPoint(inst, Vector3(inst.entity:LocalToWorldSpace(distance, 0, 0)))
end

function EyeOfTerrorDash.ReticuleMouseTargetFn(inst, mousepos)
    return EyeOfTerrorDash.GetTargetPoint(inst, mousepos)
end

function EyeOfTerrorDash.ReticuleUpdatePositionFn(inst, pos, reticule, ease, smoothing, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    reticule.Transform:SetPosition(x, 0, z)
    local rot = -math.atan2(pos.z - z, pos.x - x) / DEGREES
    if ease and dt ~= nil then
        local rot0 = reticule.Transform:GetRotation()
        local drot = rot - rot0
        rot = Lerp((drot > 180 and rot0 + 360) or (drot < -180 and rot0 - 360) or rot0, rot, dt * smoothing)
    end
    reticule.Transform:SetRotation(rot)
end

return EyeOfTerrorDash
