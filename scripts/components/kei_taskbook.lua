local TaskBook = require("kei/task_book")
local TaskSummon = require("kei/task_summon")

local TASK_MILESTONE_GIFTS = {
    { count = 10, prefab = "kei_blank_cd_random" },
    { count = 25, prefab = "kei_combat_cd_blue_random" },
    { count = 50, prefab = "kei_combat_cd_golden_random" },
    { count = 100, prefab = "kei_combat_cd_purple_random" },
}

local KeiTaskBook = Class(function(self, inst)
    self.inst = inst
    self.records = {}
    self.implanted = {}
    self.tasks = {}
    self.task_serial = 0
    self.last_generated_day = -1
    self.last_blueprint_reward_day = -1
    self.task_version = TaskBook.TASK_VERSION
    self.completed_task_count = 0
    self.claimed_task_milestones = {}
    self:SyncNetValues()
end)

function KeiTaskBook:SyncNetValues()
    if self.inst._kei_taskbook_records ~= nil then self.inst._kei_taskbook_records:set(TaskBook.EncodeRecords(self.records)) end
    if self.inst._kei_taskbook_implanted ~= nil then self.inst._kei_taskbook_implanted:set(TaskBook.EncodeRecords(self.implanted)) end
    if self.inst._kei_taskbook_tasks ~= nil then self.inst._kei_taskbook_tasks:set(TaskBook.EncodeTasks(self.tasks)) end
    if self.inst._kei_taskbook_completed_count ~= nil then
        self.inst._kei_taskbook_completed_count:set(self.completed_task_count or 0)
    end
end

local function GetWorldDay()
    return TheWorld ~= nil and TheWorld.state ~= nil and (TheWorld.state.cycles or 0) or 0
end

local function CollectItems(holder, items, visited)
    if holder == nil or visited[holder] then return end
    visited[holder] = true
    table.insert(items, holder)
    local container = holder.components ~= nil and holder.components.container or nil
    if container ~= nil then
        for slot = 1, container:GetNumSlots() do
            CollectItems(container:GetItemInSlot(slot), items, visited)
        end
    end
end

function KeiTaskBook:GetOwnedItems()
    local inventory = self.inst.components.inventory
    local items, visited = {}, {}
    if inventory == nil then return items end
    for slot = 1, inventory:GetNumSlots() do
        CollectItems(inventory:GetItemInSlot(slot), items, visited)
    end
    CollectItems(inventory:GetActiveItem(), items, visited)
    return items
end

function KeiTaskBook:CountOwnedPrefab(prefab)
    local count = 0
    for _, item in ipairs(self:GetOwnedItems()) do
        if item.prefab == prefab then
            local stackable = item.components ~= nil and item.components.stackable or nil
            count = count + (stackable ~= nil and stackable:StackSize() or 1)
        end
    end
    return count
end

function KeiTaskBook:ConsumeOwnedPrefab(prefab, amount)
    if self:CountOwnedPrefab(prefab) < amount then return false end
    local remaining = amount
    for _, item in ipairs(self:GetOwnedItems()) do
        if remaining <= 0 then break end
        if item.prefab == prefab then
            local stackable = item.components ~= nil and item.components.stackable or nil
            local size = stackable ~= nil and stackable:StackSize() or 1
            local take = math.min(size, remaining)
            if stackable ~= nil and take < size then
                local split = stackable:Get(take)
                if split ~= nil then split:Remove() end
            else
                item:Remove()
            end
            remaining = remaining - take
        end
    end
    return remaining == 0
end

function KeiTaskBook:PrepareTaskReward(prefab, amount)
    local rewards = {}
    while amount > 0 do
        local item = SpawnPrefab(prefab)
        if item == nil then
            for _, reward in ipairs(rewards) do reward:Remove() end
            return nil
        end
        local stackable = item.components ~= nil and item.components.stackable or nil
        -- Stackable exposes maxsize as a field on the server component.
        local maxsize = stackable ~= nil and stackable.maxsize or 1
        local give = math.min(amount, maxsize or 1)
        if stackable ~= nil then stackable:SetStackSize(give) end
        table.insert(rewards, item)
        amount = amount - give
    end
    return rewards
end

