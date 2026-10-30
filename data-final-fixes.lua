-- ##############################################################################################
-- CTDaddon_for_K2SO: data-final-fixes.lua
-- Тонкая настройка механик игры и других модов под видение автора.
-- ##############################################################################################

local assembler = data.raw["assembling-machine"]
local boiler = data.raw["boiler"]
local burner_generator = data.raw["burner-generator"]
local electric_poles = data.raw["electric-pole"]
local generator = data.raw["generator"]
local item = data.raw["item"]
local lab = data.raw["lab"]
local pump = data.raw["offshore-pump"]
local recipe = data.raw["recipe"]
local shortcut = data.raw["shortcut"]
local tech = data.raw["technology"]
local solar = data.raw["solar-panel"]

local add_dependency = CTDmod.lib.tech.add_dependency
local add_science_pack = CTDmod.lib.tech.add_science_pack
local remove_prerequisite = CTDmod.lib.tech.remove_prerequisite
local remove_unlock_recipe = CTDmod.lib.tech.remove_unlock_recipe
local set_field_for = CTDmod.lib.prototypes.set_field_for
local rescale_recipes = CTDmod.lib.recipe.rescale_recipes

-- ##############################################################################################
-- Скрытие ярлыков зелёных/красных проводов (если не используется GetWiresBack)
-- ##############################################################################################
if not mods["GetWiresBack"] then
    if mods["aai-industry"] and shortcut and shortcut["give-copper-wire"] then
        shortcut["give-copper-wire"].technology_to_unlock = "electricity"
    end

    set_field_for(shortcut, {
        "give-copper-wire",
        "give-red-wire",
        "give-green-wire",
    }, "unavailable_until_unlocked", true)
end

-- ##############################################################################################
-- PowerOverload: ограничение дистанции проводов для интерфейсных столбов
-- ##############################################################################################
if mods["PowerOverload"] and electric_poles then
    local pole_distances = {
        ["po-interface"]                = 20,
        ["po-interface-north"]          = 20,
        ["po-interface-east"]           = 20,
        ["po-interface-south"]          = 20,
        ["po-hidden-electric-pole-in"]  = 10,
        ["po-hidden-electric-pole-out"] = 10,
    }
    for name, distance in pairs(pole_distances) do
        local pole = electric_poles[name]
        if pole then
            pole.maximum_wire_distance = distance
        end
    end
end

-- ##############################################################################################
-- Krastorio2-spaced-out: корректировка технологий
-- ##############################################################################################
if mods["Krastorio2-spaced-out"] then
    if tech and tech["kr-laboratory"] then
        tech["kr-laboratory"].prerequisites = nil
        tech["kr-laboratory"].effects = nil
    end

    if tech and tech["radar"] then
        remove_prerequisite("radar", "electronics")
        add_dependency("radar", "logistic-science-pack")
    end
end

-- ##############################################################################################
-- Smart_Inserters: привязка к технологии "Логистическая технологическая карта"
-- ##############################################################################################
if mods["Smart_Inserters"] then
    add_dependency("si-unlock-offsets", "logistic-science-pack")
    add_dependency("si-unlock-x-diagonals", "logistic-science-pack")

    if mods["aai-industry"] then
        add_dependency("si-unlock-cross", "burner-mechanics")
    end
end

-- ##############################################################################################
-- Repair_Turret: привязка к технологии "Логистическая технологическая карта"
-- ##############################################################################################
if mods["Repair_Turret"] then
    add_dependency("repair-turret", "logistic-science-pack")
    add_dependency("repair-turret", "steel-processing")
end

-- ##############################################################################################
-- Добавление Логистической технологической карты к технологии "Химия жидкостей"
-- ##############################################################################################
add_science_pack("kr-fluids-chemistry", "logistic-science-pack", 1)

-- ##############################################################################################
-- Удаление разблокировки Длинного манипулятора технологией "Логистика"
-- Привязка технологии "Увеличение грузоподъемности манипулятора 2"
-- к технологии "Химическая технологическая карта"
-- Привязка технологии "Пояс для инструментов 2" к технологии "Химическая технологическая карта"
-- ##############################################################################################
if mods["boblogistics"] then
    remove_unlock_recipe("logistics", "long-handed-inserter")
    add_dependency("inserter-stack-size-bonus-2", "chemical-science-pack")
    add_dependency("toolbelt-2", "chemical-science-pack")
end

-- ##############################################################################################
-- Удаление разблокировки рецепта "Кокс из углерода" технологией "Производство стали"
-- ##############################################################################################
if mods["Krastorio2-spaced-out"] then
    remove_unlock_recipe("steel-processing", "kr-coke-carbon")
end

-- ##############################################################################################
-- Разблокировка рецепта "Кокс из углерода" технологией "Космическая платформа"
-- ##############################################################################################
if not tech["space-platform"] then
    log('ИНФО: Технология "space-platform" не найдена!')
