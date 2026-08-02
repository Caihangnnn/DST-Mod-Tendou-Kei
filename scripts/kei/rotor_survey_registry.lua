-- 旋翼调查仪无人机登记表：按玩家 userid 索引专属无人机，避免全世界搜索。
local Registry = {}

local function GetEntries()
    if TheWorld == nil then
        return nil
    end

    if TheWorld._kei_rotor_survey_drones == nil then
        TheWorld._kei_rotor_survey_drones = {}
    end

    return TheWorld._kei_rotor_survey_drones
end

local function GetControllers()
    if TheWorld == nil then
        return nil
    end

    if TheWorld._kei_rotor_survey_controllers == nil then
        TheWorld._kei_rotor_survey_controllers = {}
    end

    return TheWorld._kei_rotor_survey_controllers
end

function Registry.Register(drone, userid)
    if drone == nil or userid == nil then
        return
    end

    local previous_userid = drone._kei_drone_owner_userid
    if previous_userid ~= nil and previous_userid ~= userid then
        Registry.Unregister(drone, previous_userid)
    end

    local entries = GetEntries()
    if entries == nil then
        return
    end

    local owned = entries[userid]
    if owned == nil then
        owned = {}
        entries[userid] = owned
    end

    owned[drone] = true
    drone._kei_drone_owner_userid = userid
    if drone._kei_drone_owner_userid_net ~= nil then
        drone._kei_drone_owner_userid_net:set(userid)
    end
end

function Registry.Unregister(drone, userid)
    if drone == nil then
        return
    end

    userid = userid or drone._kei_drone_owner_userid
    local entries = GetEntries()
    local owned = entries ~= nil and userid ~= nil and entries[userid] or nil
    if owned ~= nil then
        owned[drone] = nil

        if next(owned) == nil then
            entries[userid] = nil
        end
    end
end

function Registry.Find(userid, predicate)
    if userid == nil then
        return nil
    end

    local entries = GetEntries()
    local owned = entries ~= nil and entries[userid] or nil
    if owned == nil then
        return nil
    end

    for drone in pairs(owned) do
        if drone ~= nil and drone:IsValid()
            and (predicate == nil or predicate(drone))
        then
            return drone
        end

        owned[drone] = nil
    end

    if next(owned) == nil then
        entries[userid] = nil
    end

    return nil
end

-- 控制器与无人机分别登记；控制器需要在重载后仍保持每名玩家唯一。
function Registry.RegisterController(controller, userid)
    if controller == nil or userid == nil then
        return
    end

    local entries = GetControllers()
    if entries == nil then
        return
    end

    local previous = entries[userid]
    if previous ~= nil and previous ~= controller and previous:IsValid() then
        previous:Remove()
    end

    entries[userid] = controller
    controller._kei_controller_owner_userid = userid
end

function Registry.UnregisterController(controller, userid)
    if controller == nil then
        return
    end

    userid = userid or controller._kei_controller_owner_userid
    local entries = GetControllers()
    if entries ~= nil and userid ~= nil and entries[userid] == controller then
        entries[userid] = nil
    end
end

function Registry.FindController(userid)
    if userid == nil then
        return nil
    end

    local entries = GetControllers()
    local controller = entries ~= nil and entries[userid] or nil
    if controller ~= nil and controller:IsValid() then
        return controller
    end
    if entries ~= nil then
        entries[userid] = nil
    end
    return nil
end

local function IsController(item)
    return item ~= nil
        and item.HasTag ~= nil
        and item:HasTag("kei_rotor_survey_controller")
end

local function FindControllerInContainer(container)
    if container == nil or container.GetNumSlots == nil or container.GetItemInSlot == nil then
        return nil
    end

    for slot = 1, container:GetNumSlots() do
        local item = container:GetItemInSlot(slot)
        if IsController(item) then
            return item
        end
    end
end

-- 查找玩家主物品栏及娇小爱丽丝中的控制器。该函数同时兼容服务端组件和客户端 replica。
function Registry.FindControllerInOwner(owner)
    if owner == nil then
        return nil
    end

    local inventory = owner.components ~= nil and owner.components.inventory or nil
    if inventory == nil and owner.replica ~= nil then
        inventory = owner.replica.inventory
    end
    if inventory == nil or inventory.GetNumSlots == nil or inventory.GetItemInSlot == nil then
        return nil
    end

    for slot = 1, inventory:GetNumSlots() do
        local item = inventory:GetItemInSlot(slot)
        if IsController(item) then
            return item
        end

        if item ~= nil and item:HasTag("kei_mini_alice") then
            local container = item.components ~= nil and item.components.container or nil
            if container == nil and item.replica ~= nil then
                container = item.replica.container
            end
            local controller = FindControllerInContainer(container)
            if controller ~= nil then
                return controller
            end
        end
    end
end

return Registry
