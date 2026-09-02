-- Give the Kei rotor wheel a second visual ring without replacing the vanilla
-- spellbook flow. Mouse selection still uses the widgets created by wheel.lua.

local OUTER_RING_OFFSET = 70
local ROTOR_CONTROLLER_TAG = "kei_rotor_survey_controller"
local ROTOR_WHEEL_CLOSE_TIME = 0.25

local function HasRotorRingItems(dataset)
    for _, item in ipairs(dataset or {}) do
        if item ~= nil and item.kei_rotor_ring ~= nil then
            return true
        end
    end
    return false
end

local function SetRotorRingPositions(dataset, radius, focus_radius)
    local rings = {}

    for _, item in ipairs(dataset or {}) do
        local ring = item.kei_rotor_ring
        if ring ~= nil then
            rings[ring] = rings[ring] or {}
            rings[ring][#rings[ring] + 1] = item
        end
    end

    for ring, items in pairs(rings) do
        local ring_radius = radius
        local ring_focus_radius = focus_radius

        if ring == 2 then
            ring_radius = radius + OUTER_RING_OFFSET
            ring_focus_radius = focus_radius + OUTER_RING_OFFSET
        end

        local cell_size_rad = TWOPI / #items
        for index, item in ipairs(items) do
            local angle = (index - 1) * cell_size_rad
            item.pos_dir = Vector3(math.sin(angle), math.cos(angle), 0)
            item.pos = item.pos_dir * ring_radius
            item.focus_pos = item.pos_dir * ring_focus_radius
        end
    end
end

local function AddRotorWheelLayout(self)
    if self.kei_rotor_wheel_patched then
        return
    end

    self.kei_rotor_wheel_patched = true

    local old_open = self.Open
    self.Open = function(wheel, ...)
        if wheel.kei_rotor_wheel_close_task ~= nil then
            wheel.kei_rotor_wheel_close_task:Cancel()
            wheel.kei_rotor_wheel_close_task = nil
            wheel.kei_rotor_wheel_closing = nil
        end
        return old_open(wheel, ...)
    end

    local old_close = self.Close
    self.Close = function(wheel, ...)
        local invobject = wheel.invobject
        if invobject == nil
            or not invobject:HasTag(ROTOR_CONTROLLER_TAG)
            or not wheel.isopen
        then
            return old_close(wheel, ...)
        end

        -- CloseSpellWheel can be requested more than once while the player
        -- state graph is changing. The first request owns the animation.
        if wheel.kei_rotor_wheel_closing then
            return
        end
        wheel.kei_rotor_wheel_closing = true
        wheel:StopUpdating()

        if wheel.cur_cell_index > 0 then
            if wheel.owner.HUD.last_focus == wheel.activeitems[wheel.cur_cell_index].widget then
                wheel.owner.HUD.last_focus = nil
            end
            wheel.activeitems[wheel.cur_cell_index].widget:ClearFocus()
            wheel.cur_cell_index = 0
        end

        local center = Vector3(0, 0, 0)
        for _, item in ipairs(wheel.activeitems) do
            if item.widget.cooldown then
                item.widget.cooldown:StopUpdating()
            end
            item.widget:CancelMoveTo()
            item.widget:MoveTo(item.widget:GetPosition(), center, ROTOR_WHEEL_CLOSE_TIME)
        end
        wheel.selected_label:CancelMoveTo()
        wheel.selected_label:SetString("")
        wheel:SetClickable(false)
        wheel:ClearFocus()
        wheel:Disable()
        wheel.isopen = false
        TheFrontEnd:LockFocus(false)

        wheel.kei_rotor_wheel_close_task = wheel.inst:DoTaskInTime(
            ROTOR_WHEEL_CLOSE_TIME,
            function()
                wheel.kei_rotor_wheel_close_task = nil
                wheel.kei_rotor_wheel_closing = nil
                for _, item in ipairs(wheel.activeitems or {}) do
                    item.widget:CancelMoveTo()
                    item.widget:Hide()
                end
                wheel:Hide()
            end
        )
    end

    local old_set_items = self.SetItems
    function self:SetItems(dataset, radius, focus_radius, dataset_name)
        old_set_items(self, dataset, radius, focus_radius, dataset_name)

        if HasRotorRingItems(dataset) then
            SetRotorRingPositions(dataset, radius, focus_radius)
        end
    end
end

AddClassPostConstruct("widgets/wheel", AddRotorWheelLayout)