function KeiTaskBook:GiveTaskReward(rewards)
    local inventory = self.inst.components.inventory
    for _, reward in ipairs(rewards or {}) do
        inventory:GiveItem(reward, nil, self.inst:GetPosition())
    end
end

function KeiTaskBook:GiveTaskExperience(rarity)
    local rewards = TUNING.KEI_TASK_EXPERIENCE_REWARD_BY_RARITY or {}
    local amount = rewards[tonumber(rarity) or 0] or 0
    local experience = self.inst.components ~= nil and self.inst.components.kei_experience or nil
    return experience ~= nil and experience:DoDelta(amount) or 0
end

function KeiTaskBook:GiveTaskMilestoneGifts()
    local inventory = self.inst.components ~= nil and self.inst.components.inventory or nil
    if inventory == nil then return end

    for _, milestone in ipairs(TASK_MILESTONE_GIFTS) do
        if self.completed_task_count >= milestone.count
            and not self.claimed_task_milestones[milestone.count]
        then
            local gift = SpawnPrefab(milestone.prefab)
            if gift ~= nil then
                inventory:GiveItem(gift, nil, self.inst:GetPosition())
                self.claimed_task_milestones[milestone.count] = true
            end
        end
    end
end

local function CanReceiveRandomBlueprint(recipe, builder)
    if recipe == nil or recipe.nounlock or recipe.builder_tag ~= nil then
        return false
    end

    -- Match the game's random blueprint rules: recipes without a real tech
    -- tier and recipes from the LOST tier are not learnable blueprint rewards.
    local has_tech = false
    for _, value in pairs(recipe.level or {}) do
        if value >= 10 then
            return false
        elseif value > 0 then
            has_tech = true
        end
    end
    if not has_tech or builder == nil then return false end

    return not builder:KnowsRecipe(recipe) and builder:CanLearn(recipe.name)
end

