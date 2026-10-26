--------------------------------------------------
-- APTUS - FILA DE ARMA
--------------------------------------------------

--------------------------------------------------
-- OBTENER PERSONAJE
--------------------------------------------------

local function getCharacterNode()

    local nodeWeapon = getDatabaseNode()

    if not nodeWeapon then
        return nil
    end

    local nodeWeapons = DB.getParent(nodeWeapon)

    if not nodeWeapons then
        return nil
    end

    return DB.getParent(nodeWeapons)

end

--------------------------------------------------
-- LOCALIZAR HABILIDAD DE ATAQUE
--------------------------------------------------

local function getAttackSkillNode()

    local nodeWeapon = getDatabaseNode()
    local nodeChar = getCharacterNode()

    if not nodeWeapon or not nodeChar then
        return nil
    end

    local sSkillId = DB.getValue(
        nodeWeapon,
        "attack_skill_id",
        ""
    )

    local nodeSkills = DB.getChild(nodeChar, "skills")

    if not nodeSkills then
        return nil
    end

    for _, nodeSkill in pairs(DB.getChildren(nodeSkills)) do

        if DB.getValue(nodeSkill, "id", "") == sSkillId then
            return nodeSkill
        end

    end

    return nil

end

--------------------------------------------------
-- PREPARAR TIRADA DE ATAQUE
--------------------------------------------------

function getAttackRollParams()

    local nodeWeapon = getDatabaseNode()
    local nodeChar = getCharacterNode()
    local nodeSkill = getAttackSkillNode()

    if not nodeWeapon or not nodeChar then
        return nil
    end

    local sWeaponName = DB.getValue(
        nodeWeapon,
        "name",
        "Arma"
    )

    local nLevel = 0
    local sAttribute = ""

    if nodeSkill then

        nLevel = DB.getValue(nodeSkill, "level", 0)
        sAttribute = DB.getValue(nodeSkill, "attribute", "")

    end

    local nReserve = 0
    local nCollect = 0

    if nLevel > 0 and sAttribute ~= "" then

        local nEffective = DB.getValue(
            nodeChar,
            "attributes." .. sAttribute .. ".effective",
            0
        )

        nReserve = nEffective + nLevel
        nCollect = nLevel

    end

    return {
        sRollMode = "SKILL",
        sLabel = sWeaponName,
        sAttribute = sAttribute,
        nReserve = nReserve,
        nCollect = nCollect
    }

end

--------------------------------------------------
-- EJECUTAR ATAQUE
--------------------------------------------------

function performAttackRoll()

    local rParams = getAttackRollParams()

    if not rParams then
        return
    end

    local nodeChar = getCharacterNode()
    local rActor = ActorManager.resolveActor(nodeChar)

    APTUSDice.performRoll(rActor, rParams)

end

--------------------------------------------------
-- ARRASTRAR TIRADA DE ATAQUE
--------------------------------------------------

function performAttackDrag(draginfo)

    local rParams = getAttackRollParams()

    if not rParams then
        return false
    end

    local rRoll = APTUSDice.buildRoll(rParams)

    if not rRoll then
        return false
    end

    local nodeChar = getCharacterNode()
    local rActor = ActorManager.resolveActor(nodeChar)

    ActionsManager.performAction(
        draginfo,
        rActor,
        rRoll
    )

    return true

end

--------------------------------------------------
-- VISUALIZAR FÓRMULA
--------------------------------------------------

function updateAttackFormula()

    local nodeChar = getCharacterNode()
    local nodeSkill = getAttackSkillNode()

    if not nodeChar then
        return
    end

    local nLevel = 0
    local sAttribute = ""

    if nodeSkill then

        nLevel = DB.getValue(nodeSkill, "level", 0)
        sAttribute = DB.getValue(nodeSkill, "attribute", "")

    end

    --------------------------------------------------
    -- DADO ROTO
    --------------------------------------------------

    if nLevel == 0 or sAttribute == "" then

        roll_reserve.setVisible(false)
        roll_separator.setVisible(false)
        roll_collect.setVisible(false)

        roll_roto.setVisible(true)

        return

    end

    --------------------------------------------------
    -- TIRADA NORMAL
    --------------------------------------------------

    roll_roto.setVisible(false)

    roll_reserve.setVisible(true)
    roll_separator.setVisible(true)
    roll_collect.setVisible(true)

    local nEffective = DB.getValue(
        nodeChar,
        "attributes." .. sAttribute .. ".effective",
        0
    )

    roll_reserve.setValue(tostring(nEffective + nLevel))
    roll_collect.setValue(tostring(nLevel))

