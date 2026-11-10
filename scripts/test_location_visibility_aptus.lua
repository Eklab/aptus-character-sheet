-- PRUEBA TEMPORAL. Sin OOB, ventanas propias ni permisos APTUS persistidos.
-- La selección vive sólo en memoria; los destinatarios nativos sí persisten.
local sSelectedPath;

local function message(s)
    if Session.IsHost then ChatManager.SystemMessage("[APTUS Visibilidad] " .. s); end
end

local function contains(t, s)
    for _, v in ipairs(t) do if v == s then return true; end end
    return false;
end

local function sorted(t)
    local result = {};
    for _, v in ipairs(t or {}) do table.insert(result, v); end
    table.sort(result);
    return result;
end

local function display(t)
    return #t > 0 and table.concat(t, ", ") or "(ninguno)";
end

local function getLocation(sPath)
    if not Session.IsHost then return nil; end
    local node = sPath and DB.findNode(sPath);
    if not node or not APTUSStructureManager.isStructure(node)
        or APTUSStructureManager.getCategory(node) ~= "locations" then
        return nil;
    end
    return node;
end

local function snapshot(node)
    return {
        public = DB.isPublic(node), owner = DB.getOwner(node) or "",
        holders = sorted(DB.getHolders(node)), active = sorted(User.getActiveUsers()),
    };
end

local function report(node, t, sLabel)
    message(sLabel .. " | " .. DB.getValue(node, "name", "(sin nombre)") .. " | " .. DB.getPath(node));
    message("Estado: " .. (t.public and "público" or "no público")
        .. " | Propietario: " .. (t.owner ~= "" and t.owner or "(sin propietario jugador)"));
    message("Conectados: " .. display(t.active) .. " | Destinatarios: " .. display(t.holders));
end

local function help()
    message("Prueba temporal del DJ. /aptusvis listar | seleccionar <ruta> | estado | dar <usuario> | quitar <usuario> | limpiar");
    message("Usa el usuario exacto, no el personaje. Seleccionar y estado no modifican permisos. No uses Compartir durante la prueba: podría hacer público el registro.");
end

local function change(sOperation, sUser)
    if not Session.IsHost then return; end
    local node = getLocation(sSelectedPath);
    if not node then
        message("RECHAZADA: selecciona una Localización existente con /aptusvis seleccionar <ruta>.");
        return;
    end
    local before = snapshot(node);
    report(node, before, "ANTES de " .. sOperation .. " [" .. sUser .. "]");
    local sReason;
    if before.public then
        sReason = "el registro es público; no se convierte ni modifica";
    elseif before.owner ~= "" and before.owner ~= Session.UserName then
        sReason = "el registro pertenece a un jugador";
    elseif DB.isReadOnly(node) or (DB.getModule(node) or "") ~= "" then
        sReason = "la prueba sólo modifica registros de campaña editables";
    elseif sUser == "" or sUser == Session.UserName then
        sReason = "indica un usuario jugador válido";
    elseif sOperation == "dar" and not contains(before.active, sUser) then
        sReason = "para conceder, el usuario debe estar conectado (nombre exacto)";
    elseif sOperation == "quitar" and not contains(before.active, sUser)
        and not contains(before.holders, sUser) then
        sReason = "el usuario no está conectado ni figura como destinatario";
    end
    if sReason then
        message("RECHAZADA: " .. sReason .. ".");
        report(node, snapshot(node), "DESPUÉS (sin operación)");
        return;
    end

    local bGrant = sOperation == "dar";
    local bAlready = contains(before.holders, sUser) == bGrant;
    local bOK, sError = true, nil;
    if not bAlready then
        bOK, sError = pcall(function()
            if bGrant then
                DB.addHolder(node, sUser, false);
            else
                DB.removeHolder(node, sUser);
            end
        end);
    end
    -- No dar por válida una llamada sin error: releer el estado del anfitrión.
    local after = snapshot(node);
    local bResult = contains(after.holders, sUser) == bGrant;
    local bOthersUnchanged = true;
    for _, s in ipairs(before.holders) do
        if s ~= sUser and not contains(after.holders, s) then bOthersUnchanged = false; end
    end
    for _, s in ipairs(after.holders) do
        if s ~= sUser and not contains(before.holders, s) then bOthersUnchanged = false; end
    end
    if bOK and bResult and bOthersUnchanged
        and after.owner == before.owner and after.public == before.public then
        message("VERIFICADA EN ANFITRIÓN: " .. sOperation .. " [" .. sUser .. "]"
            .. (bAlready and " (el estado solicitado ya existía)." or "."));
        message("Comprueba el resultado en el cliente; este comando no confirma recepción ni cierre remoto.");
    else
        message("NO VERIFICADA: " .. sOperation .. " [" .. sUser .. "]. Revisa el estado posterior."
            .. (not bOK and (" Error: " .. tostring(sError)) or ""));
        if not bOthersUnchanged or after.owner ~= before.owner or after.public ~= before.public then
            message("ADVERTENCIA: también cambió otro destinatario, propietario o estado público. No se aplica ninguna corrección automática.");
        end
    end
    report(node, after, "DESPUÉS");
end

function onTabletopInit()
    if not Session.IsHost then return; end
    Comm.registerSlashHandler("aptusvis", processCommand,
        "listar | seleccionar <ruta> | estado | dar <usuario> | quitar <usuario> | limpiar");
end

function processCommand(_, sParams)
    if not Session.IsHost then return; end
    local sCommand, sValue = (sParams or ""):match("^%s*(%S*)%s*(.-)%s*$");
    sCommand = (sCommand or ""):lower();
    if sCommand == "listar" then
        local tPaths = {};
        for _, node in pairs(DB.getChildren(APTUSStructureManager.getRootPath())) do
            if APTUSStructureManager.getCategory(node) == "locations" then
                table.insert(tPaths, DB.getPath(node));
            end
        end
        table.sort(tPaths);
        message("Localizaciones de campaña: " .. #tPaths);
        for _, sPath in ipairs(tPaths) do
            message(DB.getValue(sPath, "name", "(sin nombre)") .. " | " .. sPath);
        end
    elseif sCommand == "seleccionar" then
        sSelectedPath = nil; -- Una selección inválida nunca conserva el objetivo anterior.
        local node = getLocation(sValue);
        if not node then message("RECHAZADA: la ruta no identifica una Localización APTUS existente."); return; end
        sSelectedPath = DB.getPath(node);
        report(node, snapshot(node), "SELECCIONADA");
    elseif sCommand == "estado" then
        message("Conectados: " .. display(sorted(User.getActiveUsers())));
        local node = getLocation(sSelectedPath);
        if node then report(node, snapshot(node), "CONSULTA");
        else message("No hay una Localización válida seleccionada."); end
    elseif sCommand == "dar" or sCommand == "quitar" then
        change(sCommand, sValue);
    elseif sCommand == "limpiar" then
        sSelectedPath = nil;
        message("Selección temporal eliminada; los permisos permanecen intactos.");
    else
        help();
    end
end
