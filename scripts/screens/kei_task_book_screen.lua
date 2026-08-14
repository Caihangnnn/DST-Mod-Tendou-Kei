local Screen = require "widgets/screen"
local Widget = require "widgets/widget"
local ImageButton = require "widgets/imagebutton"
local KeiTaskBookWidget = require "widgets/kei_task_book_widget"

local TASK_BOOK_UI_SAVE_KEY = "tendou_kei_task_book_ui"

local function GetSavedTab(owner)
    return owner ~= nil and owner._kei_taskbook_selected_tab or 1
end

local function LoadSavedTab(screen)
    TheSim:GetPersistentString(TASK_BOOK_UI_SAVE_KEY, function(success, data)
        if not success or data == nil or screen == nil or not screen.inst:IsValid() then
            return
        end

        local ok, saved = pcall(json.decode, data)
        local tab = ok and saved ~= nil and tonumber(saved.tab) or nil
        if tab ~= nil and screen.book ~= nil and screen.book.inst:IsValid() then
            screen.book:SelectTab(tab)
        end
    end)
end

local KeiTaskBookScreen = Class(Screen, function(self, owner)
    self.owner = owner
    Screen._ctor(self, "KeiTaskBookScreen")

    local black = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    black.image:SetVRegPoint(ANCHOR_MIDDLE)
    black.image:SetHRegPoint(ANCHOR_MIDDLE)
    black.image:SetVAnchor(ANCHOR_MIDDLE)
    black.image:SetHAnchor(ANCHOR_MIDDLE)
    black.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    black.image:SetTint(0, 0, 0, .5)
    black:SetOnClick(function() TheFrontEnd:PopScreen() end)
    black:SetHelpTextMessage("")

    local root = self:AddChild(Widget("root"))
    root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    root:SetHAnchor(ANCHOR_MIDDLE)
    root:SetVAnchor(ANCHOR_MIDDLE)
    root:SetPosition(0, -25)
    self.book = root:AddChild(KeiTaskBookWidget(owner, GetSavedTab(owner)))
    self.default_focus = self.book
    SetAutopaused(true)
    LoadSavedTab(self)
end)

function KeiTaskBookScreen:OnDestroy()
    SetAutopaused(false)
    local selected_tab = self.book ~= nil and self.book.selected_tab or GetSavedTab(self.owner)
    TheSim:SetPersistentString(TASK_BOOK_UI_SAVE_KEY, json.encode({ tab = selected_tab }), false)
    POPUPS.KEI_TASK_BOOK:Close(self.owner)
    KeiTaskBookScreen._base.OnDestroy(self)
end

function KeiTaskBookScreen:OnControl(control, down)
    if KeiTaskBookScreen._base.OnControl(self, control, down) then return true end
    if not down and (control == CONTROL_MENU_BACK or control == CONTROL_CANCEL) then
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        TheFrontEnd:PopScreen()
        return true
    end
    return false
end

return KeiTaskBookScreen
