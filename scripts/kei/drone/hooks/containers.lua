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
        return true
    end
    return false
end

AddComponentPostInit("container", function(self)
    local old_CanTakeItemInSlot = self.CanTakeItemInSlot
    local old_MoveItemFromAllOfSlot = self.MoveItemFromAllOfSlot
    local old_MoveItemFromHalfOfSlot = self.MoveItemFromHalfOfSlot
    local old_MoveItemFromCountOfSlot = self.MoveItemFromCountOfSlot
    local old_DropItemBySlot = self.DropItemBySlot

    function self:CanTakeItemInSlot(item, slot)
        if IsController(item) then
            return false
        end
        return old_CanTakeItemInSlot(self, item, slot)
    end

    function self:DropItemBySlot(slot, ...)
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
                return true
            end
            return old_CanTakeItemInSlot(self, item, slot)
        end
    end)

    AddClassPostConstruct("components/container_replica", function(self)
        local old_CanTakeItemInSlot = self.CanTakeItemInSlot

        function self:CanTakeItemInSlot(item, slot)
            if IsController(item) then
                return false
            end
            return old_CanTakeItemInSlot(self, item, slot)
        end
    end)

    -- invslot 在点击时会直接发起 Put/Move RPC；对控制器在 UI 入口再次拦截，
    -- 避免客户端先显示到背包、等待服务端拒绝后又回到原位置。
    AddClassPostConstruct("widgets/invslot", function(self)
        local old_Click = self.Click
        local old_TradeItem = self.TradeItem

        local function IsAllowedClientInventoryDestination(container, owner)
            if container == nil or owner == nil then
                return false
            end
            if container == owner.replica.inventory then
                return true
            end
            return false
        end

        function self:Click(stack_mod)
            local owner = self.owner
            local inventory = owner ~= nil and owner.replica ~= nil
                and owner.replica.inventory or nil
            local active_item = inventory ~= nil and inventory:GetActiveItem() or nil
            if IsController(active_item)
                and not IsAllowedClientInventoryDestination(self.container, owner)
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
                -- 控制器不能从主物品栏交易到容器；保留旧存档中
                -- Alice 控制器向主物品栏单向取出的机会。
                local source_is_alice = self.container ~= nil
                    and self.container.inst ~= nil
                    and self.container.inst:HasTag("kei_mini_alice")
                if self.container ~= inventory and not source_is_alice then
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
