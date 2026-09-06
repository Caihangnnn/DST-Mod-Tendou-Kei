local KeiTaskBookScreen = require("screens/kei_task_book_screen")

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

AddModRPCHandler("TendouKei", "SetKeiTaskBookSkin", function(player, skin_name)
    if player == nil
        or player.prefab ~= "kei"
        or player:HasTag("playerghost")
        or type(skin_name) ~= "string"
        or not KEI_TASK_BOOK_SKINS[skin_name]
        or player.components.skinner == nil
    then
        return
    end

    if player.components.skinner.skin_name ~= skin_name then
        player.components.skinner:SetSkinName(skin_name)
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
        if self.owner == nil or not self.owner:HasTag("kei") then
            return false
        end
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
