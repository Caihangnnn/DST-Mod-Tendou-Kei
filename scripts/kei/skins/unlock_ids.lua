-- Klei user IDs permitted to use restricted Kei skins.
-- Add IDs in the KU_xxx format reported by TheNet:GetUserID().
local LISTS = {
    all = {
    },
    kei_skin_decagrammaton = {
    },
}

local MAP = {}
for skin_name, user_ids in pairs(LISTS) do
    MAP[skin_name] = {}
    for _, user_id in ipairs(user_ids) do
        MAP[skin_name][user_id] = true
    end
end

local function IsUnlocked(skin_name, user_id)
    return user_id ~= nil
        and ((MAP.all ~= nil and MAP.all[user_id])
            or (MAP[skin_name] ~= nil and MAP[skin_name][user_id]))
        or false
end

return {
    IsUnlocked = IsUnlocked,
}

