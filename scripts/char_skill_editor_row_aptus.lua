--------------------------------------------------
-- APTUS - EDITOR DE HABILIDADES
--------------------------------------------------

function onInit()

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

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

end


--------------------------------------------------
-- FORMULA DE TIRADA
--------------------------------------------------

function updateRollFormula()

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

    local sId = DB.getValue(nodeSkill, "id", "")
    local nLevel = DB.getValue(nodeSkill, "level", 0)

    local sAttribute = DB.getValue(
        nodeSkill,
        "attribute",
        ""
    )

    --------------------------------------------------
    -- HABILIDAD ROTA
    --------------------------------------------------

    if sId == "generic_skill" or nLevel <= 0 then

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
        roll_reserve.setValue("")
        roll_collect.setValue("")
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


--------------------------------------------------
-- LIMPIEZA
--------------------------------------------------

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

end


--------------------------------------------------
-- ELIMINAR HABILIDAD
--------------------------------------------------

function deleteSkill()
    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

    DB.deleteNode(nodeSkill)
end