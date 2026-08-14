local KeiTaskBookScreen = require("screens/kei_task_book_screen")

AddPopup("KEI_TASK_BOOK")

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

local function IsTaskBookAction(action)
    local item = action ~= nil and (action.invobject or action.target) or nil
    return item ~= nil and item:HasTag("kei_task_book")
end

local function GetReadState(inst, action, is_client)
    if IsTaskBookAction(action) then return "kei_taskbook_open" end
    if is_client then
        return action.invobject ~= nil and action.invobject:HasTag("simplebook") and "cookbook_open"
            or inst:HasTag("aspiring_bookworm") and "book_peruse"
            or "book"
    end
    return action.invobject ~= nil and action.invobject.components.simplebook ~= nil and "cookbook_open"
        or inst.components.reader ~= nil and inst.components.reader:IsAspiringBookworm() and "book_peruse"
        or "book"
end

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.READ, function(inst, action)
    return GetReadState(inst, action, false)
end))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.READ, function(inst, action)
    return GetReadState(inst, action, true)
end))

AddStategraphState("wilson", State{
    name = "kei_taskbook_open",
    tags = { "doing", "busy" },
    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.AnimState:OverrideSymbol("book_cook", "cookbook", "book_cook")
        inst.AnimState:PlayAnimation("action_uniqueitem_pre")
        inst.AnimState:PushAnimation("reading_in", false)
        inst.AnimState:PushAnimation("reading_loop", true)
    end,
    timeline = {
        TimeEvent(8 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
            inst:PerformBufferedAction()
        end),
    },
    events = {
        EventHandler("ms_closepopup", function(inst, data)
            if data.popup == POPUPS.KEI_TASK_BOOK then
                inst.sg:GoToState("kei_taskbook_close")
            end
        end),
    },
    onexit = function(inst)
        inst:ShowPopUp(POPUPS.KEI_TASK_BOOK, false)
    end,
})

AddStategraphState("wilson", State{
    name = "kei_taskbook_close",
    tags = { "idle", "nodangle" },
    onenter = function(inst)
        inst.components.locomotor:StopMoving()
        inst.AnimState:PlayAnimation("reading_pst")
        inst.sg:SetTimeout(inst.AnimState:GetCurrentAnimationLength())
    end,
    ontimeout = function(inst)
        inst:ClearBufferedAction()
        inst.sg:GoToState("idle")
    end,
})

AddStategraphState("wilson_client", State{
    name = "kei_taskbook_open",
    server_states = { "kei_taskbook_open" },
    forward_server_states = true,
    onenter = function(inst)
        inst.sg:GoToState("action_uniqueitem_busy")
    end,
})
