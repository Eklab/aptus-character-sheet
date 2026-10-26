--------------------------------------------------
-- PREPARAR TIRADA DE HABILIDAD
--------------------------------------------------

function getSkillRollParams()

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return nil
    end

    --------------------------------------------------
    -- PERSONAJE
    --------------------------------------------------

    local nodeSkills = DB.getParent(nodeSkill)
    local nodeChar = DB.getParent(nodeSkills)

    if not nodeChar then
        return nil
    end

    --------------------------------------------------
    -- DATOS DE LA HABILIDAD
    --------------------------------------------------

    local sId = DB.getValue(nodeSkill, "id", "")
    local sName = DB.getValue(nodeSkill, "name", "Habilidad")
    local sAttribute = DB.getValue(nodeSkill, "attribute", "")
    local nLevel = DB.getValue(nodeSkill, "level", 0)

    local nReserve = 0
    local nCollect = 0

    --------------------------------------------------
    -- OTRAS HABILIDADES
    --------------------------------------------------

    if sId == "generic_skill" then

        sName = "Otras habilidades"
        sAttribute = ""
        nLevel = 0

    end

    --------------------------------------------------
    -- CÁLCULO DE DADOS
    --------------------------------------------------

    if nLevel > 0 then

        local nEffective = DB.getValue(
            nodeChar,
            "attributes." .. sAttribute .. ".effective",
            0
        )

        nReserve = nEffective + nLevel
        nCollect = nLevel

    end

    --------------------------------------------------
    -- PARÁMETROS DE LA TIRADA
    --------------------------------------------------

    return {
        sRollMode = "SKILL",
        sLabel = sName,
        sAttribute = sAttribute,
        nReserve = nReserve,
        nCollect = nCollect
    }

end

--------------------------------------------------
-- EJECUTAR TIRADA DE HABILIDAD
--------------------------------------------------

function performSkillRoll()

    local rParams = getSkillRollParams()

    if not rParams then
        return
    end

    local nodeSkill = getDatabaseNode()
    local nodeChar = DB.getParent(DB.getParent(nodeSkill))

    local rActor = ActorManager.resolveActor(nodeChar)

    APTUSDice.performRoll(rActor, rParams)

end

--------------------------------------------------
-- ARRASTRAR TIRADA DE HABILIDAD
--------------------------------------------------

function performSkillDrag(draginfo)

    local rParams = getSkillRollParams()

    if not rParams then
        return false
    end

    local rRoll = APTUSDice.buildRoll(rParams)

    if not rRoll then
        return false
    end

    local nodeSkill = getDatabaseNode()
    local nodeChar = DB.getParent(DB.getParent(nodeSkill))
    local rActor = ActorManager.resolveActor(nodeChar)

    ActionsManager.performAction(
        draginfo,
        rActor,
        rRoll
    )

    return true

end

--------------------------------------------------
-- VISUALIZACIÓN DE LA TIRADA
--------------------------------------------------

function onInit()

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

    -- Actualizar nombre de Otras habilidades
    local sId = DB.getValue(nodeSkill, "id", "")

    if sId == "generic_skill" then
        DB.setValue(
            nodeSkill,
            "name",
            "string",
            "Otras habilidades"
        )
    end

    --------------------------------------------------
    -- ESCUCHAR CAMBIOS EN LA HABILIDAD
    --------------------------------------------------

    DB.addHandler(
        DB.getPath(nodeSkill, "pack"),
        "onUpdate",
        updateProgressionIndicator
    )

    DB.addHandler(
        DB.getPath(nodeSkill, "profession"),
        "onUpdate",
        updateProgressionIndicator
    )

    --------------------------------------------------
    -- ESCUCHAR CAMBIOS EN NIVEL Y ATRIBUTO
    --------------------------------------------------

    DB.addHandler(
        DB.getPath(nodeSkill, "level"),
        "onUpdate",
        updateRollFormula
    )

    DB.addHandler(
        DB.getPath(nodeSkill, "attribute"),
        "onUpdate",
        updateRollFormula
    )

    DB.addHandler(
        DB.getPath(nodeSkill, "attribute"),
        "onUpdate",
        updateAttributeDisplay
    )

    --------------------------------------------------
    -- ESCUCHAR CAMBIOS EN LOS ATRIBUTOS
    --------------------------------------------------

    local nodeChar = DB.getParent(DB.getParent(nodeSkill))

    if nodeChar then

        for _, sAttribute in ipairs({
            "fue", "agi", "con", "per", "int", "esp"
        }) do

            DB.addHandler(
                DB.getPath(
                    nodeChar,
                    "attributes." .. sAttribute .. ".effective"
                ),
                "onUpdate",
                updateRollFormula
            )

        end

    end

    updateRollFormula()
    updateProgressionIndicator()
    updateAttributeDisplay()

