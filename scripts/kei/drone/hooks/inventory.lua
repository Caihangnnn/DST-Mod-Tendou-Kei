local CONTROLLER_TAG = "kei_rotor_survey_controller"

local function IsController(item)
    return item ~= nil and item:HasTag(CONTROLLER_TAG)
end

local function IsAllowedControllerDestination(container, owner, item)
    if item == nil or not IsController(item) then
        return true
    end
    if container == nil or owner == nil or owner.userid == nil then
        return false
    end
    if container == owner then
        return true
    end
    return false
end

AddComponentPostInit("inventory", function(self)
    local old_CanTakeItemInSlot = self.CanTakeItemInSlot
    local old_MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
    local old_MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
    local old_MoveItemFromCountOfSlot = self.MoveItemFromCountOfSlot
    local old_DropItem = self.DropItem

    function self:CanTakeItemInSlot(item, slot)
        if IsController(item) then
            return true
        end
        return old_CanTakeItemInSlot(self, item, slot)
    end

    function self:MoveItemFromAllOfSlot(slot, container, ...)
        local item = self:GetItemInSlot(slot)
        if item ~= nil and not IsAllowedControllerDestination(container, self.inst, item) then
            return
        end
        return old_MoveItemFromAllOfSlot(self, slot, container, ...)
    end

    function self:MoveItemFromHalfOfSlot(slot, container, ...)
        local item = self:GetItemInSlot(slot)
        if item ~= nil and not IsAllowedControllerDestination(container, self.inst, item) then
            return
        end
        return old_MoveItemFromHalfOfSlot(self, slot, container, ...)
    end

    function self:MoveItemFromCountOfSlot(slot, container, count, ...)
        local item = self:GetItemInSlot(slot)
        if item ~= nil and not IsAllowedControllerDestination(container, self.inst, item) then
            return
        end
        return old_MoveItemFromCountOfSlot(self, slot, container, count, ...)
    end

    function self:DropItem(item, wholestack, randomdir, pos, keepoverstacked)
        return old_DropItem(self, item, wholestack, randomdir, pos, keepoverstacked)
    end
end)
