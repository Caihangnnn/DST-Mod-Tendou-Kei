local RotorSurveyRegistry = require("kei/drone/registry")

local function IsRotorSurveyRecipe(recipe)
    return (type(recipe) == "string" and recipe or recipe ~= nil and recipe.name) == "kei_rotor_surveyor"
end

local function HasInventoryReplica(builder)
    return builder ~= nil
        and builder.inst ~= nil
        and builder.inst:IsValid()
        and builder.inst.replica ~= nil
        and builder.inst.replica.inventory ~= nil
end

AddComponentPostInit("builder", function(self)
    local old_HasIngredients = self.HasIngredients

    function self:HasIngredients(recipe)
        if not HasInventoryReplica(self) then
            return false
        end
        if IsRotorSurveyRecipe(recipe)
            and RotorSurveyRegistry.FindControllerInOwner(self.inst) ~= nil
        then
            return false
        end
        return old_HasIngredients(self, recipe)
    end
end)

AddClassPostConstruct("components/builder_replica", function(self)
    local old_HasIngredients = self.HasIngredients

    function self:HasIngredients(recipe)
        if not HasInventoryReplica(self) then
            return false
        end
        if IsRotorSurveyRecipe(recipe)
            and RotorSurveyRegistry.FindControllerInOwner(self.inst) ~= nil
        then
            return false
        end
        return old_HasIngredients(self, recipe)
    end
end)
