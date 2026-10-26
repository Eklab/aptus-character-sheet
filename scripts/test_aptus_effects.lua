function testCharacterEffect(nodeChar)
    if not nodeChar then
        Debug.console("[APTUS TEST] No se ha recibido un personaje")
        return
    end

    -- 1. Crear un efecto de prueba en la ficha.
    local nodeEffects = DB.createChild(nodeChar, "effects")
    local nodeEffect = DB.createChild(nodeEffects, "aptus_test_agi")

    DB.setValue(nodeEffect, "label", "string", "AGI: -2")
    DB.setValue(nodeEffect, "isactive", "number", 1)

    -- 2. Resolver el actor.
    local rActor = ActorManager.resolveActor(nodeChar)

    if not rActor then
        Debug.console("[APTUS TEST] No se ha podido resolver el actor")
        return
    end

    -- 3. Registrar los efectos de la ficha.
    ActorEffectManager.addActiveEffectNode(rActor, nodeChar)

    -- 4. Consultar el modificador.
    local nModifier = EffectManager.getBonusMod(rActor, "AGI")

    Debug.console("[APTUS TEST] AGI activo:", nModifier)

    -- 5. Desactivar el efecto.
    DB.setValue(nodeEffect, "isactive", "number", 0)

    local nInactiveModifier = EffectManager.getBonusMod(rActor, "AGI")

    Debug.console("[APTUS TEST] AGI inactivo:", nInactiveModifier)
end

function testFreshActor(nodeChar)
    if not nodeChar then
        return
    end

    -- Recuperar un actor nuevo
    local rActor = ActorManager.resolveActor(nodeChar)

    local nodeEffect = DB.getChild(nodeChar, "effects.aptus_test_agi")

    if not nodeEffect then
        Debug.console("[APTUS TEST] No existe el efecto de prueba")
        return
    end

    DB.setValue(nodeEffect, "isactive", "number", 1)

    -- Consultar SIN registrar nuevamente los efectos
    local nBefore = EffectManager.getBonusMod(rActor, "AGI")

    -- Registrar los efectos almacenados en la ficha
    ActorEffectManager.addActiveEffectNode(rActor, nodeChar)

    -- Consultar nuevamente
    local nAfter = EffectManager.getBonusMod(rActor, "AGI")

    Debug.console("[APTUS TEST] Actor nuevo SIN registro:", nBefore)
    Debug.console("[APTUS TEST] Actor nuevo CON registro:", nAfter)
end