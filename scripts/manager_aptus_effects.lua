--------------------------------------------------
-- APTUS EFFECTS MANAGER
--------------------------------------------------

local aAttributeTags = {
    fue = "FUE",
    agi = "AGI",
    con = "CON",
    per = "PER",
    int = "INT",
    esp = "ESP"
}

--------------------------------------------------
-- RESOLVER ACTOR CON EFECTOS
--------------------------------------------------

function resolveActor(nodeChar)

    if not nodeChar then
        return nil
    end

    local rActor = ActorManager.resolveActor(nodeChar)

    if not rActor then
        return nil
    end

    -- Registrar los efectos persistentes de la ficha.
    ActorEffectManager.addActiveEffectNode(
        rActor,
        nodeChar
    )

    return rActor
end

--------------------------------------------------
-- CONSULTAR MODIFICADOR DE ATRIBUTO
--------------------------------------------------

function getAttributeModifier(nodeChar, sAttribute)

    if not nodeChar then
        return 0
    end

    local sTag = aAttributeTags[sAttribute]

    if not sTag then
        return 0
    end

    local rActor = APTUSEffectsManager.resolveActor(
        nodeChar
    )

    if not rActor then
        return 0
    end

    local nModifier = EffectManager.getBonusMod(
        rActor,
        sTag
    )

    return tonumber(nModifier) or 0
end