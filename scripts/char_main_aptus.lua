--------------------------------------------------
-- CONFIGURACIÓN
--------------------------------------------------

local aAttributes = {
    "fue",
    "agi",
    "con",
    "per",
    "int",
    "esp"
}

local aCommonSkills = {
    { id = "acrobacias",       name = "Acrobacias",       attribute = "agi" },
    { id = "alerta",           name = "Alerta",           attribute = "per" },
    { id = "atletismo",        name = "Atletismo",        attribute = "fue" },
    { id = "ave_intenciones",  name = "Ave. Intenciones", attribute = "per" },
    { id = "conducir",         name = "Conducir",         attribute = "agi" },
    { id = "coraje",           name = "Coraje",           attribute = "esp" },
    { id = "cultura",          name = "Cultura",          attribute = "int" },
    { id = "engano",           name = "Engaño",           attribute = "esp" },
    { id = "informatica",      name = "Informática",      attribute = "int" },
    { id = "intimidacion",     name = "Intimidación",     attribute = "esp" },
    { id = "investigacion",    name = "Investigación",    attribute = "int" },
    { id = "pelea",            name = "Pelea",            attribute = "fue" },
    { id = "persuasion",       name = "Persuasión",       attribute = "esp" },
    { id = "punteria",         name = "Puntería",         attribute = "per" },
    { id = "sigilo",           name = "Sigilo",           attribute = "agi" },
    { id = "supervivencia",    name = "Supervivencia",    attribute = "per" },
    { id = "tecnologia",       name = "Tecnología",       attribute = "int" },
    { id = "mecanica",         name = "Mecánica",         attribute = "int" }
}

--------------------------------------------------
-- GESTIÓN DE ATRIBUTOS
--------------------------------------------------

--------------------------------------------------
-- ACTUALIZAR ATRIBUTO
--------------------------------------------------

local function updateAttribute(sAttribute)
    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    local sPath = "attributes." .. sAttribute

    -- Valor base
    local nBase = DB.getValue(
        nodeChar,
        sPath .. ".base",
        0
    )

    -- Alteración procedente de efectos activos
    local nAlteration =
        APTUSEffectsManager.getAttributeModifier(
            nodeChar,
            sAttribute
        )

    -- Valor efectivo (mínimo 0)
    local nEffective = math.max(
        0,
        nBase + nAlteration
    )

    -- Guardar alteración calculada
    DB.setValue(
        nodeChar,
        sPath .. ".alteration",
        "number",
        nAlteration
    )

    -- Guardar valor efectivo
    DB.setValue(
        nodeChar,
        sPath .. ".effective",
        "number",
        nEffective
    )
end

local function updateDefenseAndHealth()
    local nodeChar = getDatabaseNode()
    if not nodeChar then
        return
    end

    -- Defensa: Agilidad efectiva
    local nAgility = DB.getValue(
        nodeChar,
        "attributes.agi.effective",
        0
    )

    -- DEFENSA
    DB.setValue(nodeChar, "defense.base", "number", nAgility)

    if DB.getValue(nodeChar, "defense.current", nil) == nil then
        DB.setValue(nodeChar, "defense.current", "number", nAgility)
    end

    -- SALUD
    DB.setValue(nodeChar, "health.base", "number", 6)

    if DB.getValue(nodeChar, "health.current", nil) == nil then
        DB.setValue(nodeChar, "health.current", "number", 6)
    end

end

local function updateAllAttributes()
    for _, sAttribute in ipairs(aAttributes) do
        updateAttribute(sAttribute)
    end

    updateDefenseAndHealth()
end

--------------------------------------------------
-- ACTUALIZACIÓN POR CAMBIOS EN EFECTOS
--------------------------------------------------
function onEffectsChanged()
    updateAllAttributes()
end

function onAttributeChanged(nodeField)
    local nodeAttribute = DB.getParent(nodeField)

    if nodeAttribute then
        updateAttribute(DB.getName(nodeAttribute))

        -- Actualizar Defensa cuando cambia un atributo
        updateDefenseAndHealth()
    end
end


--------------------------------------------------
-- INICIALIZAR HABILIDADES COMUNES
--------------------------------------------------

