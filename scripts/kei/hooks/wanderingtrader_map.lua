AddPrefabPostInit("wanderingtrader", function(inst)
    if not TheWorld.ismastersim then
        return
    end

    if inst.components.maprevealable == nil then
        inst:AddComponent("maprevealable")
    end
    inst.components.maprevealable:SetIcon("wandering_trader.tex")
    inst.components.maprevealable:AddRevealSource("kei_wandering_trader_compass", "compassbearer")
end)

if GetModConfigData("KEI_WANDERING_TRADER_MAP_MARKER") ~= false then
    AddPrefabPostInit("wanderingtrader", function(inst)
        if inst.MiniMapEntity == nil then
            inst.entity:AddMiniMapEntity()
        end
        inst.MiniMapEntity:SetIcon("wandering_trader.tex")
    end)
end