end

--------------------------------------------------
-- INICIALIZACIÓN
--------------------------------------------------

function onInit()

    local nodeChar = getCharacterNode()


    local nodeWeapon = getDatabaseNode()
    local nodeSkill = getAttackSkillNode()

    --------------------------------------------------
    -- DEPURACIÓN
    --------------------------------------------------

    Debug.chat(
        "[APTUS ARMAS] Arma:",
        DB.getValue(nodeWeapon, "name", "")
    )

    Debug.chat(
        "[APTUS ARMAS] Habilidad ID:",
        DB.getValue(nodeWeapon, "attack_skill_id", "")
    )

    Debug.chat(
        "[APTUS ARMAS] Habilidad encontrada:",
        nodeSkill and DB.getValue(nodeSkill, "name", "") or "NO"
    )

    Debug.chat(
        "[APTUS ARMAS] Daño:",
        DB.getValue(nodeWeapon, "damage_dice", ""),
        DB.getValue(nodeWeapon, "damage_type", "")
    )

    --------------------------------------------------
    -- CAMBIOS EN ATRIBUTOS
    --------------------------------------------------

    for _, sAttribute in ipairs({
        "fue", "agi", "con", "per", "int", "esp"
    }) do

        DB.addHandler(
            DB.getPath(
                nodeChar,
                "attributes." .. sAttribute .. ".effective"
            ),
            "onUpdate",
            updateAttackFormula
        )

    end

    --------------------------------------------------
    -- CAMBIOS EN HABILIDADES
    --------------------------------------------------

    if nodeSkill then

        DB.addHandler(
            DB.getPath(nodeSkill, "level"),
            "onUpdate",
            updateAttackFormula
        )

        DB.addHandler(
            DB.getPath(nodeSkill, "attribute"),
            "onUpdate",
            updateAttackFormula
        )

    end

    --------------------------------------------------
    -- CAMBIOS EN LA HABILIDAD ASOCIADA AL ARMA
    --------------------------------------------------

    local nodeWeapon = getDatabaseNode()

    if nodeWeapon then

        DB.addHandler(
            DB.getPath(nodeWeapon, "attack_skill_id"),
            "onUpdate",
            updateAttackFormula
        )

    end

    --------------------------------------------------
    -- ACTUALIZAR VISUALIZACIÓN
    --------------------------------------------------

    updateAttackFormula()
    updateDamageDisplay()

end

--------------------------------------------------
-- CERRAR
--------------------------------------------------

function onClose()

    local nodeChar = getCharacterNode()

    if not nodeChar then
        return
    end

    for _, sAttribute in ipairs({
        "fue", "agi", "con", "per", "int", "esp"
    }) do

        DB.removeHandler(
            DB.getPath(
                nodeChar,
                "attributes." .. sAttribute .. ".effective"
            ),
            "onUpdate",
            updateAttackFormula
        )

    end

    local nodeSkill = getAttackSkillNode()

    if nodeSkill then

        DB.removeHandler(
            DB.getPath(nodeSkill, "level"),
            "onUpdate",
            updateAttackFormula
        )

        DB.removeHandler(
            DB.getPath(nodeSkill, "attribute"),
            "onUpdate",
            updateAttackFormula
        )

    end

    --------------------------------------------------
    -- CAMBIOS EN LA HABILIDAD ASOCIADA AL ARMA
    --------------------------------------------------

    local nodeWeapon = getDatabaseNode()

    if nodeWeapon then

        DB.addHandler(
            DB.getPath(nodeWeapon, "attack_skill_id"),
            "onUpdate",
            updateAttackFormula
        )

    end

end

--------------------------------------------------
-- VISUALIZAR DAÑO DEL ARMA
--------------------------------------------------

function updateDamageDisplay()

    local nodeWeapon = getDatabaseNode()

    if not nodeWeapon then
        return
    end

    local sDice = DB.getValue(nodeWeapon, "damage_dice", "")
    local sType = DB.getValue(nodeWeapon, "damage_type", "")

    damage_display.setValue(sDice .. " " .. sType)

end

--------------------------------------------------
-- ELIMINAR ARMA DEL PERSONAJE
--------------------------------------------------

function deleteWeapon()

    if not Session.IsHost then
        return
    end

    local nodeWeapon = getDatabaseNode()

    if nodeWeapon then
        DB.deleteNode(nodeWeapon)
    end

end