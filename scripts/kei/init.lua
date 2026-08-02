-- Kei feature registration order. Keep strings and presentation data first so
-- actions, recipes, and integrations can safely reference character data.
modimport("scripts/kei/strings.lua")
modimport("scripts/kei/presentation.lua")
modimport("scripts/kei/actions.lua")
modimport("scripts/kei/hooks/rotor_controller.lua")
modimport("scripts/kei/hooks/rotor_survey_map.lua")
modimport("scripts/kei/integrations/winona.lua")
modimport("scripts/kei/recipes.lua")
modimport("scripts/kei/integrations/wanderingtrader.lua")
modimport("scripts/kei/growth/init.lua")

