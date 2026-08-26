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
