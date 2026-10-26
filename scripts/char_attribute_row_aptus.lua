--------------------------------------------------
-- CONFIGURACIÓN
--------------------------------------------------

local aAttributeNames = {
    fue = "Fuerza",
    agi = "Agilidad",
    con = "Constitución",
    per = "Percepción",
    int = "Inteligencia",
    esp = "Espíritu"
}

--------------------------------------------------
-- INICIALIZACIÓN
--------------------------------------------------

function onInit()

    local nodeAttribute = getDatabaseNode()

    if not nodeAttribute then
        return
    end

    local sAttribute = DB.getName(nodeAttribute)
    attribute_name.setValue(
        aAttributeNames[sAttribute] or sAttribute
    )

end

--------------------------------------------------
-- TIRADA DE ATRIBUTO
--------------------------------------------------

function rollAttribute()

    local nodeAttribute = getDatabaseNode()

    if not nodeAttribute then
        return
    end

    local sAttribute = DB.getName(nodeAttribute)
    local nodeChar = DB.getParent(DB.getParent(nodeAttribute))

    if not nodeChar then
        return
    end

    local nEffective = DB.getValue(nodeAttribute, "effective", 0)

    local rActor = ActorManager.resolveActor(nodeChar)

    APTUSDice.performRoll(rActor, {
        sRollMode = "ATTRIBUTE",
        sLabel = aAttributeNames[sAttribute] or sAttribute,
        sAttribute = sAttribute,
        nReserve = nEffective,
        nCollect = nEffective
    })

end

--------------------------------------------------
-- INICIATIVA
--------------------------------------------------

function rollInitiative()

    local nodeAttribute = getDatabaseNode()

    if not nodeAttribute then
        return
    end

    local sAttribute = DB.getName(nodeAttribute)
    local nodeChar = DB.getParent(DB.getParent(nodeAttribute))

    if not nodeChar then
        return
    end

    local nEffective = DB.getValue(
        nodeAttribute,
        "effective",
        0
    )

    local rActor = ActorManager.resolveActor(nodeChar)

    APTUSDice.performRoll(rActor, {
        sRollMode = "QUANTIFICATION",
        sLabel = aAttributeNames[sAttribute] or sAttribute,
        sAttribute = sAttribute,

        nReserve = nEffective * 2,
        nCollect = nEffective * 2
    })

end