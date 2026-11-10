local bApplying = false;

function onInit()
    if not Session.IsHost then close(); return; end
    APTUSLocationPermissions.subscribe(refreshPermissions);
    refreshPermissions();
end

function onClose()
    APTUSLocationPermissions.unsubscribe(refreshPermissions);
end

function update()
    refreshPermissions();
end

function refreshPermissions()
    if not Session.IsHost or not players or bApplying then return; end
    local node = getDatabaseNode();
    if not node or not DB.findNode(DB.getPath(node)) then return; end
    local sOwner = DB.getOwner(node) or "";
    if DB.isPublic(node) then
        permission_state.setValue("PÚBLICA: todos pueden verla. No se puede revocar Visibilidad individual; no se convierte a privada.");
    elseif sOwner ~= "" and sOwner ~= Session.UserName then
        permission_state.setValue("Propietario jugador: " .. sOwner .. ". El gestor rechaza modificaciones sobre este registro.");
    else
        permission_state.setValue("No pública. Visibilidad según destinatarios nativos. El DJ siempre tiene Visibilidad y Acceso.");
    end
    for _, w in ipairs(players.getWindows()) do w.close(); end
    for _, tUser in ipairs(APTUSLocationPermissions.getKnownUsers()) do
        local w = players.createWindow();
        w.setUser(tUser, node);
    end
    players.applySort();
end


local function applyPermissionOperation(fn)
    if not Session.IsHost or bApplying or not APTUSLocationPermissions.isVisibilityInterfaceEnabled() then return; end
    -- Los eventos del gestor pueden ser síncronos. No destruir la fila pulsada
    -- hasta que finalice la operación; después releer siempre el estado real.
    bApplying = true;
    local bCalled, bResult, detail = pcall(fn, getDatabaseNode());
    bApplying = false;
    refreshPermissions();
    if not bCalled then
        ChatManager.SystemMessage("APTUS Permisos: no se completó la operación. " .. tostring(bResult));
    elseif not bResult then
        local sReason = "No se han aplicado todos los permisos solicitados.";
        if type(detail) == "string" then
            sReason = detail;
        elseif type(detail) == "table" then
            local tFailed = {};
            for _, t in ipairs(detail) do
                if not t.success then table.insert(tFailed, t.username .. ": " .. (t.reason or "sin confirmar")); end
            end
            sReason = table.concat(tFailed, "; ");
        end
        ChatManager.SystemMessage("APTUS Permisos: " .. sReason);
    end
    return bCalled and bResult == true;
end

function setUserVisibility(sUser, bEnabled)
    return applyPermissionOperation(function(node)
        return APTUSLocationPermissions.setVisibility(node, sUser, bEnabled);
    end);
end

function grantVisibilityToConnected()
    return applyPermissionOperation(APTUSLocationPermissions.grantVisibilityToConnected);
end

function setUserAccess(sUser, bEnabled)
    return applyPermissionOperation(function(node)
        return APTUSLocationPermissions.setAccess(node, sUser, bEnabled);
    end);
end

function grantAccessToConnected()
    return applyPermissionOperation(APTUSLocationPermissions.grantAccessToConnected);
end
