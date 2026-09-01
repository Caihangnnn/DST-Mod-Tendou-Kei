local KEI_RPC_NAMESPACE = "TendouKei"
local RotorSurveyRegistry = require("kei/drone/registry")
local ClientSettings = require("kei/client_settings")

-- The controller is a server-owned inventory item. Equip it on the server
-- first, then ask only that client to open the existing spell-wheel flow.
AddModRPCHandler(KEI_RPC_NAMESPACE, "UseRotorControllerShortcut", function(player)
    if player == nil
        or not player:HasTag("kei")
        or player:HasTag("playerghost")
        or player.components.inventory == nil
    then
        return
    end

    local controller = RotorSurveyRegistry.FindControllerInOwner(player)
    if controller == nil or not controller:IsValid() then
        return
    end

    local inventory = player.components.inventory
    if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) ~= controller then
        inventory:Equip(controller)
    end
    if inventory:GetEquippedItem(EQUIPSLOTS.HANDS) == controller and player.userid ~= nil then
        SendModRPCToClient(
            GetClientModRPC(KEI_RPC_NAMESPACE, "OpenRotorControllerWheel"),
            player.userid
        )
    end
end)

if not TheNet:IsDedicated() and TheInput ~= nil then
    local rotor_wheel_task = nil

    local function OpenRotorControllerWheel()
        if ThePlayer == nil then
            return
        end
        if rotor_wheel_task ~= nil then
            rotor_wheel_task:Cancel()
        end
        local attempts = 0
        rotor_wheel_task = ThePlayer:DoPeriodicTask(.1, function(player)
            attempts = attempts + 1
            local inventory = player.replica ~= nil and player.replica.inventory or nil
            local controller = inventory ~= nil and inventory:GetEquippedItem(EQUIPSLOTS.HANDS) or nil
            if controller ~= nil and controller:HasTag("kei_rotor_survey_controller") then
                rotor_wheel_task:Cancel()
                rotor_wheel_task = nil
                local spellbook = controller.components ~= nil and controller.components.spellbook or nil
                if spellbook ~= nil and spellbook:CanBeUsedBy(player) then
                    spellbook:OpenSpellBook(player)
                end
            elseif attempts >= 10 then
                rotor_wheel_task:Cancel()
                rotor_wheel_task = nil
            end
        end)
    end

    AddClientModRPCHandler(KEI_RPC_NAMESPACE, "OpenRotorControllerWheel", OpenRotorControllerWheel)
    ClientSettings:RegisterActionHandler("rotor", function()
        local player = ThePlayer
        local screen = TheFrontEnd ~= nil and TheFrontEnd:GetActiveScreen() or nil
        if player ~= nil and screen ~= nil and screen.name == "HUD" and player:HasTag("kei") then
            SendModRPCToServer(MOD_RPC[KEI_RPC_NAMESPACE].UseRotorControllerShortcut)
        end
    end)
end

-- AddClientModRPCHandler must run on the dedicated server as well: the server
-- owns the RPC id table used by SendModRPCToClient, even though it never runs
-- the callback itself.
if TheNet:IsDedicated() then
    AddClientModRPCHandler(KEI_RPC_NAMESPACE, "OpenRotorControllerWheel", function()
    end)
end
