local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"
local StatusBadgeHelpers = require "widgets/kei_statusbadge_helpers"

local POWER_TINT = { 255 / 255, 203 / 255, 229 / 255, 1 }
local PULSE_GAIN_COLOUR = { 120 / 255, 255 / 255, 170 / 255, 0.6 }
local PULSE_LOSS_COLOUR = { 255 / 255, 92 / 255, 155 / 255, 0.6 }

local function ApplyMeterBuild(self)
    self.backing:GetAnimState():OverrideSymbol("bg", "kei_status_power_meter", "bg")
    self.circleframe:GetAnimState():OverrideSymbol("frame_circle", "kei_status_power_meter", "frame_circle")
end

local KeiPowerBadge = Class(Badge, function(self, owner)
    Badge._ctor(self, nil, owner, POWER_TINT, "kei_status_power", nil, nil, true)
    self.pulse:GetAnimState():SetMultColour(unpack(PULSE_LOSS_COLOUR))
    self.warning:GetAnimState():SetMultColour(unpack(PULSE_LOSS_COLOUR))
    ApplyMeterBuild(self)
    self.circleframe:GetAnimState():OverrideSymbol("icon", "kei_status_power", "icon")

    self.hungerarrow = self.underNumber:AddChild(UIAnim())
    self.hungerarrow:GetAnimState():SetBank("sanity_arrow")
    self.hungerarrow:GetAnimState():SetBuild("sanity_arrow")
    self.hungerarrow:GetAnimState():PlayAnimation("neutral")
    self.hungerarrow:SetClickable(false)
    self.hungerarrow:GetAnimState():AnimateWhilePaused(false)

    self:StartUpdating()
end)

function KeiPowerBadge:OnUpdate(dt)
    if TheNet:IsServerPaused() then
        return
    end

    local anim = "neutral"
    local hunger = self.owner and self.owner.replica.hunger
    if hunger then
        local gain, drain
        if self.owner:HasTag("wintersfeastbuff") then
            gain = true
        else
            if self.owner:HasTag("hungerregenbuff") then
                gain = true
            end

            if self.owner:HasAnyTag("sleeping", "swimming_floater", "wonkey_run", "gallop_run")
                or (self.owner.sg and self.owner.sg:HasAnyStateTag("floating_predict_move", "monkey_predict_run", "gallop_predict_run"))
            then
                drain = true
            end
        end

        if gain and drain then
            local tick = GetTick()
            if self.tracking == nil then
                self.tracking =
                {
                    i1 = 1,
                    i2 = 1,
                    t = tick,
                    history = { hunger:GetPercent() },
                }
            elseif self.tracking.t ~= tick then
                local maxn = 150
                self.tracking.i2 = (self.tracking.i2 % maxn) + 1
                if self.tracking.i2 == self.tracking.i1 then
                    self.tracking.i1 = (self.tracking.i1 % maxn) + 1
                end
                self.tracking.history[self.tracking.i2] = hunger:GetPercent()
                self.tracking.t = tick
            end
            local pct1 = self.tracking.history[self.tracking.i1]
            local pct2 = self.tracking.history[self.tracking.i2]
            if pct1 > pct2 then
                gain = false
            elseif pct1 < pct2 then
                drain = false
            else
                gain, drain = false, false
            end
        else
            self.tracking = nil
        end

        if gain then
            if hunger:GetPercent() < 1 then
                anim = "arrow_loop_increase"
            end
        elseif drain and hunger:GetPercent() > 0 then
            anim = "arrow_loop_decrease"
        end
    end

    if self.arrowdir ~= anim then
        self.arrowdir = anim
        self.hungerarrow:GetAnimState():PlayAnimation(anim, true)
    end
end

function KeiPowerBadge:PulseGreen()
    StatusBadgeHelpers.PlayPulse(self, PULSE_GAIN_COLOUR, PULSE_LOSS_COLOUR, 3)
end

function KeiPowerBadge:PulseRed()
    StatusBadgeHelpers.PlayPulse(self, PULSE_LOSS_COLOUR, PULSE_LOSS_COLOUR, 1)
end

function KeiPowerBadge:StartWarning(r, g, b, a)
    StatusBadgeHelpers.StartWarning(self, Badge, PULSE_LOSS_COLOUR)
end

return KeiPowerBadge
