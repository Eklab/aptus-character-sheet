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

    -- Sin habilidad asociada se conserva la tirada ROTA anterior.
    local rParams = APTUSSkillsManager.getSkillRollParams(nodeSkill) or {
        sRollMode = "SKILL", sAttribute = "", nReserve = 0, nCollect = 0,
    };
    if not nodeSkill or DB.getValue(nodeSkill, "attribute", "") == "" then
        rParams.nReserve, rParams.nCollect = 0, 0;
    end
    rParams.sLabel = sWeaponName;
    return rParams;

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

    local rParams = getAttackRollParams();
    if not rParams then return; end
    local bBroken = rParams.nCollect == 0;
    roll_reserve.setVisible(not bBroken);
    roll_separator.setVisible(not bBroken);
    roll_collect.setVisible(not bBroken);
    roll_roto.setVisible(bBroken);
    if not bBroken then
        roll_reserve.setValue(tostring(rParams.nReserve));
        roll_collect.setValue(tostring(rParams.nCollect));
    end

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

    DB.addHandler(DB.getPath(nodeChar, "skills"), "onChildUpdate", updateAttackFormula);
    DB.addHandler(DB.getPath(nodeChar, "skills"), "onChildAdded", updateAttackFormula);
    DB.addHandler(DB.getPath(nodeChar, "skills"), "onChildDeleted", updateAttackFormula);


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

    DB.removeHandler(DB.getPath(nodeChar, "skills"), "onChildUpdate", updateAttackFormula);
    DB.removeHandler(DB.getPath(nodeChar, "skills"), "onChildAdded", updateAttackFormula);
    DB.removeHandler(DB.getPath(nodeChar, "skills"), "onChildDeleted", updateAttackFormula);


    --------------------------------------------------
    -- CAMBIOS EN LA HABILIDAD ASOCIADA AL ARMA
    --------------------------------------------------

    local nodeWeapon = getDatabaseNode()

    if nodeWeapon then

        DB.removeHandler(
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