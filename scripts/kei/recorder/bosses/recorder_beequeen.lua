local RecorderBeeQueen = {}

local function RemoveEntities(source, field)
    local entities = source[field]
    if entities == nil then
        return
    end

    source[field] = nil
    for _, entity in ipairs(entities) do
        if entity ~= nil and entity:IsValid() then
            entity:Remove()
        end
    end
end

function RecorderBeeQueen.Remove(target)
    if target == nil then
        return
    end

    local source = target.kei_recorder_source
    if source == nil then
        return
    end

    -- Remove guards before trails so no guard death event can leave a new trail
    -- behind while the recorder is being stopped.
    RemoveEntities(source, "kei_recorder_beeguards")
    RemoveEntities(source, "kei_recorder_green_honey_trails")
end

return RecorderBeeQueen
