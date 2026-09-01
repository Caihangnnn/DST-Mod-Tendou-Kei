-- Give the Kei rotor wheel a second visual ring without replacing the vanilla
-- spellbook flow. Mouse selection still uses the widgets created by wheel.lua.

local OUTER_RING_OFFSET = 70

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

    local old_set_items = self.SetItems
    function self:SetItems(dataset, radius, focus_radius, dataset_name)
        old_set_items(self, dataset, radius, focus_radius, dataset_name)

        if HasRotorRingItems(dataset) then
            SetRotorRingPositions(dataset, radius, focus_radius)
        end
    end
end

AddClassPostConstruct("widgets/wheel", AddRotorWheelLayout)