elseif recipe["kr-coke-carbon"] then
    local space_platform = tech["space-platform"]
    space_platform.effects = space_platform.effects or {}

    local already_unlocked = false
    for _, effect in pairs(space_platform.effects) do
        if effect.type == "unlock-recipe" and effect.recipe == "kr-coke-carbon" then
            already_unlocked = true
            break
        end
    end

    if not already_unlocked then
        table.insert(space_platform.effects, {
            type = "unlock-recipe",
            recipe = "kr-coke-carbon",
        })
    end
end

-- ##############################################################################################
-- Возврат стандартной теплоемкости воде и пару / изменение хар-к бойлеров, паровых двигателей,
-- насосов, твердотопливных сборщиков/лабораторий/генераторов, солнечной панели
-- ##############################################################################################
data.raw.fluid["water"].heat_capacity = "2kJ" -- вода
data.raw.fluid["steam"].heat_capacity = "0.2kJ" -- пар

    -- КПД паровых движков
generator["steam-engine"].effectivity = 0.7
generator["steam-engine"].fluid_usage_per_tick = 0.5
generator["steam-engine"].max_power_output = nil
if mods ["bobpower"] then
    generator["bob-steam-engine-2"].effectivity = 0.75
	generator["bob-steam-engine-3"].effectivity = 0.8
	generator["bob-steam-engine-4"].effectivity = 0.85
	generator["bob-steam-engine-5"].effectivity = 0.9
end

    -- КПД бойлеров
boiler["boiler"].energy_source.effectivity = 0.7
boiler["boiler"].energy_consumption = "1.8MW"
boiler["boiler"].energy_source.emissions_per_minute = {pollution = 45}
if mods ["bobpower"] then
    boiler["bob-boiler-2"].energy_consumption = "3.6MW"
    boiler["bob-boiler-3"].energy_consumption = "5.4MW"
    boiler["bob-boiler-4"].energy_consumption = "7.2MW"
    boiler["bob-boiler-5"].energy_consumption = "9.0MW"
    boiler["bob-boiler-2"].energy_source.effectivity = 0.75
    boiler["bob-boiler-3"].energy_source.effectivity = 0.8
    boiler["bob-boiler-4"].energy_source.effectivity = 0.85
    boiler["bob-boiler-5"].energy_source.effectivity = 0.9
    solar["solar-panel"].production = "60kW"
end

if mods ["aai-industry"] then
    -- КПД Твердотопливной турбины-генератора
    burner_generator["burner-turbine"].burner.effectivity = 0.45
    burner_generator["burner-turbine"].max_power_output = "800kW"

    pump["offshore-pump"].energy_usage = "60kW"
    pump["offshore-pump"].pumping_speed = 2	-- 120л/сек

    assembler["burner-assembling-machine"].energy_source.effectivity = 0.45
    assembler["burner-assembling-machine"].crafting_speed = 0.25
end

lab["burner-lab"].energy_source.effectivity = 0.45
lab["burner-lab"].researching_speed = 0.5

-- ##############################################################################################
-- Возврат стандартной теплотворности углю и древесине
-- ##############################################################################################
-- Изменение теплотворной способности угля на 4 МДж
item["coal"].fuel_value = "4MJ"

-- Изменение теплотворной способности древесины на 2 МДж
item["wood"].fuel_value = "2MJ"

-- ##############################################################################################
	-- увеличение потребления эл.энергии радарами х3
-- radar["radar"].energy_usage = "900kW"

-- if mods ["bobwarfare"] then
-- 	radar["bob-radar-2"].energy_usage = "1.35MW"
-- 	radar["bob-radar-3"].energy_usage = "1.8MW"
-- 	radar["bob-radar-4"].energy_usage = "2.25MW"
-- 	radar["bob-radar-5"].energy_usage = "2.7MW"
-- end
-- ##############################################################################################

-- ##############################################################################################
-- reactor["burner-reactor"].energy_source.effectivity = 0.75
-- reactor["burner-reactor-2"].energy_source.effectivity = 0.85

-- reactor["fluid-reactor"].energy_source.effectivity = 0.8
-- reactor["fluid-reactor-2"].energy_source.effectivity = 0.9
-- ##############################################################################################

-- ##############################################################################################
-- 	reactor["burner-reactor"].energy_source.effectivity = 0.75
-- 	reactor["burner-reactor-2"].energy_source.effectivity = 0.87

-- 	reactor["fluid-reactor"].energy_source.effectivity = 0.76
-- 	reactor["fluid-reactor-2"].energy_source.effectivity = 0.88
-- ##############################################################################################
if mods ["bobpower"] then
    rescale_recipes("solar-panel", "bob-solar-panel-small", "bob-solar-panel-large")
end