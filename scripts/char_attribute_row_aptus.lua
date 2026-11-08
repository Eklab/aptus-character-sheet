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
        scale and sAttribute:upper() or (aAttributeNames[sAttribute] or sAttribute)
    )
    if scale then APTUSSkin.subscribe(self, updateScale); end

end

--------------------------------------------------
-- TIRADA DE ATRIBUTO
--------------------------------------------------

function rollAttribute(draginfo)

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

    local rParams = {
        sRollMode = "ATTRIBUTE",
        sLabel = aAttributeNames[sAttribute] or sAttribute,
        sAttribute = sAttribute,
        nReserve = nEffective,
        nCollect = nEffective
    }
    if draginfo then
        local rRoll = APTUSDice.buildRoll(rParams)
        if not rRoll then return false; end
        ActionsManager.performAction(draginfo, rActor, rRoll)
        return true;
    end
    APTUSDice.performRoll(rActor, rParams)

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
        bAptusInitiative = true,
        sLabel = aAttributeNames[sAttribute] or sAttribute,
        sAttribute = sAttribute,

        nReserve = nEffective * 2,
        nCollect = nEffective * 2
    })

end

-- Presentación opcional de la fila nueva; el cálculo sigue en char_main_aptus.lua.
function updateScale()
    if not scale then return; end
    local nValue = DB.getValue(getDatabaseNode(), "effective", 0);
    local nLevel = math.max(0, math.min(6, math.floor(nValue)));
    scale.setIcon(APTUSSkin.getIcon(self, "aptus_attribute_level_" .. nLevel));
    if initiative_button then
        initiative_button.setIcons(APTUSSkin.getIcon(self, "aptus_attribute_initiative"));
    end
end

function onClose()
    if scale then APTUSSkin.unsubscribe(self, updateScale); end
end