local function initializeCommonSkills()

    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    local nodeSkills = DB.createChild(nodeChar, "skills")

    if not nodeSkills then
        return
    end

    -- Registrar las habilidades que ya existen
    local aExistingSkills = {}

    for _, nodeSkill in pairs(DB.getChildren(nodeSkills)) do
        local sId = DB.getValue(nodeSkill, "id", "")

        if sId ~= "" then
            aExistingSkills[sId] = true
        end
    end

    -- Incorporar únicamente las habilidades que faltan
    for _, rSkill in ipairs(aCommonSkills) do

        if not aExistingSkills[rSkill.id] then

            local nodeSkill = DB.createChild(nodeSkills)

            if nodeSkill then

                DB.setValue(nodeSkill, "id", "string", rSkill.id)
                DB.setValue(nodeSkill, "name", "string", rSkill.name)

                DB.setValue(
                    nodeSkill,
                    "attribute",
                    "string",
                    rSkill.attribute
                )

                DB.setValue(
                    nodeSkill,
                    "default_attribute",
                    "string",
                    rSkill.attribute
                )

                DB.setValue(nodeSkill, "level", "number", 0)
                DB.setValue(nodeSkill, "special", "number", 0)

                aExistingSkills[rSkill.id] = true

            end

        end

    end

end

--------------------------------------------------
-- INICIALIZACIÓN
--------------------------------------------------

function onInit()
    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    -- Establecer el orden de los atributos
    for nOrder, sAttribute in ipairs(aAttributes) do
        DB.setValue(
            nodeChar,
            "attributes." .. sAttribute .. ".order",
            "number",
            nOrder
        )
    end

    for _, sAttribute in ipairs(aAttributes) do
        local sPath = DB.getPath(nodeChar, "attributes." .. sAttribute)

        DB.addHandler(
            sPath .. ".base",
            "onUpdate",
            onAttributeChanged
        )

    end

    -- Escuchar cambios en los efectos del personaje
    local sEffectsPath = DB.getPath(nodeChar, "effects")

    DB.addHandler(
        sEffectsPath,
        "onChildUpdate",
        onEffectsChanged
    )

    DB.addHandler(
        sEffectsPath,
        "onChildAdded",
        onEffectsChanged
    )

    DB.addHandler(
        sEffectsPath,
        "onChildDeleted",
        onEffectsChanged
    )

     updateAllAttributes()

    -- Inicializar las habilidades predeterminadas una sola vez
    local nInitialized = DB.getValue(
        nodeChar,
        "skills_initialized",
        0
    )

    if nInitialized == 0 then
        initializeCommonSkills()
        initializeGenericSkill()

        DB.setValue(
            nodeChar,
            "skills_initialized",
            "number",
            1
        )
    end

    updateWounds()

    -- TEMPORAL --

    local nodeEffects = DB.getChild(nodeChar, "effects")

    Debug.console(
        "[APTUS] Nodo de efectos:",
        nodeEffects and DB.getPath(nodeEffects) or "NO EXISTE"
    )

    if nodeEffects then
        for _, nodeEffect in pairs(DB.getChildren(nodeEffects)) do
            Debug.console(
                "[APTUS] Efecto encontrado:",
                DB.getPath(nodeEffect),
                DB.getValue(nodeEffect, "label", "")
            )
        end
    end

end

function initializeGenericSkill()
    local nodeChar = getDatabaseNode()
    if not nodeChar then
        return
    end

    local nodeSkills = DB.createChild(nodeChar, "skills")
    if not nodeSkills then
        return
    end

    -- Comprobar si ya existe
    for _, nodeSkill in pairs(DB.getChildren(nodeSkills)) do
        if DB.getValue(nodeSkill, "id", "") == "generic_skill" then
            return
        end
    end

    -- Crear Habilidad Genérica
    local nodeSkill = DB.createChild(nodeSkills)
    if not nodeSkill then
        return
    end

    DB.setValue(nodeSkill, "id", "string", "generic_skill")
    DB.setValue(nodeSkill, "name", "string", "Otras habilidades")
    DB.setValue(nodeSkill, "attribute", "string", "")
    DB.setValue(nodeSkill, "default_attribute", "string", "")
    DB.setValue(nodeSkill, "level", "number", 0)
    DB.setValue(nodeSkill, "special", "number", 0)
