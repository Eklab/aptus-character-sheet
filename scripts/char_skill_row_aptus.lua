--------------------------------------------------
-- PREPARAR TIRADA DE HABILIDAD
--------------------------------------------------

function getSkillRollParams()
    return APTUSSkillsManager.getSkillRollParams(getDatabaseNode());
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

    DB.addHandler(DB.getPath(nodeSkill, "special"), "onUpdate", updateRollFormula);
    DB.addHandler(DB.getPath(nodeSkill, "special"), "onDelete", updateRollFormula);

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
    if skill_formula_artwork then
        APTUSSkin.subscribe(self, updateSkillPresentation);
    end

end

--------------------------------------------------
-- VISUALIZACIÓN DE LA TIRADA
--------------------------------------------------

function updateRollFormula()

    updateProgressionIndicator();

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

        roll_roto.setVisible(not skill_formula_artwork)
        updateSkillPresentation()

        return
    end

    --------------------------------------------------
    -- HABILIDAD NORMAL
    --------------------------------------------------

    roll_roto.setVisible(false)

    roll_reserve.setVisible(true)
    roll_separator.setVisible(not skill_formula_artwork)
    roll_collect.setVisible(true)

    local nodeChar = DB.getParent(DB.getParent(nodeSkill))

    if not nodeChar then
        return
    end

    local rParams = getSkillRollParams()
    roll_reserve.setValue(tostring(rParams.nReserve))
    roll_collect.setValue(tostring(rParams.nCollect))
    updateSkillPresentation()

end

function onClose()

    if skill_formula_artwork then
        APTUSSkin.unsubscribe(self, updateSkillPresentation);
    end

    local nodeSkill = getDatabaseNode()

    if not nodeSkill then
        return
    end

    DB.removeHandler(DB.getPath(nodeSkill, "special"), "onUpdate", updateRollFormula);
    DB.removeHandler(DB.getPath(nodeSkill, "special"), "onDelete", updateRollFormula);

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
        if training_artwork then
            training_artwork.setVisible(true);
            training_artwork.setIcon(APTUSSkin.getIcon(self, "aptus_skill_untrained"));
        end
        progression_indicator.setValue("")
        return
    end

    local bTrained = APTUSSkillsManager.isTrained(nodeSkill);
    if training_artwork then
        training_artwork.setVisible(true);
        training_artwork.setIcon(APTUSSkin.getIcon(self,
            bTrained and "aptus_skill_trained" or "aptus_skill_untrained"));
    end
    progression_indicator.setValue(bTrained and "●" or "○");

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
        (DB.getValue(nodeSkill, "id", "") == "generic_skill") and "-" or string.upper(sAttribute)
    )

end

-- Sólo apariencia de Principal. Los parámetros de tirada siguen en getSkillRollParams.
function updateSkillPresentation()
    if not skill_formula_artwork then return; end
    local nodeSkill = getDatabaseNode();
    if not nodeSkill then return; end
    local bBroken = DB.getValue(nodeSkill, "id", "") == "generic_skill"
        or DB.getValue(nodeSkill, "level", 0) == 0;
    local sTextFont = bBroken and "aptus_font_skill_inactive" or "aptus_font_navigation_white";
    name.setFont(sTextFont);
    attribute_display.setFont(sTextFont);
    skill_attribute_artwork.setIcon(APTUSSkin.getIcon(self, bBroken and "aptus_skill_attribute_broken" or "aptus_skill_attribute"));
    skill_formula_artwork.setIcon(APTUSSkin.getIcon(self, bBroken and "aptus_skill_formula_broken" or "aptus_skill_formula"));
    roll_separator.setVisible(false);
    roll_roto.setVisible(false);
    updateProgressionIndicator();
end
