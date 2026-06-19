local StatusBadgeHelpers = {}

local function CancelStatusPulse(self)
    if self.kei_status_pulse_task ~= nil then
        self.kei_status_pulse_task:Cancel()
        self.kei_status_pulse_task = nil
    end
end

function StatusBadgeHelpers.PlayPulse(self, colour, warning_colour, speed)
    speed = speed or 1
    CancelStatusPulse(self)

    self.warning:GetAnimState():SetDeltaTimeMultiplier(speed)
    self.warning:GetAnimState():SetMultColour(unpack(colour))
    self.warning:Show()
    self.warning:GetAnimState():PlayAnimation("pulse")

    local duration = self.warning:GetAnimState():GetCurrentAnimationLength() / speed
    self.kei_status_pulse_task = self.inst:DoTaskInTime(duration, function()
        self.kei_status_pulse_task = nil
        self.warning:GetAnimState():SetDeltaTimeMultiplier(1)
        if self.warningstarted then
            self.warning:GetAnimState():SetMultColour(unpack(warning_colour))
            self.warning:GetAnimState():PlayAnimation("pulse", true)
        else
            self.warning:Hide()
        end
    end)
end

function StatusBadgeHelpers.StartWarning(self, Badge, warning_colour)
    CancelStatusPulse(self)
    self.warning:GetAnimState():SetDeltaTimeMultiplier(1)
    Badge.StartWarning(self, unpack(warning_colour))
end

return StatusBadgeHelpers
