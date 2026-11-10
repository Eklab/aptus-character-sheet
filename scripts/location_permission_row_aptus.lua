local sSortKey = "";
local sUsername;
function getSortKey() return sSortKey; end

function setUser(tUser, node)
    sUsername = tUser.username;
    sSortKey = (tUser.connected and "0" or "1") .. tUser.username:lower() .. "|" .. tUser.username;
    username.setValue(tUser.username);
    connection.setValue(tUser.connected and "Conectado" or "Desconectado");
    visibility.setValue(APTUSLocationPermissions.hasVisibility(node, tUser.username) and 1 or 0);
    access.setValue(APTUSLocationPermissions.hasAccess(node, tUser.username) and 1 or 0);
end

-- Sólo una pulsación solicita escritura; setValue durante el refresco no lo hace.
function onVisibilityPressed()
    if not Session.IsHost or not sUsername then return; end
    local sUser = sUsername;
    local bEnabled = visibility.getValue() == 1;
    return windowlist.window.setUserVisibility(sUser, bEnabled);
end

function onAccessPressed()
    if not Session.IsHost or not sUsername then return; end
    return windowlist.window.setUserAccess(sUsername, access.getValue() == 1);
end
