local function HasCraftingInventoryReplica(hud)
    local owner = hud ~= nil and hud.owner or nil
    return owner ~= nil
        and owner:IsValid()
        and owner.replica ~= nil
        and owner.replica.inventory ~= nil
end

-- CraftingMenuHUD can start updating while the player's builder replica is
-- already present but the inventory replica is still being attached. Keep the
-- refresh pending until the inventory is available instead of allowing the
-- vanilla RebuildRecipes -> builder:HasIngredients path to index nil.
AddClassPostConstruct("widgets/redux/craftingmenu_hud", function(self)
    local old_RebuildRecipes = self.RebuildRecipes
    local old_OnUpdate = self.OnUpdate

    self.RebuildRecipes = function(hud, ...)
        if not HasCraftingInventoryReplica(hud) then
            hud.needtoupdate = true
            return
        end
        return old_RebuildRecipes(hud, ...)
    end

    self.OnUpdate = function(hud, dt, ...)
        if hud.needtoupdate and not HasCraftingInventoryReplica(hud) then
            -- Vanilla OnUpdate clears needtoupdate after RebuildRecipes.
            -- Do not call it until the inventory replica is ready.
            hud.needtoupdate = true
            if hud.RefreshCraftingHelpText ~= nil then
                hud:RefreshCraftingHelpText()
            end
            return
        end
        return old_OnUpdate(hud, dt, ...)
    end
end)