end

--------------------------------------------------
-- VISUALIZACIÓN DE LA TIRADA
--------------------------------------------------

function updateRollFormula()

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

    local sId = DB.getValue(nodeSkill, "id", "")
    local nLevel = DB.getValue(nodeSkill, "level", 0)
    local sAttribute = DB.getValue(nodeSkill, "attribute", "")

    --------------------------------------------------
    -- HABILIDAD ROTA
    --------------------------------------------------

    if sId == "generic_skill" or nLevel == 0 then

        roll_reserve.setVisible(false)
        roll_separator.setVisible(false)
        roll_collect.setVisible(false)

        roll_roto.setVisible(true)

        return
    end

    --------------------------------------------------
    -- HABILIDAD NORMAL
    --------------------------------------------------

    roll_roto.setVisible(false)

    roll_reserve.setVisible(true)
    roll_separator.setVisible(true)
    roll_collect.setVisible(true)

    local nodeChar = DB.getParent(DB.getParent(nodeSkill))

    if not nodeChar then
        return
    end

    local nEffective = DB.getValue(
        nodeChar,
        "attributes." .. sAttribute .. ".effective",
        0
    )

    local nReserve = nEffective + nLevel

    roll_reserve.setValue(tostring(nReserve))
    roll_collect.setValue(tostring(nLevel))

end

function onClose()

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

    DB.removeHandler(
        DB.getPath(nodeSkill, "level"),
        "onUpdate",
        updateRollFormula
    )

    DB.removeHandler(
        DB.getPath(nodeSkill, "attribute"),
        "onUpdate",
        updateRollFormula
    )

    DB.removeHandler(
        DB.getPath(nodeSkill, "attribute"),
        "onUpdate",
        updateAttributeDisplay
    )

    local nodeChar = DB.getParent(DB.getParent(nodeSkill))

    if nodeChar then

        for _, sAttribute in ipairs({
            "fue", "agi", "con", "per", "int", "esp"
        }) do

            DB.removeHandler(
                DB.getPath(
                    nodeChar,
                    "attributes." .. sAttribute .. ".effective"
                ),
                "onUpdate",
                updateRollFormula
            )

        end

    end

    DB.removeHandler(
        DB.getPath(nodeSkill, "pack"),
        "onUpdate",
        updateProgressionIndicator
    )

    DB.removeHandler(
        DB.getPath(nodeSkill, "profession"),
        "onUpdate",
        updateProgressionIndicator
    )

end

--------------------------------------------------
-- INDICADOR DE PROGRESIÓN
--------------------------------------------------

function updateProgressionIndicator()

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

    local sId = DB.getValue(nodeSkill, "id", "")

    -- Otras habilidades nunca puede progresar
    if sId == "generic_skill" then
        progression_indicator.setValue("")
        return
    end

    local nPack = DB.getValue(nodeSkill, "pack", 0)
    local nProfession = DB.getValue(nodeSkill, "profession", 0)

    if nPack == 1 or nProfession == 1 then
        progression_indicator.setValue("●")
    else
        progression_indicator.setValue("○")
    end

end

--------------------------------------------------
-- VISUALIZACIÓN DEL ATRIBUTO
--------------------------------------------------

function updateAttributeDisplay()

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

    local sAttribute = DB.getValue(
        nodeSkill,
        "attribute",
        ""
    )

    attribute_display.setValue(
        string.upper(sAttribute)
    )

end