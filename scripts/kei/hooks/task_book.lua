local KeiTaskBookScreen = require("screens/kei_task_book_screen")
local SkinOwnership = require("kei/skins/ownership")

AddPopup("KEI_TASK_BOOK")

AddModRPCHandler("TendouKei", "SubmitTask", function(player, task_id)
    if player ~= nil and player.prefab == "kei" and type(task_id) == "string"
        and player.components.kei_taskbook ~= nil
    then
        player.components.kei_taskbook:SubmitTask(task_id)
    end
end)

AddModRPCHandler("TendouKei", "SetTaskShares", function(player, task_id, shares)
    if player ~= nil and player.prefab == "kei" and type(task_id) == "string"
        and player.components.kei_taskbook ~= nil
    then
        player.components.kei_taskbook:SetTaskShares(task_id, shares)
    end
end)

AddModRPCHandler("TendouKei", "RefuseTask", function(player, task_id)
    if player ~= nil and player.prefab == "kei" and type(task_id) == "string"
        and player.components.kei_taskbook ~= nil
    then
        player.components.kei_taskbook:RefuseTask(task_id)
    end
end)

-- The task book only exposes the two Kei base skins. Keep the allow-list on
-- the server so the client cannot request an arbitrary skin name.
local KEI_TASK_BOOK_SKINS = {
    kei_none = true,
    kei_skin_decagrammaton = true,
}

local function IsTaskBookSkinAllowed(player, skin_name)
    if skin_name == "kei_skin_decagrammaton" then
        return SkinOwnership.IsDecagrammatonOwned(player.userid)
    end
    return true
end

local function EnforceSkinOwnership(player)
    if player == nil
        or player.prefab ~= "kei"
        or player.components == nil
        or player.components.skinner == nil
        or player.components.skinner.skin_name ~= "kei_skin_decagrammaton"
    then
        return
    end

    if not SkinOwnership.IsDecagrammatonOwned(player.userid) then
        player.components.skinner:SetSkinName("kei_none")
    end
end

AddModRPCHandler("TendouKei", "SetKeiTaskBookSkin", function(player, skin_name)
    if player == nil
        or player.prefab ~= "kei"
        or player:HasTag("playerghost")
        or type(skin_name) ~= "string"
        or not KEI_TASK_BOOK_SKINS[skin_name]
        or not IsTaskBookSkinAllowed(player, skin_name)
        or player.components.skinner == nil
    then
        return
    end

    if player.components.skinner.skin_name ~= skin_name then
        player.components.skinner:SetSkinName(skin_name)
    end
end)

-- Also clean up a restricted skin restored from an old save or selected before
-- the ownership list was changed.
AddSimPostInit(function()
    local world = TheWorld
    if world == nil or not world.ismastersim then
        return
    end

    local function OnPlayerJoined(_, player)
        EnforceSkinOwnership(player)
    end

    world:ListenForEvent("ms_playerjoined", OnPlayerJoined)
    for _, player in ipairs(AllPlayers or {}) do
        EnforceSkinOwnership(player)
    end
end)

POPUPS.KEI_TASK_BOOK.fn = function(inst, show)
    if inst.HUD == nil then return end
    if not show then
        inst.HUD:CloseKeiTaskBookScreen()
    elseif not inst.HUD:OpenKeiTaskBookScreen() then
        POPUPS.KEI_TASK_BOOK:Close(inst)
    end
end

AddClassPostConstruct("screens/playerhud", function(self)
    function self:OpenKeiTaskBookScreen()
        self:CloseKeiTaskBookScreen()
        self.kei_taskbookscreen = KeiTaskBookScreen(self.owner)
        self:OpenScreenUnderPause(self.kei_taskbookscreen)
        return true
    end

    function self:CloseKeiTaskBookScreen()
        if self.kei_taskbookscreen ~= nil then
            if self.kei_taskbookscreen.inst:IsValid() then
                TheFrontEnd:PopScreen(self.kei_taskbookscreen)
            end
            self.kei_taskbookscreen = nil
        end
    end
end)
