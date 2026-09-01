-- Klei IDs allowed to use the restricted Kei skin.
-- Keep IDs in the KU_xxx format assigned by Klei.
local DECAGRAMMATON_OWNERS = {
    -- ["KU_xxxxxxxxxxxxxxxxx"] = true,
}

local Ownership = {}

function Ownership.IsDecagrammatonOwned(user_id)
    return type(user_id) == "string" and DECAGRAMMATON_OWNERS[user_id] == true
end

return Ownership
