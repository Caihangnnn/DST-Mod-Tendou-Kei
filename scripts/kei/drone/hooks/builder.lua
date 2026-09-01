local RotorSurveyRegistry = require("kei/drone/registry")

local function IsRotorSurveyRecipe(recipe)
    return (type(recipe) == "string" and recipe or recipe ~= nil and recipe.name) == "kei_rotor_surveyor"
end

AddComponentPostInit("builder", function(self)
    local old_HasIngredients = self.HasIngredients

    function self:HasIngredients(recipe)
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
        if IsRotorSurveyRecipe(recipe)
            and RotorSurveyRegistry.FindControllerInOwner(self.inst) ~= nil
        then
            return false
        end
        return old_HasIngredients(self, recipe)
    end
end)
