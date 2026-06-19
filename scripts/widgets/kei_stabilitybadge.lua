local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"

local STABILITY_TINT = { 32 / 255, 216 / 255, 238 / 255, 1 }
local PULSE_GAIN_COLOUR = { 120 / 255, 255 / 255, 170 / 255, 0.6 }
local PULSE_LOSS_COLOUR = { 255 / 255, 92 / 255, 155 / 255, 0.6 }

local function ApplyMeterBuild(self)
    self.backing:GetAnimState():OverrideSymbol("bg", "kei_status_stability_meter", "bg")
    self.circleframe:GetAnimState():OverrideSymbol("frame_circle", "kei_status_stability_meter", "frame_circle")
end

local function PlayStatusPulse(self, colour, speed)
    speed = speed or 1
    if self.kei_status_pulse_task ~= nil then
        self.kei_status_pulse_task:Cancel()
        self.kei_status_pulse_task = nil
    end

    self.warning:GetAnimState():SetDeltaTimeMultiplier(speed)
    self.warning:GetAnimState():SetMultColour(unpack(colour))
    self.warning:Show()
    self.warning:GetAnimState():PlayAnimation("pulse")

    local duration = self.warning:GetAnimState():GetCurrentAnimationLength() / speed
    self.kei_status_pulse_task = self.inst:DoTaskInTime(duration, function()
        self.kei_status_pulse_task = nil
        self.warning:GetAnimState():SetDeltaTimeMultiplier(1)
        if self.warningstarted then
            self.warning:GetAnimState():SetMultColour(unpack(PULSE_LOSS_COLOUR))
            self.warning:GetAnimState():PlayAnimation("pulse", true)
        else
            self.warning:Hide()
        end
    end)
end

local INCREASE_RATE_SCALE_ANIM =
{
    [RATE_SCALE.INCREASE_HIGH] = "arrow_loop_increase_most",
    [RATE_SCALE.INCREASE_MED]  = "arrow_loop_increase_more",
    [RATE_SCALE.INCREASE_LOW]  = "arrow_loop_increase",
}

local DECREASE_RATE_SCALE_ANIM =
{
    [RATE_SCALE.DECREASE_HIGH] = "arrow_loop_decrease_most",
    [RATE_SCALE.DECREASE_MED]  = "arrow_loop_decrease_more",
    [RATE_SCALE.DECREASE_LOW]  = "arrow_loop_decrease",
}

local KeiStabilityBadge = Class(Badge, function(self, owner)
    Badge._ctor(self, nil, owner, STABILITY_TINT, "kei_status_stability", nil, nil, true)
    self.pulse:GetAnimState():SetMultColour(unpack(PULSE_LOSS_COLOUR))
    self.warning:GetAnimState():SetMultColour(unpack(PULSE_LOSS_COLOUR))
    ApplyMeterBuild(self)
    self.circleframe:GetAnimState():OverrideSymbol("icon", "kei_status_stability", "icon")

    self.topperanim = self.underNumber:AddChild(UIAnim())
    self.topperanim:GetAnimState():SetBank("status_meter")
    self.topperanim:GetAnimState():SetBuild("status_meter")
    self.topperanim:GetAnimState():PlayAnimation("anim")
    self.topperanim:GetAnimState():AnimateWhilePaused(false)
    self.topperanim:GetAnimState():SetMultColour(0, 0, 0, 1)
    self.topperanim:SetScale(1, -1, 1)
    self.topperanim:SetClickable(false)
    self.topperanim:GetAnimState():SetPercent("anim", 1)

    self.sanityarrow = self.underNumber:AddChild(UIAnim())
    self.sanityarrow:GetAnimState():SetBank("sanity_arrow")
    self.sanityarrow:GetAnimState():SetBuild("sanity_arrow")
    self.sanityarrow:GetAnimState():PlayAnimation("neutral")
    self.sanityarrow:GetAnimState():AnimateWhilePaused(false)
    self.sanityarrow:SetClickable(false)

    self.val = 100
    self.max = 100
    self.penaltypercent = 0

    self:StartUpdating()
end)

function KeiStabilityBadge:SetPercent(val, max, penaltypercent)
    self.val = val
    self.max = max
    Badge.SetPercent(self, self.val, self.max)

    self.penaltypercent = penaltypercent or 0
    self.topperanim:GetAnimState():SetPercent("anim", 1 - self.penaltypercent)
end

function KeiStabilityBadge:OnUpdate(dt)
    if TheNet:IsServerPaused() then
        return
    end

    local sanity = self.owner.replica.sanity
    local anim = "neutral"

    if sanity ~= nil then
        if self.owner:HasTag("sleeping") then
            if sanity:GetPercentWithPenalty() < 1 then
                local rate = TUNING.SLEEP_SANITY_PER_TICK / TUNING.SLEEP_TICK_PERIOD
                local ratescale =
                    (rate > .2 and RATE_SCALE.INCREASE_HIGH) or
                    (rate > .1 and RATE_SCALE.INCREASE_MED) or
                    (rate > .01 and RATE_SCALE.INCREASE_LOW) or
                    RATE_SCALE.NEUTRAL

                anim = INCREASE_RATE_SCALE_ANIM[ratescale]
            end
        else
            local ratescale = sanity:GetRateScale()

            if INCREASE_RATE_SCALE_ANIM[ratescale] then
                if sanity:GetPercentWithPenalty() < 1 then
                    anim = INCREASE_RATE_SCALE_ANIM[ratescale]
                end
            elseif DECREASE_RATE_SCALE_ANIM[ratescale] then
                if sanity:GetPercentWithPenalty() > 0 then
                    anim = DECREASE_RATE_SCALE_ANIM[ratescale]
                end
            end
        end
    end

    if self.arrowdir ~= anim then
        self.arrowdir = anim
        self.sanityarrow:GetAnimState():PlayAnimation(anim, true)
    end
end

function KeiStabilityBadge:PulseGreen()
    PlayStatusPulse(self, PULSE_GAIN_COLOUR, 3)
end

function KeiStabilityBadge:PulseRed()
    PlayStatusPulse(self, PULSE_LOSS_COLOUR, 1)
end

function KeiStabilityBadge:StartWarning(r, g, b, a)
    if self.kei_status_pulse_task ~= nil then
        self.kei_status_pulse_task:Cancel()
        self.kei_status_pulse_task = nil
    end
    self.warning:GetAnimState():SetDeltaTimeMultiplier(1)
    Badge.StartWarning(self, unpack(PULSE_LOSS_COLOUR))
end

return KeiStabilityBadge