function KeiTaskBook:GiveDailyBlueprintReward()
    local day = GetWorldDay()
    if self.last_blueprint_reward_day == day then return false end

    local builder = self.inst.components ~= nil and self.inst.components.builder or nil
    if builder == nil or AllRecipes == nil then return false end

    local candidates = {}
    for _, recipe in pairs(AllRecipes) do
        if IsRecipeValid(recipe.name) and CanReceiveRandomBlueprint(recipe, builder) then
            table.insert(candidates, recipe)
        end
    end
    if #candidates == 0 then return false end

    local recipe = candidates[math.random(#candidates)]
    local blueprint = SpawnPrefab("blueprint")
    if blueprint == nil or blueprint.components == nil or blueprint.components.teacher == nil then
        if blueprint ~= nil then blueprint:Remove() end
        return false
    end

    blueprint.recipetouse = recipe.name
    blueprint.components.teacher:SetRecipe(recipe.name)
    local names = STRINGS ~= nil and STRINGS.NAMES or nil
    local recipe_name = names ~= nil and names[string.upper(recipe.name)] or nil
    local blueprint_name = names ~= nil and names.BLUEPRINT or "Blueprint"
    local unknown_name = names ~= nil and names.UNKNOWN or "Unknown"
    if blueprint.components.named ~= nil then
        blueprint.components.named:SetName((recipe_name or unknown_name or recipe.name) .. " " .. blueprint_name)
    end

    local inventory = self.inst.components.inventory
    if inventory == nil then
        blueprint:Remove()
        return false
    end
    inventory:GiveItem(blueprint, nil, self.inst:GetPosition())
    self.last_blueprint_reward_day = day
    return true
end

function KeiTaskBook:RemoveExpiredTasks(day)
    local kept, changed = {}, false
    for _, task in ipairs(self.tasks) do
        -- Completed tasks remain visible for the rest of the current day, then
        -- leave the book together with expired unfinished tasks at day refresh.
        if task.completed or task.expires_day <= day then
            changed = true
        else
            table.insert(kept, task)
        end
    end
    self.tasks = kept
    return changed
end

function KeiTaskBook:ActiveCount(rarity)
    local count = 0
    for _, task in ipairs(self.tasks) do
        if task.rarity == rarity and not task.completed then count = count + 1 end
    end
    return count
end

function KeiTaskBook:GetActiveTargetPrefabs()
    local targets = {}
    for _, task in ipairs(self.tasks) do
        if not task.completed then targets[task.target_prefab] = true end
    end
    return targets
end

function KeiTaskBook:GenerateDailyTasks(day)
    if self.last_generated_day == day then return false end
    self.last_generated_day = day
    local changed = self:RemoveExpiredTasks(day)
    local active_targets = self:GetActiveTargetPrefabs()
    for rarity, data in pairs(TaskBook.TASK_RARITIES) do
        local remaining = data.active_limit - self:ActiveCount(rarity)
        -- cycles is zero-based: all tiers run on day one, then tier 2 repeats
        -- every two days and tier 3 repeats every three days.
        if remaining > 0 and day % rarity == 0 then
            local count = math.min(math.random(data.min_count, data.max_count), remaining)
            for _ = 1, count do
                self.task_serial = self.task_serial + 1
                local task = TaskBook.MakeTask(rarity, self.task_serial, day, active_targets)
                if task ~= nil then
                    table.insert(self.tasks, task)
                    active_targets[task.target_prefab] = true
                    changed = true
                end
            end
        end
    end
    if changed then self:SyncNetValues() self.inst:PushEvent("kei_taskbook_changed") end
    return changed
end

function KeiTaskBook:RefreshDailyTasks()
    return self:GenerateDailyTasks(GetWorldDay())
end

function KeiTaskBook:SubmitTask(id)
    for _, task in ipairs(self.tasks) do
        if task.id == id and not task.completed then
            if task.expires_day <= GetWorldDay() then
                return false
            end
            local offer = task.offer
            if offer == nil then return false end
            local rewards = self:PrepareTaskReward(offer.reward_prefab, offer.reward_count)
            if rewards == nil then return false end
            if not self:ConsumeOwnedPrefab(offer.submit_prefab, offer.submit_count) then
                for _, reward in ipairs(rewards) do reward:Remove() end
                return false
            end
            self:GiveTaskReward(rewards)
            self:GiveTaskExperience(task.rarity)
            task.completed = true
            self.completed_task_count = self.completed_task_count + 1
            self:GiveTaskMilestoneGifts()
            self:GiveDailyBlueprintReward()
            self:SyncNetValues()
            self.inst:PushEvent("kei_taskbook_changed", { task_id = id, completed = true })
            return true
        end
    end
    return false
end

function KeiTaskBook:SetTaskShares(id, shares)
    for _, task in ipairs(self.tasks) do
        if task.id == id and not task.completed and task.expires_day > GetWorldDay() then
            local offer = TaskBook.BuildTaskOffer(task, shares)
            if offer == nil then return false end
            task.offer = offer
            self:SyncNetValues()
            self.inst:PushEvent("kei_taskbook_changed", { task_id = id, shares = offer.shares })
            return true
        end
    end
    return false
end

local function GetTaskSummonPosition(player)
    local x, y, z = player.Transform:GetWorldPosition()
    local map = TheWorld ~= nil and TheWorld.Map or nil
    for _ = 1, 12 do
        local angle = math.random() * 2 * PI
        local distance = math.random(3, 5)
        local sx, sz = x + math.cos(angle) * distance, z + math.sin(angle) * distance
        if map == nil or map:IsPassableAtPoint(sx, y, sz) then
            return sx, y, sz
        end
    end
    return x, y, z
end

local function DisableTaskSummonLoot(target)
    local dropper = target.components ~= nil and target.components.lootdropper or nil
    if dropper == nil then return end
    dropper.loot = {}
    dropper.chanceloot = {}
    dropper.ifnotchanceloot = {}
    dropper.randomloot = {}
    dropper.numrandomloot = 0
    dropper.chanceloottable = nil
    dropper.totalrandomweight = 0
    if dropper.GenerateLoot ~= nil then dropper.GenerateLoot = function() return {} end end
    if dropper.DropLoot ~= nil then dropper.DropLoot = function() end end
end

function KeiTaskBook:SpawnRefusedTaskTarget(prefab)
    local target = SpawnPrefab(prefab)
    if target == nil then return false end

    local x, y, z = GetTaskSummonPosition(self.inst)
    target.Transform:SetPosition(x, y, z)
    target.persists = false
    target.kei_task_refusal_summon = true
    target.kei_task_refusal_owner = self.inst
    DisableTaskSummonLoot(target)
    TaskSummon.PrepareSpecialTarget(target, self.inst, target)
    TaskSummon.StartTaskAggression(target, self.inst)
    target:DoTaskInTime(0, function(inst)
        TaskSummon.AggroTarget(inst, self.inst)
    end)

    local function RemoveTaskSummon()
        if target ~= nil and target:IsValid() then target:Remove() end
    end
    target.kei_task_refusal_owner_death_fn = RemoveTaskSummon
    target.kei_task_refusal_owner_remove_fn = RemoveTaskSummon
    target:ListenForEvent("death", RemoveTaskSummon, self.inst)
    target:ListenForEvent("onremove", RemoveTaskSummon, self.inst)
    target:ListenForEvent("onremove", function(inst)
        inst:RemoveEventCallback("death", RemoveTaskSummon, self.inst)
        inst:RemoveEventCallback("onremove", RemoveTaskSummon, self.inst)
        TaskSummon.CleanupSpecialTarget(inst)
    end)
    return true
end

function KeiTaskBook:RefuseTask(id)
    for index, task in ipairs(self.tasks) do
        if task.id == id and not task.completed and task.expires_day > GetWorldDay() then
            table.remove(self.tasks, index)
            if math.random() < .5 then
                if self:SpawnRefusedTaskTarget(task.target_prefab) then
                    local talker = self.inst.components ~= nil and self.inst.components.talker or nil
                    if talker ~= nil then
                        talker:Say("它好像生气了")
                    end
                end
            end
            self:SyncNetValues()
            self.inst:PushEvent("kei_taskbook_changed", { task_id = id, refused = true })
            return true
        end
    end
    return false
end

function KeiTaskBook:UpdateTaskVisual(prefab)
    local changed = false
    for _, task in ipairs(self.tasks) do
        if task.target_prefab == prefab and task.visual == nil then
            task.visual = TaskBook.GetTaskVisual(prefab)
            changed = task.visual ~= nil or changed
        end
    end
    if changed then
        self:SyncNetValues()
        self.inst:PushEvent("kei_taskbook_changed", { target_prefab = prefab })
    end
    return changed
end

function KeiTaskBook:MigrateTasks(version)
    local changed = false
    if version < 3 then
        for _, task in ipairs(self.tasks) do
            -- Version 3 replaces pre-generated exchanges with a player
            -- selected offer. Existing tasks remain, but need a new choice.
            task.offer = nil
            task.submit_prefab, task.submit_count = nil, nil
            task.reward_prefab, task.reward_count = nil, nil
            task.multiplier = nil
            changed = true
        end
    end
    if version < 4 then
        for _, task in ipairs(self.tasks) do
            task.loot = TaskBook.GetTargetLoot(task.target_prefab)
            changed = true
        end
    end
    if version < 5 then
        for _, task in ipairs(self.tasks) do
            task.offers = TaskBook.BuildTaskOffers(task)
            task.offer = task.offers ~= nil and task.offers[1] or nil
            changed = true
        end
    end
    if version < 6 then
        for _, task in ipairs(self.tasks) do
            if task.offers == nil or #task.offers == 0 then
                task.offers = TaskBook.BuildTaskOffers(task)
                task.offer = task.offers ~= nil and task.offers[1] or nil
                changed = true
            end
        end
    end
    if version < 7 then
        for _, task in ipairs(self.tasks) do
            task.visual = TaskBook.GetTaskVisual(task.target_prefab, task.visual)
            changed = true
        end
    end
    if version < 8 then
        for _, task in ipairs(self.tasks) do
            if task.visual == nil then task.visual = TaskBook.GetTaskVisual(task.target_prefab) end
            changed = true
        end
    end
    if version < 9 then
        for _, task in ipairs(self.tasks) do
            if #(task.loot or {}) == 1 then
                task.offers = TaskBook.BuildTaskOffers(task)
                task.offer = task.offers ~= nil and task.offers[1] or nil
                changed = true
            end
        end
    end
    if version < 10 then
        local unique_tasks, active_targets = {}, {}
        for _, task in ipairs(self.tasks) do
            if task.completed or not active_targets[task.target_prefab] then
                table.insert(unique_tasks, task)
                if not task.completed then active_targets[task.target_prefab] = true end
            else
                changed = true
            end
        end
        self.tasks = unique_tasks
    end
    if version < 11 then
        for _, task in ipairs(self.tasks) do
            if type(task.visual) == "table" and type(task.visual.facing) ~= "number" then
                task.visual.facing = 0
                changed = true
            end
        end
    end
    if version < 12 then
        for _, task in ipairs(self.tasks) do
            local rarity_data = TaskBook.TASK_RARITIES[task.rarity]
            if rarity_data ~= nil then
                task.expires_day = (tonumber(task.created_day) or 0) + rarity_data.lifetime_days
                changed = true
            end
        end
    end
    if version < 14 then
        local kept = {}
        for _, task in ipairs(self.tasks) do
            if task.completed then
                table.insert(kept, task)
            elseif task.offer ~= nil and TaskBook.IsTaskSubmitPrefab(task.offer.submit_prefab) then
                table.insert(kept, task)
            else
                task.offers = TaskBook.BuildTaskOffers(task)
                task.offer = task.offers ~= nil and task.offers[1] or nil
                if task.offer ~= nil then table.insert(kept, task) end
                changed = true
            end
        end
        self.tasks = kept
    end
    return changed
end

function KeiTaskBook:RecordProtocolData(data, prefab)
    local entry = TaskBook.NormalizeProtocolData(data, prefab)
    if entry == nil or not TaskBook.IsRecordableKind(entry.kind) or self.records[entry.id] then return false end
    self.records[entry.id] = true
    self:SyncNetValues()
    self.inst:PushEvent("kei_taskbook_changed", { id = entry.id })
    return true
end

function KeiTaskBook:RecordProtocolItem(item)
    return item ~= nil and item:HasTag("kei_protocol_cd") and self:RecordProtocolData(item.kei_protocol_data, item.prefab) or false
end

function KeiTaskBook:MarkImplanted(data, prefab)
    local entry = TaskBook.NormalizeProtocolData(data, prefab)
    if entry == nil or not TaskBook.IsRecordableKind(entry.kind) then return false end
    local changed = not self.records[entry.id] or not self.implanted[entry.id]
    self.records[entry.id] = true
    self.implanted[entry.id] = true
    if changed then
        self:SyncNetValues()
        self.inst:PushEvent("kei_taskbook_changed", { id = entry.id, implanted = true })
    end
    return changed
end

function KeiTaskBook:OnSave()
    return {
        records = self.records, implanted = self.implanted, tasks = self.tasks,
        task_serial = self.task_serial, last_generated_day = self.last_generated_day,
        last_blueprint_reward_day = self.last_blueprint_reward_day,
        task_version = self.task_version, completed_task_count = self.completed_task_count,
        claimed_task_milestones = self.claimed_task_milestones,
    }
end

function KeiTaskBook:OnLoad(data)
    self.records, self.implanted = {}, {}
    for id, value in pairs(data ~= nil and data.records or {}) do
        local kind = TaskBook.ParseId(id)
        if value and TaskBook.IsRecordableKind(kind) then self.records[id] = true end
    end
    for id, value in pairs(data ~= nil and data.implanted or {}) do
        local kind = TaskBook.ParseId(id)
        if value and TaskBook.IsRecordableKind(kind) then self.records[id], self.implanted[id] = true, true end
    end
    self.tasks = data ~= nil and data.tasks or {}
    self.task_serial = tonumber(data ~= nil and data.task_serial) or 0
    self.last_generated_day = tonumber(data ~= nil and data.last_generated_day) or -1
    self.last_blueprint_reward_day = tonumber(data ~= nil and data.last_blueprint_reward_day) or -1
    self.completed_task_count = math.max(0, tonumber(data ~= nil and data.completed_task_count) or 0)
    self.claimed_task_milestones = data ~= nil and data.claimed_task_milestones or {}
    local task_version = tonumber(data ~= nil and data.task_version) or 1
    self:MigrateTasks(task_version)
    self.task_version = TaskBook.TASK_VERSION
    self:SyncNetValues()
end

return KeiTaskBook
