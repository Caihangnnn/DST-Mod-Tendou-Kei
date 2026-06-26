-- 龙蝇协议：过热免疫 + 火焰伤害免疫 + 温度上限（免疫过热） + 粉色火焰燃烧。

local DRAGONFLY_BURN_COLOUR = { 242 / 255, 144 / 255, 186 / 255, 1 }
local DRAGONFLY_BURN_DURATION = 30
local DRAGONFLY_BURN_DAMAGE_PERIOD = 1
local DRAGONFLY_BURN_MAX_HEALTH_DAMAGE = 0.001

local DragonflyEffect = {}

-- ---------- 粉色火焰燃烧 ----------

local function ApplyDragonflyBurnVisuals(target)
    local burnable = target ~= nil and target.components.burnable or nil
    if burnable == nil or burnable.fxchildren == nil then
        return
    end

    for _, fx in ipairs(burnable.fxchildren) do
        if fx.AnimState ~= nil then
            fx.AnimState:SetMultColour(
                DRAGONFLY_BURN_COLOUR[1],
                DRAGONFLY_BURN_COLOUR[2],
                DRAGONFLY_BURN_COLOUR[3],
                DRAGONFLY_BURN_COLOUR[4]
            )
        end
        if fx.components.firefx ~= nil and fx.components.firefx.light ~= nil then
            fx.components.firefx.light.Light:SetColour(
                DRAGONFLY_BURN_COLOUR[1],
                DRAGONFLY_BURN_COLOUR[2],
                DRAGONFLY_BURN_COLOUR[3]
            )
        end
    end
end

local function StopDragonflyBurn(target)
    local data = target ~= nil and target._kei_dragonfly_burn_data or nil
    if data == nil then
        return
    end

    target._kei_dragonfly_burn_data = nil
    if data.task ~= nil then
        data.task:Cancel()
    end
    if data.has_old_burntime and target.components.burnable ~= nil then
        target.components.burnable.burntime = data.old_burntime
    end
    if data.onextinguish ~= nil then
        target:RemoveEventCallback("onextinguish", data.onextinguish)
    end
    if data.ondeath ~= nil then
        target:RemoveEventCallback("death", data.ondeath)
    end
    if data.onremove ~= nil then
        target:RemoveEventCallback("onremove", data.onremove)
    end
end

local function StartDragonflyBurn(owner, target)
    if owner == nil
        or target == nil
        or not target:IsValid()
        or target.components.burnable == nil
    then
        return
    end

    local burnable = target.components.burnable
    if burnable:IsBurning() then
        local data = target._kei_dragonfly_burn_data
        if data == nil then
            return
        end

        burnable.burntime = DRAGONFLY_BURN_DURATION
        burnable:ExtendBurning()
        ApplyDragonflyBurnVisuals(target)
        return
    end

    local had_tag = owner:HasTag("controlled_burner")
    if not had_tag then
        owner:AddTag("controlled_burner")
    end
    burnable:Ignite(nil, owner, owner)
    if not had_tag then
        owner:RemoveTag("controlled_burner")
    end

    if not burnable:IsBurning() then
        return
    end

    ApplyDragonflyBurnVisuals(target)
    StopDragonflyBurn(target)

    local data = { old_burntime = burnable.burntime, has_old_burntime = true }
    burnable.burntime = DRAGONFLY_BURN_DURATION
    burnable:ExtendBurning()
    data.onextinguish = function(target_inst)
        StopDragonflyBurn(target_inst)
    end
    data.onremove = function(target_inst)
        StopDragonflyBurn(target_inst)
    end
    data.ondeath = function(target_inst)
        StopDragonflyBurn(target_inst)
    end
    data.task = target:DoPeriodicTask(DRAGONFLY_BURN_DAMAGE_PERIOD, function(target_inst)
        if target_inst.components.health == nil or target_inst.components.health:IsDead() then
            StopDragonflyBurn(target_inst)
            return
        end
        if target_inst.components.burnable == nil or not target_inst.components.burnable:IsBurning() then
            StopDragonflyBurn(target_inst)
            return
        end

        local max_health = target_inst.components.health.maxhealth or 0
        local damage = max_health * DRAGONFLY_BURN_MAX_HEALTH_DAMAGE
        if damage > 0 then
            target_inst.components.health:DoFireDamage(damage, owner, true)
        end
        ApplyDragonflyBurnVisuals(target_inst)
    end, DRAGONFLY_BURN_DAMAGE_PERIOD)

    target._kei_dragonfly_burn_data = data
    target:ListenForEvent("onextinguish", data.onextinguish)
    target:ListenForEvent("death", data.ondeath)
    target:ListenForEvent("onremove", data.onremove)
end

-- ---------- 接口方法 ----------

function DragonflyEffect.Enable(slots, inst)
    inst:AddTag("kei_nooverheat")

    if inst.components.temperature ~= nil
        and inst.components.temperature:GetCurrent() > TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE
    then
        inst.components.temperature:SetTemperature(TUNING.KEI_DRAGONFLY_MAX_TEMPERATURE)
    end
    if inst.components.health ~= nil then
        inst.components.health.externalfiredamagemultipliers:SetModifier(inst, 0)
    end
end

function DragonflyEffect.Disable(slots, inst)
    inst:RemoveTag("kei_nooverheat")

    if inst.components.health ~= nil then
        inst.components.health.externalfiredamagemultipliers:RemoveModifier(inst)
    end
end

function DragonflyEffect.OnHitOther(slots, inst, data)
    local target = data and data.target
    if target ~= nil then
        StartDragonflyBurn(inst, target)
    end
end

return DragonflyEffect
