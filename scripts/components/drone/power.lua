-- 旋翼调查仪控制器的电量组件。

local RotorUpgrades = require("kei/drone/upgrades")

local KeiRotorPower = Class(function(self, inst)
    self.inst = inst
    self.base_max_power = TUNING.KEI_ROTOR_CONTROLLER_MAX_POWER or 240
    self.max_power = self.base_max_power
    self.power = self.max_power
    self.skill_drain_rate = 0
    self.follow_drain_rate = 0
    self.task = nil

    self:SyncPerishable()
    self:Start()
end)

local function GetOwner(inst)
    if inst ~= nil and inst._kei_controller_owner ~= nil
        and inst._kei_controller_owner:IsValid()
    then
        return inst._kei_controller_owner
    end

    local inventoryitem = inst ~= nil
        and inst.components ~= nil
        and inst.components.inventoryitem
        or nil
    return inventoryitem ~= nil and inventoryitem.owner
        or nil
end

local function SyncOwnerPower(self)
    local owner = GetOwner(self.inst)
    if owner ~= nil and owner.userid ~= nil then
        owner._kei_rotor_controller_power = self.power
    end
end

function KeiRotorPower:IsEquipped()
    local owner = GetOwner(self.inst)
    if owner == nil then
        return false
    end

    if owner.components ~= nil and owner.components.inventory ~= nil then
        return owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == self.inst
    end

    return self.inst.components ~= nil
        and self.inst.components.equippable ~= nil
        and self.inst.components.equippable:IsEquipped()
end

function KeiRotorPower:SyncPerishable()
    local perishable = self.inst.components ~= nil and self.inst.components.perishable or nil
    if perishable ~= nil then
        perishable:SetPercent(self:GetPercent())
    end
end

function KeiRotorPower:GetPower()
    return self.power
end

function KeiRotorPower:GetMaxPower()
    return self.max_power
end

function KeiRotorPower:GetPercent()
    return self.max_power > 0 and self.power / self.max_power or 0
end

function KeiRotorPower:SetPower(value)
    value = tonumber(value) or 0
    self.power = math.max(0, math.min(self.max_power, value))
    self:SyncPerishable()
    SyncOwnerPower(self)
end

function KeiRotorPower:RefreshMaxPower(owner)
    owner = owner or GetOwner(self.inst)
    local desired = RotorUpgrades.GetControllerMaxPower(owner)
    if desired == self.max_power then
        return
    end

    self.max_power = desired
    local perishable = self.inst.components ~= nil and self.inst.components.perishable or nil
    if perishable ~= nil and perishable.SetPerishTime ~= nil then
        perishable:SetPerishTime(desired)
    end
    -- Capacity changes must not refill an existing controller.
    self:SetPower(self.power)
end

function KeiRotorPower:Recharge(amount)
    amount = tonumber(amount) or self.max_power
    self:SetPower(self.power + amount)
end

function KeiRotorPower:SetSkillDrain(rate)
    self.skill_drain_rate = math.max(0, tonumber(rate) or 0)
end

function KeiRotorPower:GetSkillDrain()
    return self.skill_drain_rate or 0
end

function KeiRotorPower:SetFollowDrain(rate)
    self.follow_drain_rate = math.max(0, tonumber(rate) or 0)
end

function KeiRotorPower:GetFollowDrain()
    return self.follow_drain_rate or 0
end

function KeiRotorPower:HasPower(amount)
    return self.power >= math.max(0, tonumber(amount) or 0)
end

function KeiRotorPower:Consume(amount)
    amount = math.max(0, tonumber(amount) or 0)
    if not self:HasPower(amount) then
        return false
    end

    self:SetPower(self.power - amount)
    return true
end

function KeiRotorPower:Update(dt)
    dt = tonumber(dt) or 0
    if dt <= 0 then
        return
    end

    local owner = GetOwner(self.inst)
    self:RefreshMaxPower(owner)
    local equipped = self:IsEquipped()
    local rate = equipped
        and (TUNING.KEI_ROTOR_CONTROLLER_DRAIN_RATE or 1)
        or (TUNING.KEI_ROTOR_CONTROLLER_REGEN_RATE or 0.5)
    local reduction = equipped and RotorUpgrades.GetControllerDrainReduction(owner) or 0
    local skill_drain = equipped and (self.skill_drain_rate or 0) or 0
    local follow_drain = self.follow_drain_rate or 0
    local delta = equipped
        and -(math.max(0, rate - reduction) + skill_drain + follow_drain)
        or rate - follow_drain
    self:SetPower(self.power + delta * dt)

    if self.power <= 0 then
        if self.inst.components ~= nil
            and self.inst.components["drone/beam"] ~= nil
        then
            self.inst.components["drone/beam"]:Stop()
        end

        local owner = GetOwner(self.inst)
        if owner ~= nil and self.inst.StopDroneFollow ~= nil then
            self.inst:StopDroneFollow(owner)
        end
        if equipped and owner ~= nil and self.inst.StopPilotForOwner ~= nil then
            self.inst:StopPilotForOwner(owner)
        end
        if equipped and owner ~= nil
            and owner.components ~= nil
            and owner.components.inventory ~= nil
            and owner.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == self.inst
        then
            local inventory = owner.components.inventory
            local item = inventory:Unequip(EQUIPSLOTS.HANDS, nil, true)
            if item == self.inst and item:IsValid() then
                inventory:GiveItem(item, nil, owner:GetPosition())
            end
        end
    end
end

function KeiRotorPower:Start()
    if self.task == nil then
        self.task = self.inst:DoPeriodicTask(1, function()
            self:Update(1)
        end)
    end
end

function KeiRotorPower:Stop()
    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end
end

function KeiRotorPower:LongUpdate(dt)
    self:Update(dt)
end

function KeiRotorPower:OnSave()
    return {
        power = self.power,
    }
end

function KeiRotorPower:OnLoad(data)
    -- 兼容旧版本错误地把电量直接保存为数字的存档格式。
    local power = nil
    if type(data) == "number" then
        power = data
    elseif type(data) == "table" then
        power = data.power or data.kei_rotor_power
    end
    if power ~= nil then
        self:SetPower(power)
    end
end

function KeiRotorPower:OnRemoveEntity()
    self:Stop()
end

return KeiRotorPower
