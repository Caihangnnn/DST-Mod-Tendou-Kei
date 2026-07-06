-- 生活协议-踏水：允许 Kei 在海面上行走。

local WaterWalkEffect = {}

local function SetWaterWalkCollision(inst, enabled)
    if enabled and not TheWorld:HasTag("cave") and not inst:HasTag("playerghost") then
        inst.Physics:SetCollisionMask(
            COLLISION.GROUND,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        inst.Physics:Teleport(inst.Transform:GetWorldPosition())
    elseif not inst:HasTag("playerghost") then
        inst.Physics:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        inst.Physics:Teleport(inst.Transform:GetWorldPosition())
    end
end

function WaterWalkEffect.Enable(slots, inst)
    if slots._kei_life_water_walk_enabled then
        return
    end

    local drownable = inst.components.drownable
    if drownable ~= nil and not TheWorld:HasTag("cave") then
        slots._kei_life_water_walk_old_drownable_enabled = drownable.enabled
        drownable.enabled = false
    end

    slots._kei_life_water_walk_enabled = true
    SetWaterWalkCollision(inst, true)
end

function WaterWalkEffect.Disable(slots, inst)
    if not slots._kei_life_water_walk_enabled then
        return
    end

    local drownable = inst.components.drownable
    if drownable ~= nil and slots._kei_life_water_walk_old_drownable_enabled ~= nil then
        drownable.enabled = slots._kei_life_water_walk_old_drownable_enabled ~= false
    end

    slots._kei_life_water_walk_old_drownable_enabled = nil
    slots._kei_life_water_walk_enabled = nil
    SetWaterWalkCollision(inst, false)
end

return WaterWalkEffect