-- ##############################################################################################
-- CTD-library: library.lua
-- Библиотека функциЙ для CTDaddon's
-- ##############################################################################################
if not CTDmod then CTDmod = {} end
if not CTDmod.lib then CTDmod.lib = {} end
if not CTDmod.lib.tech then CTDmod.lib.tech = {} end
if not CTDmod.lib.shortcuts then CTDmod.lib.shortcuts = {} end
if not CTDmod.lib.prototypes then CTDmod.lib.prototypes = {} end
if not CTDmod.lib.recipe then CTDmod.lib.recipe = {} end

local tech = data.raw["technology"]
local recipe = data.raw["recipe"]

-- ##############################################################################################
-- Вспомогательные функции
-- ##############################################################################################

-------------------------------------------------------------------------------------------------
--- Константы для типов предметов
local ITEM_TYPES = {
    "tool",
    "item",
    "capsule",
    "module",
    "ammo",
    "gun",
    "armor",
    "blueprint",
    "blueprint-book",
    "deconstruction-item",
    "upgrade-item",
    "rail-planner",
    "spidertron-remote",
    "selection-tool",
    "copy-paste-tool",
    "production-module",
    "speed-module",
    "efficiency-module",
}

-------------------------------------------------------------------------------------------------
--- Вспомогательная функция проверки существования предмета
---@param item_name string Название предмета
local function item_exists(item_name)
    if not item_name then return false end
    for _, type_name in ipairs(ITEM_TYPES) do
        if data.raw[type_name] and data.raw[type_name][item_name] then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------------------------
--- Добавляет зависимость к технологии, если её ещё нет.
---@param tech_name string  идентификатор зависимой технологии
---@param dependency  string  идентификатор требуемой технологии
---@return boolean
-------------------------------------------------------------------------------------------------
function CTDmod.lib.tech.add_dependency(tech_name, dependency)
    if not tech or not tech[tech_name] then
        error("ОШИБКА: Технология '" .. tech_name .. "' не найдена!")
    end
    if not tech[dependency] then
        error("ОШИБКА: Технология-зависимость '" .. dependency .. "' не найдена!")
    end

    local target = tech[tech_name]
    target.prerequisites = target.prerequisites or {}

    for _, prereq in ipairs(target.prerequisites) do
        if prereq == dependency then
            log("ИНФО: Технология '" .. tech_name .. "' уже зависит от '" .. dependency .. "'")
            return true
        end
    end

    table.insert(target.prerequisites, dependency)
    log("ИНФО: Добавлена зависимость - '" .. tech_name .. "' теперь требует '" .. dependency .. "'")
    return true
end

-------------------------------------------------------------------------------------------------
--- Удаляет все вхождения указанного предварительного условия из технологии.
---@param tech_name string
---@param prereq_name string
-------------------------------------------------------------------------------------------------
function CTDmod.lib.tech.remove_prerequisite(tech_name, prereq_name)
    local target = tech and tech[tech_name]
    if not (target and target.prerequisites) then
        error("ОШИБКА: Технология '" .. tech_name .. "' не найдена!")
    end
    for i = #target.prerequisites, 1, -1 do
        if target.prerequisites[i] == prereq_name then
            table.remove(target.prerequisites, i)
            log("ИНФО: Убрана зависимость - '" .. tech_name .. "' теперь не требует '" .. prereq_name .. "'")
        end
    end
end

-------------------------------------------------------------------------------------------------
--- Безопасно устанавливает поле для набора прототипов по имени.
---@param prototypes table
---@param names string[]
---@param field string
---@param value any
-------------------------------------------------------------------------------------------------
function CTDmod.lib.prototypes.set_field_for(prototypes, names, field, value)
    if not prototypes then
        return
    end
    for _, name in ipairs(names) do
        local proto = prototypes[name]
        if proto then
            proto[field] = value
        end
    end
end

