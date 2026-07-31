-- 动物学家：累计经验达到要求后，击杀生物时将战利品独立判定两次。

local Zoologist = {}

local function GetExperienceTotal(inst)
    if inst == nil then
        return 0
    end

    local experience = inst.components ~= nil and inst.components.kei_experience or nil
    if experience ~= nil then
        return tonumber(experience.total) or 0
    end

    -- 客户端只用于动作和状态预测，实际战利品判定始终在服务器执行。
    if inst._kei_experience_total ~= nil then
        return tonumber(inst._kei_experience_total:value()) or 0
    end

    return 0
end

local function IsActive(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst:HasTag("kei")
        and not inst:HasTag("playerghost")
        and GetExperienceTotal(inst) >= (TUNING.KEI_ZOOLOGIST_EXPERIENCE_THRESHOLD or 10000)
end

local function GetSourceOwner(source)
    if source == nil or not source:IsValid() then
        return nil
    end

    if source:HasTag("kei") then
        return source
    end

    if source.components ~= nil and source.components.inventoryitem ~= nil then
        local inventoryitem = source.components.inventoryitem
        if inventoryitem.GetGrandOwner ~= nil then
            local owner = inventoryitem:GetGrandOwner()
            if owner ~= nil then
                return owner
            end
        end
        if inventoryitem.owner ~= nil then
            return inventoryitem.owner
        end
    end

    if source.components ~= nil and source.components.projectile ~= nil then
        local projectile = source.components.projectile
        local owner = projectile.owner or projectile.caster or projectile.attacker
        if owner ~= nil then
            return owner
        end
    end

    if source.components ~= nil and source.components.follower ~= nil then
        return source.components.follower:GetLeader()
    end

    return nil
end

local function FindKiller(data)
    if data == nil then
        return nil
    end

    local source = data.afflicter or data.attacker or data.source
    local owner = GetSourceOwner(source)
    if IsActive(owner) then
        return owner
    end

    return nil
end

local function MarkDoubleLoot(victim, data)
    if victim == nil
        or not victim:IsValid()
        or victim:HasTag("player")
        or victim.components == nil
        or victim.components.lootdropper == nil
    then
        return
    end

    if FindKiller(data) ~= nil then
        victim._kei_zoologist_double_loot = true
    end
end

local function AddDeathHook(component)
    if TheWorld == nil or not TheWorld.ismastersim or component.inst:HasTag("player") then
        return
    end

    component.inst:ListenForEvent("death", MarkDoubleLoot)
end

local function AddLootDropHook(component)
    if component._kei_zoologist_drop_loot_wrapped then
        return
    end

    local old_drop_loot = component.DropLoot
    if old_drop_loot == nil then
        return
    end

    component._kei_zoologist_drop_loot_wrapped = true
    component.DropLoot = function(self, ...)
        local result = old_drop_loot(self, ...)
        if self.inst._kei_zoologist_double_loot then
            -- 清除标记后再执行第二次，避免同一生物后续重复调用 DropLoot
            -- 时继续获得额外战利品。
            self.inst._kei_zoologist_double_loot = nil
            old_drop_loot(self, ...)
        end
        return result
    end
end

AddComponentPostInit("health", AddDeathHook)
AddComponentPostInit("lootdropper", AddLootDropHook)

return Zoologist
