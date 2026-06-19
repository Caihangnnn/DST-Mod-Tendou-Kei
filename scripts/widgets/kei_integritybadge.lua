local Badge = require "widgets/badge"
local HealthBadge = require "widgets/healthbadge"
local StatusBadgeHelpers = require "widgets/kei_statusbadge_helpers"

local INTEGRITY_TINT = { 255 / 255, 234 / 255, 56 / 255, 1 }
local PULSE_GAIN_COLOUR = { 120 / 255, 255 / 255, 170 / 255, 0.6 }
local PULSE_LOSS_COLOUR = { 255 / 255, 92 / 255, 155 / 255, 0.6 }

local function ApplyMeterBuild(self)
    self.backing:GetAnimState():OverrideSymbol("bg", "kei_status_integrity_meter", "bg")
    self.circleframe:GetAnimState():OverrideSymbol("frame_circle", "kei_status_integrity_meter", "frame_circle")
    self.circleframe2:GetAnimState():OverrideSymbol("frame_circle", "kei_status_integrity_meter", "frame_circle")
end

local function KeiIntegrityBadge(owner)
    local badge = HealthBadge(owner, nil, "status_abigail")
    badge.pulse:GetAnimState():SetMultColour(unpack(PULSE_LOSS_COLOUR))
    badge.warning:GetAnimState():SetMultColour(unpack(PULSE_LOSS_COLOUR))
    ApplyMeterBuild(badge)
    badge.anim:GetAnimState():SetMultColour(unpack(INTEGRITY_TINT))
    badge.circleframe:GetAnimState():OverrideSymbol("icon", "kei_status_integrity", "icon")

    badge.PulseGreen = function(self)
        StatusBadgeHelpers.PlayPulse(self, PULSE_GAIN_COLOUR, PULSE_LOSS_COLOUR, 3)
    end

    badge.PulseRed = function(self)
        StatusBadgeHelpers.PlayPulse(self, PULSE_LOSS_COLOUR, PULSE_LOSS_COLOUR, 1)
    end

    badge.StartWarning = function(self, r, g, b, a)
        StatusBadgeHelpers.StartWarning(self, Badge, PULSE_LOSS_COLOUR)
    end

    return badge
end

return KeiIntegrityBadge
