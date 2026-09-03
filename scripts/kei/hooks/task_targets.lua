local TaskBook = require("kei/task_book")

-- Explicit compatibility path for creature prefabs that intentionally use
-- custom tags or are never spawned before task generation.
TENDOU_KEI_API.RegisterTaskTarget = function(prefab, rarity)
    return TaskBook.RegisterTaskTarget(prefab, rarity)
end

TENDOU_KEI_API.GetExcludedTaskTargets = function()
    return TaskBook.GetExcludedTaskTargets()
end

local IDLE_ANIMS = { "anim", "idle", "idle_loop", "idle1", "idle2", "idle3", "idle4" }

local function GetCreatureVisual(inst)
    if inst == nil or inst.AnimState == nil then return nil end
    local anim
    for _, candidate in ipairs(IDLE_ANIMS) do
        if inst.AnimState:IsCurrentAnimation(candidate) then anim = candidate break end
    end
    anim = anim or "idle_loop"
    local ok, bank, build, facing = pcall(function()
        return inst.AnimState:GetBankHash(), inst.AnimState:GetBuild(), inst.AnimState:GetCurrentFacing()
    end)
    return ok and type(bank) == "number" and type(build) == "string" and {
        bank = bank, build = build, facing = type(facing) == "number" and facing or 0, anim = anim,
    } or nil
end

local function RefreshTaskBooks(prefab)
    for _, player in ipairs(AllPlayers or {}) do
        local taskbook = player.components ~= nil and player.components.kei_taskbook or nil
        if taskbook ~= nil then
            taskbook:UpdateTaskVisual(prefab)
            if #taskbook.tasks == 0 and taskbook.waiting_for_task_targets then
                taskbook:RefreshDailyTasks()
            end
        end
    end
end

-- Record actual loaded creatures instead of instantiating all Prefabs. Tags
-- classify giants and ordinary fauna, while the live entity supplies its
-- battle-modified loot and visual animation data.
AddPrefabPostInitAny(function(inst)
    if not TheWorld.ismastersim or inst == nil or inst.components == nil then return end
    local is_giant = inst:HasTag("epic")
    if not is_giant and not (inst:HasTag("monster") or inst:HasTag("animal")
        or inst:HasTag("smallcreature") or inst:HasTag("largecreature")) then return end
    local dropper = inst.components.lootdropper
    if dropper == nil then return end
    local rarity = is_giant and 3 or (inst:HasTag("largecreature") and 2 or 1)
    inst:DoTaskInTime(0, function()
        if inst:IsValid() and TaskBook.RegisterTaskTarget(inst.prefab, rarity,
            TaskBook.GetLootdropperLoot(dropper), GetCreatureVisual(inst)) then
            RefreshTaskBooks(inst.prefab)
        end
    end)
end)