-------------------------------------------------------------------------------------------------
--- Добавляет требование научного пакета к технологии
---@param tech_name string Название технологии
---@param science_pack string Название научного пакета
---@param amount integer Количество (по умолчанию 1)
-------------------------------------------------------------------------------------------------
function CTDmod.lib.tech.add_science_pack(tech_name, science_pack, amount)
    amount = amount or 1
    if not tech[tech_name] then
        error("ОШИБКА: Технология '" .. tech_name .. "' не найдена!")
        return false
    end
    if not item_exists(science_pack) then
        error("ОШИБКА: Предмет '"..science_pack.."' не найден в data.raw!")
        return false
    end
    local technology = tech[tech_name]
    if not technology.unit then
        error("ОШИБКА: Технология '"..tech_name"' не имеет unit!")
        return false
    end
    if not technology.unit.ingredients then
        technology.unit.ingredients = {}
    end
    for _, ingredient in pairs(technology.unit.ingredients) do
        if ingredient[1] == science_pack then
            ingredient[2] = (ingredient[2] or 1) + amount
            log("ИНФО: Увеличено кол-во пакета '"..science_pack.."' до "..ingredient[2].." в технологии '"..tech_name"'")
            return true
        end
    end
    table.insert(technology.unit.ingredients, {science_pack, amount})
    log("ИНФО:Добавлен пакет '"..science_pack.."' x"..amount.." в технологию '"..tech_name.."'")
    return true
end

-------------------------------------------------------------------------------------------------
--- Удаляет разблокировку рецепта технологией
---@param tech_name string Название технологии
---@param recipe_name string Название рецепта
-------------------------------------------------------------------------------------------------
function CTDmod.lib.tech.remove_unlock_recipe(tech_name, recipe_name)
    if not tech[tech_name] then
        error("ОШИБКА: Технология '" .. tech_name .. "' не найдена!")
        return false
    end
    if not recipe[recipe_name] then
        error("ОШИБКА: Рецепт '" .. recipe_name .. "' не найден!")
        return false
    end
    if tech[tech_name].effects then
        for i, effect in ipairs(tech[tech_name].effects) do
            if effect.type == "unlock-recipe" and effect.recipe == recipe_name then
                table.remove(tech[tech_name].effects, i)
            end
        end
    end
end

-------------------------------------------------------------------------------------------------
--- Пересчитывает ингредиенты рецепта-источника и записывает в два целевых рецепта без создания.
--- @param source_recipe string  Имя рецепта-источника (например, "solar-panel")
--- @param small_recipe string   Имя рецепта малой версии (например, "small-solar-panel")
--- @param large_recipe string   Имя рецепта большой версии (например, "large-solar-panel")
-------------------------------------------------------------------------------------------------
function CTDmod.lib.recipe.rescale_recipes (source_recipe, small_recipe, large_recipe)
    local src = recipe[source_recipe]
    if not src then
        log("ОШИБКА: Не найден рецепт источник: " .. source_recipe)
        return
    end
    if not src.ingredients then
        log("ОШИБКА: У рецепта "..source_recipe.." нет ингредиентов")
    end
    -- Коэффициенты: малая = 4/9, большая = 16/9
    local ratios = {
        [small_recipe] = 4/9,
        [large_recipe] = 16/9
    }
    for target_name, ratio in pairs(ratios) do
        local target = recipe[target_name]
        if not target then
            log("Не найден целевой рецепт: " .. target_name)
            goto continue
        end
        local new_ingredients = {}
        for _, ing in ipairs(src.ingredients) do
            local new_amount = math.floor(ing.amount * ratio + 0.5)
            if new_amount < 1 then new_amount = 1 end
            table.insert(new_ingredients, {
                type = ing.type or "item",
                name = ing.name,
                amount = new_amount
            })
        end
        target.ingredients = new_ingredients
        -- Пересчёт времени производства (не может быть меньше 0.1 сек)
        if src.energy_required then
            local new_time = math.floor(src.energy_required * ratio * 10 + 0.5) / 10
            if new_time < 0.1 then new_time = 0.1 end
            target.energy_required = new_time
        end
        log(string.format("ИНФО: %s: ингредиенты и время пересчитаны (коэффициент=%.4f)", target_name, ratio))

        ::continue::
    end
end