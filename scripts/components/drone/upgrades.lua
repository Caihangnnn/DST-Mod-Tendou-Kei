-- Persistent rotor surveyor upgrade levels owned by the Kei character.

local RotorUpgrades = require("kei/drone/upgrades")

local KeiRotorUpgrades = Class(function(self, inst)
    self.inst = inst
    self.levels = {}
    for _, upgrade in ipairs(RotorUpgrades.UPGRADE_ORDER) do
        self.levels[upgrade] = 0
    end
    self:SyncNetValues()
end)

function KeiRotorUpgrades:GetLevel(upgrade)
    return self.levels[upgrade] or 0
end

function KeiRotorUpgrades:SyncNetValues()
    for _, upgrade in ipairs(RotorUpgrades.UPGRADE_ORDER) do
        local netvar = self.inst["_kei_rotor_upgrade_" .. upgrade]
        if netvar ~= nil then
            netvar:set(self:GetLevel(upgrade))
        end
    end
end

function KeiRotorUpgrades:CanUpgrade(upgrade)
    return RotorUpgrades.GetMaxLevel(upgrade) > self:GetLevel(upgrade)
end

function KeiRotorUpgrades:Upgrade(upgrade)
    if not self:CanUpgrade(upgrade) then
        return false, "KEI_ROTOR_UPGRADE_MAX"
    end

    self.levels[upgrade] = self:GetLevel(upgrade) + 1
    self:SyncNetValues()
    self.inst:PushEvent("kei_rotor_upgrades_changed", { upgrade = upgrade })
    return true
end

function KeiRotorUpgrades:OnSave()
    return {
        levels = self.levels,
    }
end

function KeiRotorUpgrades:OnLoad(data)
    local saved = data ~= nil and data.levels or nil
    if saved == nil and data ~= nil then
        saved = data
    end

    for _, upgrade in ipairs(RotorUpgrades.UPGRADE_ORDER) do
        local value = saved ~= nil and tonumber(saved[upgrade]) or 0
        self.levels[upgrade] = math.max(
            0,
            math.min(RotorUpgrades.GetMaxLevel(upgrade), math.floor(value or 0))
        )
    end
    self:SyncNetValues()
end

function KeiRotorUpgrades:OnRemoveFromEntity()
    for _, upgrade in ipairs(RotorUpgrades.UPGRADE_ORDER) do
        self.inst["_kei_rotor_upgrade_" .. upgrade] = nil
    end
end

return KeiRotorUpgrades
