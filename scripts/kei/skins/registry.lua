local SKIN_AFFINITY_INFO = require("skin_affinity_info")

local function InsertUnique(list, value)
    for _, existing in ipairs(list) do
        if existing == value then
            return
        end
    end
    table.insert(list, value)
end

local function RegisterKeiSkin(skin_name)
    PREFAB_SKINS.kei = PREFAB_SKINS.kei or {}
    InsertUnique(PREFAB_SKINS.kei, skin_name)

    SKIN_AFFINITY_INFO.kei = SKIN_AFFINITY_INFO.kei or {}
    InsertUnique(SKIN_AFFINITY_INFO.kei, skin_name)
end

return RegisterKeiSkin
