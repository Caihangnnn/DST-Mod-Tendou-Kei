local CONTROLLER_TAG = "kei_rotor_survey_controller"

local function IsController(item)
    return item ~= nil and item:HasTag(CONTROLLER_TAG)
end

local function GetControllerOwnerUserId(item)
    if item ~= nil and item.GetControllerOwnerUserId ~= nil then
        return item:GetControllerOwnerUserId()
    end
    local owner_userid = item ~= nil and item._kei_controller_owner_userid_net or nil
    return owner_userid ~= nil and owner_userid:value() or nil
end

local function IsAllowedControllerDestination(container, opener, item)
    if item == nil or not IsController(item) then
        return true
    end
    if container == nil or opener == nil or opener.userid == nil then
        return false
    end
    if container == opener then
        return GetControllerOwnerUserId(item) == opener.userid
    end
    if not container:HasTag("kei_mini_alice") then
        return false
    end
    local inventoryitem = container.components ~= nil
        and container.components.inventoryitem or nil
    return inventoryitem ~= nil
        and inventoryitem:GetGrandOwner() == opener
        and GetControllerOwnerUserId(item) == opener.userid
end

AddComponentPostInit("container", function(self)
    local old_CanTakeItemInSlot = self.CanTakeItemInSlot
    local old_MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
    local old_MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
    local old_MoveItemFromCountOfSlot = self.MoveItemFromCountOfSlot
    local old_DropItemBySlot = self.DropItemBySlot

    function self:CanTakeItemInSlot(item, slot)
        if IsController(item) then
            if not self.inst:HasTag("kei_mini_alice") then
                return false
            end

            local inventoryitem = self.inst.components ~= nil and self.inst.components.inventoryitem or nil
            local owner = inventoryitem ~= nil and inventoryitem:GetGrandOwner() or nil
            return GetControllerOwnerUserId(item) == (owner ~= nil and owner.userid or nil)
                and owner ~= nil
                and owner.userid ~= nil
        end
        return old_CanTakeItemInSlot(self, item, slot)
    end

    function self:DropItemBySlot(slot, ...)
        local item = self:GetItemInSlot(slot)
        if IsController(item) then
            return nil
        end
        return old_DropItemBySlot(self, slot, ...)
    end

    function self:MoveItemFromAllOfSlot(slot, container, opener, ...)
        local item = self:GetItemInSlot(slot)
        if item ~= nil and not IsAllowedControllerDestination(container, opener, item) then
            return
        end
        return old_MoveItemFromAllOfSlot(self, slot, container, opener, ...)
    end

    function self:MoveItemFromHalfOfSlot(slot, container, opener, ...)
        local item = self:GetItemInSlot(slot)
        if item ~= nil and not IsAllowedControllerDestination(container, opener, item) then
            return
        end
        return old_MoveItemFromHalfOfSlot(self, slot, container, opener, ...)
    end

    function self:MoveItemFromCountOfSlot(slot, container, count, opener, ...)
        local item = self:GetItemInSlot(slot)
        if item ~= nil and not IsAllowedControllerDestination(container, opener, item) then
            return
        end
        return old_MoveItemFromCountOfSlot(self, slot, container, count, opener, ...)
    end
end)

if not TheNet:IsDedicated() then
    AddClassPostConstruct("components/inventory_replica", function(self)
        local old_CanTakeItemInSlot = self.CanTakeItemInSlot

        function self:CanTakeItemInSlot(item, slot)
            if IsController(item) then
                return self.inst ~= nil
                    and self.inst.userid ~= nil
                    and GetControllerOwnerUserId(item) == self.inst.userid
            end
            return old_CanTakeItemInSlot(self, item, slot)
        end
    end)

    AddClassPostConstruct("components/container_replica", function(self)
        local old_CanTakeItemInSlot = self.CanTakeItemInSlot

        function self:CanTakeItemInSlot(item, slot)
            if IsController(item) then
                if self.inst == nil or not self.inst:HasTag("kei_mini_alice") then
                    return false
                end

                local alice_inventoryitem = self.inst.replica.inventoryitem
                return ThePlayer ~= nil
                    and alice_inventoryitem ~= nil
                    and alice_inventoryitem:IsGrandOwner(ThePlayer)
                    and GetControllerOwnerUserId(item) == ThePlayer.userid
            end
            return old_CanTakeItemInSlot(self, item, slot)
        end
    end)

    -- invslot 在点击时会直接发起 Put/Move RPC；对控制器在 UI 入口再次拦截，
    -- 避免客户端先显示到背包、等待服务端拒绝后又回到原位置。
    AddClassPostConstruct("widgets/invslot", function(self)
        local old_Click = self.Click
        local old_TradeItem = self.TradeItem

        local function IsAllowedClientDestination(container, owner)
            if container == nil or owner == nil then
                return false
            end
            if container == owner.replica.inventory then
                return true
            end
            local container_inst = container.inst
            if container_inst == nil or not container_inst:HasTag("kei_mini_alice") then
                return false
            end
            local inventoryitem = container_inst.replica ~= nil
                and container_inst.replica.inventoryitem or nil
            return inventoryitem ~= nil
                and inventoryitem:IsGrandOwner(owner)
        end

        function self:Click(stack_mod)
            local owner = self.owner
            local inventory = owner ~= nil and owner.replica ~= nil
                and owner.replica.inventory or nil
            local active_item = inventory ~= nil and inventory:GetActiveItem() or nil
            if IsController(active_item)
                and not IsAllowedClientDestination(self.container, owner)
            then
                return
            end
            return old_Click(self, stack_mod)
        end

        function self:TradeItem(stack_mod)
            local item = self.container ~= nil
                and self.container:GetItemInSlot(self.num) or nil
            if IsController(item) then
                local owner = self.owner
                local inventory = owner ~= nil and owner.replica ~= nil
                    and owner.replica.inventory or nil
                -- 控制器在主物品栏中不能被交易到其他容器；娇小爱丽丝中的
                -- 控制器仍允许按原版流程移回主物品栏。
                if self.container ~= inventory
                    and not IsAllowedClientDestination(self.container, owner)
                then
                    return
                end
                if self.container == inventory then
                    return
                end
            end
            return old_TradeItem(self, stack_mod)
        end
    end)
end
