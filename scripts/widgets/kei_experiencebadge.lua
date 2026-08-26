-- Experience badge shown beside Kei's three base status meters.

local Widget = require("widgets/widget")
local UIAnim = require("widgets/uianim")
local Text = require("widgets/text")
local ImageButton = require("widgets/imagebutton")

local EXPERIENCE_ICON_HITBOX_SIZE = 64

local KeiExperienceBadge = Class(Widget, function(self, owner)
    Widget._ctor(self, "KeiExperienceBadge")
    self.owner = owner
    self.is_full = nil
    self.current = 0
    self.max = 1000
    self.total = 0

    self.icon = self:AddChild(UIAnim())
    self.icon:GetAnimState():SetBank("kei_exp_bank")
    self.icon:GetAnimState():SetBuild("kei_exp")
    self.icon:GetAnimState():PlayAnimation("exp_unfilled", true)
    self.icon:GetAnimState():AnimateWhilePaused(false)
    self.icon:SetScale(0.8, 0.8, 0.8)
    self.icon:SetClickable(true)
    local announce_on_mouse_button = function(_, button, down)
        if button == MOUSEBUTTON_LEFT and down then
            self:AnnounceExperience()
            return true
        end
        return false
    end
    self.icon.OnMouseButton = announce_on_mouse_button

    -- UIAnim hit testing follows the visible line art. Overlay a transparent
    -- square so the full icon bounds are consistently clickable.
    self.icon_hitbox = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.icon_hitbox:SetNormalScale(1)
    self.icon_hitbox:SetFocusScale(1)
    self.icon_hitbox.scale_on_focus = false
    self.icon_hitbox:ForceImageSize(EXPERIENCE_ICON_HITBOX_SIZE, EXPERIENCE_ICON_HITBOX_SIZE)
    self.icon_hitbox.image:SetTint(1, 1, 1, 0)
    self.icon_hitbox:SetOnClick(function() self:AnnounceExperience() end)

    self.total_value = self:AddChild(Text(NUMBERFONT, 18))
    self.total_value:SetHAlign(ANCHOR_MIDDLE)
    self.total_value:SetPosition(0, 35, 0)
    self.total_value:SetString("0")
    self.total_value:SetClickable(true)
    self.total_value.OnMouseButton = announce_on_mouse_button

    self.value = self:AddChild(Text(NUMBERFONT, 22))
    self.value:SetHAlign(ANCHOR_MIDDLE)
    self.value:SetPosition(0, -37, 0)
    self.value:SetString("0/1000")
    self.value:SetClickable(true)
    self.value.OnMouseButton = announce_on_mouse_button

    self:SetTooltip(STRINGS.UI.KEI_EXPERIENCE or "Experience")
end)

local function FormatValue(value)
    if math.abs(value - math.floor(value + 0.5)) < 0.001 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%.1f", value)
end

function KeiExperienceBadge:SetValues(current, max, total)
    current = tonumber(current) or 0
    max = tonumber(max) or 0
    total = tonumber(total) or 0
    self.current = current
    self.max = max
    self.total = total
    local is_full = max > 0 and current >= max
    if self.is_full ~= is_full then
        self.is_full = is_full
        self.icon:GetAnimState():PlayAnimation(is_full and "exp_full" or "exp_unfilled", true)
    end
    self.total_value:SetString(FormatValue(total))
    self.value:SetString(FormatValue(current) .. "/" .. FormatValue(max))
end

function KeiExperienceBadge:AnnounceExperience()
    local message = string.format(
        "神秘：%s/%s",
        FormatValue(self.current),
        FormatValue(self.max)
    )

    -- This is a client-side UI action, so send a real chat message instead of
    -- calling the server-side talker component.
    if TheNet ~= nil and TheNet.Say ~= nil then
        TheNet:Say(message, false)
    end
end

return KeiExperienceBadge
