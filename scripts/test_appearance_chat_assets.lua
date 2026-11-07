-- PRUEBA AISLADA: no cambia modos, imágenes nativas ni la notificación existente.
-- Reutiliza el mensaje visual del gestor, sin texto de depuración.
function send(nodeChar)
    if not Session.IsHost or not nodeChar then return false; end
    local tPortraits = {};
    local tSeen = {};
    for _, sMode in ipairs(APTUSSymbioteAppearance.getModes()) do
        local sAsset = DB.getValue(nodeChar,
            APTUSSymbioteAppearance.getAssetPath(sMode, "portrait"), "");
        if sAsset ~= "" and not tSeen[sAsset] then
            table.insert(tPortraits, { mode = sMode, asset = sAsset });
            tSeen[sAsset] = true;
            if #tPortraits == 2 then break; end
        end
    end
    if #tPortraits < 2 then
        ChatManager.SystemMessage("Prueba APTUS msg.assets: configura Portraits distintos en al menos dos modos. No se ha enviado la composición.");
        return false;
    end
    local tBefore, tAfter = tPortraits[1], tPortraits[2];
    return APTUSSymbioteAppearance.sendPortraitTransition(nodeChar, tBefore.mode, tAfter.mode);
end
