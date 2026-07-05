-- 邪天翁协议：水面行走（禁用溺水 + 修改碰撞遮罩）。

local MalbatrossEffect = {}

function MalbatrossEffect.Enable(slots, inst)
    if slots._kei_malbatross_enabled then
        return
    end

    local drownable = inst.components.drownable
    if drownable ~= nil and not TheWorld:HasTag("cave") then
        slots._kei_malbatross_old_drownable_enabled = drownable.enabled
        drownable.enabled = false
        inst.Physics:SetCollisionMask(
            COLLISION.GROUND,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        inst.Physics:Teleport(inst.Transform:GetWorldPosition())
    end

    slots._kei_malbatross_enabled = true
end

function MalbatrossEffect.Disable(slots, inst)
    if not slots._kei_malbatross_enabled then
        return
    end

    local drownable = inst.components.drownable
    if drownable ~= nil then
        drownable.enabled = slots._kei_malbatross_old_drownable_enabled ~= false
        slots._kei_malbatross_old_drownable_enabled = nil
    end

    if not inst:HasTag("playerghost") then
        inst.Physics:SetCollisionMask(
            COLLISION.WORLD,
            COLLISION.OBSTACLES,
            COLLISION.SMALLOBSTACLES,
            COLLISION.CHARACTERS,
            COLLISION.GIANTS
        )
        inst.Physics:Teleport(inst.Transform:GetWorldPosition())
    end

    slots._kei_malbatross_enabled = nil
end

return MalbatrossEffect
