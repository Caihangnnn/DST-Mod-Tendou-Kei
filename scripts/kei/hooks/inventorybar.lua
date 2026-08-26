local function HasInventoryReplica(inventorybar)
    local owner = inventorybar ~= nil and inventorybar.owner or nil
    return owner ~= nil
        and owner:IsValid()
        and owner.replica ~= nil
        and owner.replica.inventory ~= nil
end

local function InstallInventoryBarGuards(inventorybar)
    if inventorybar == nil or inventorybar._kei_inventorybar_guards_installed then
        return
    end

    inventorybar._kei_inventorybar_guards_installed = true

    local old_rebuild = inventorybar.Rebuild
    inventorybar.Rebuild = function(self, ...)
        if not HasInventoryReplica(self) then
            self.rebuild_pending = true
            return
        end
        return old_rebuild(self, ...)
    end

    local old_refresh = inventorybar.Refresh
    inventorybar.Refresh = function(self, ...)
        if not HasInventoryReplica(self) then
            self.rebuild_pending = true
            return
        end
        return old_refresh(self, ...)
    end
end

AddClassPostConstruct("widgets/inventorybar", function(self)
    -- Install lazily so all other inventorybar wrappers are already present.
    local old_update = self.OnUpdate
    self.OnUpdate = function(self, dt, ...)
        InstallInventoryBarGuards(self)
        if not HasInventoryReplica(self) then
            self.rebuild_pending = true
            return
        end
        return old_update(self, dt, ...)
    end
end)