end


--------------------------------------------------
-- CIERRE
--------------------------------------------------

function onClose()
    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    for _, sAttribute in ipairs(aAttributes) do
        local sPath = DB.getPath(nodeChar, "attributes." .. sAttribute)

        DB.removeHandler(
            sPath .. ".base",
            "onUpdate",
            onAttributeChanged
        )

    end

    local sEffectsPath = DB.getPath(nodeChar, "effects")

    DB.removeHandler(
        sEffectsPath,
        "onChildUpdate",
        onEffectsChanged
    )

    DB.removeHandler(
        sEffectsPath,
        "onChildAdded",
        onEffectsChanged
    )

    DB.removeHandler(
        sEffectsPath,
        "onChildDeleted",
        onEffectsChanged
    )

    end

--------------------------------------------------
-- TIRADAS DE ATRIBUTO
--------------------------------------------------

function rollAttribute(sAttribute)

    -- Recuperar el personaje de la ficha
    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    -- Recuperar el valor efectivo del atributo
    local nEffective = DB.getValue(
        nodeChar,
        "attributes." .. sAttribute .. ".effective",
        0
    )

    -- Identificar el actor para Fantasy Grounds
    local rActor = ActorManager.resolveActor(nodeChar)

    -- Nombres visibles
    local aAttributeNames = {
        fue = "Fuerza",
        agi = "Agilidad",
        con = "Constitución",
        per = "Percepción",
        int = "Inteligencia",
        esp = "Espíritu"
    }

    -- Enviar la tirada al motor APTUS
    APTUSDice.performRoll(rActor, {
        sRollMode = "ATTRIBUTE",
        sLabel = aAttributeNames[sAttribute] or sAttribute,
        sAttribute = sAttribute,

        nReserve = nEffective,
        nCollect = nEffective
    })

end

--------------------------------------------------
-- EDITOR DE ATRIBUTOS
--------------------------------------------------

function openAttributesEditor()

    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    Interface.openWindow(
        "aptus_attributes_editor",
        nodeChar
    )

end

--------------------------------------------------
-- APTUS - CONTROL DE HERIDAS
--------------------------------------------------

local MAX_WOUNDS = 7

function updateWounds()

    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    local nWounds = DB.getValue(nodeChar, "wounds", 0)

    nWounds = math.max(0, math.min(MAX_WOUNDS, nWounds))

    for i = 1, MAX_WOUNDS do

        local control = self["wound_" .. i]

        if control then
            control.setVisible(i <= nWounds)
        end

    end

end

--------------------------------------------------
-- MODIFICAR HERIDAS
--------------------------------------------------

function changeWounds(nNotches)

    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    local nWounds = DB.getValue(nodeChar, "wounds", 0)

    if nNotches > 0 then
        nWounds = math.min(7, nWounds + 1)
    elseif nNotches < 0 then
        nWounds = math.max(0, nWounds - 1)
    else
        return
    end

    DB.setValue(nodeChar, "wounds", "number", nWounds)

end


--------------------------------------------------
-- APTUS - AÑADIR ARMA DESDE EL CATÁLOGO
--------------------------------------------------

function addWeaponFromDrop(draginfo)

    if draginfo.getType() ~= "shortcut" then
        return false
    end

    local sClass, sRecord = draginfo.getShortcutData()

    -- Solo aceptar registros del catálogo de armas
    if sClass ~= "aptus_weapon" then
        return false
    end

    local nodeSource = DB.findNode(sRecord)

    if not nodeSource then
        return false
    end

    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return false
    end

    -- Crear un arma en el personaje
    local nodeWeapons = DB.createChild(nodeChar, "weapons")
    local nodeWeapon = DB.createChild(nodeWeapons)

    if not nodeWeapon then
        return false
    end

    -- Copiar los datos del arma del catálogo
    for _, sField in ipairs({
        "id",
        "name",
        "attack_skill_id",
        "range",
        "damage_dice",
        "damage_type",
        "critical_dice",
        "special"
    }) do

        DB.setValue(
            nodeWeapon,
            sField,
            "string",
            DB.getValue(nodeSource, sField, "")
        )

    end

    return true

end