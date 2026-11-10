-- Autoridad del anfitrión. Concesiones privadas y proyección nativa individual.
local sRoster = "aptus_known_users";
local sPrivate = "aptus_location_permissions";
local sStates = "aptus_location_user_states";
local notify;
local tListeners, tHandlers = {}, {};
local tRemembering = {};
local bRefreshing = false;

function isInterfaceEnabled() return true; end
function isVisibilityInterfaceEnabled() return true; end

local function validUser(sUser)
    return type(sUser) == "string" and sUser:match("%S") ~= nil
        and sUser ~= Session.UserName;
end

local function isLocation(node)
    return node and APTUSStructureManager.isStructure(node)
        and APTUSStructureManager.getCategory(node) == "locations";
end

local function permissionRecord(node, bCreate)
    local sPath = DB.getPath(node);
    for _, record in pairs(DB.getChildren(sPrivate)) do
        local _, sTarget = DB.getValue(record, "structure", "", "");
        if sTarget == sPath then return record; end
    end
    if bCreate and Session.IsHost then
        local record = DB.createChild(sPrivate);
        if record then DB.setValue(record, "structure", "windowreference", "aptus_structure", sPath); end
        return record;
    end
end

local function findGrant(node, sUser)
    local record = permissionRecord(node, false);
    if not record then return nil; end
    for _, grant in pairs(DB.getChildren(record, "access")) do
        if DB.getValue(grant, "username", "") == sUser then return grant; end
    end
end

function rememberUser(sUser)
    if not Session.IsHost or not validUser(sUser) then return false; end
    if tRemembering[sUser] then return false; end
    for _, node in pairs(DB.getChildren(sRoster)) do
        if DB.getValue(node, "username", "") == sUser then return false; end
    end
    -- Los eventos de DB pueden ejecutarse durante la creación del registro.
    tRemembering[sUser] = true;
    local node = DB.createChild(sRoster);
    if not node then tRemembering[sUser] = nil; return false; end
    DB.setValue(node, "username", "string", sUser);
    tRemembering[sUser] = nil;
    return true;
end

function getKnownUsers()
    if not Session.IsHost then return {}; end
    local tActive, tResult, tSeen = {}, {}, {};
    for _, sUser in ipairs(User.getActiveUsers()) do tActive[sUser] = true; end
    for _, node in pairs(DB.getChildren(sRoster)) do
        local sUser = DB.getValue(node, "username", "");
        if validUser(sUser) and not tSeen[sUser] then
            tSeen[sUser] = true;
            table.insert(tResult, { username = sUser, connected = tActive[sUser] == true });
        end
    end
    table.sort(tResult, function(a, b)
        if a.connected ~= b.connected then return a.connected; end
        if a.username:lower() ~= b.username:lower() then return a.username:lower() < b.username:lower(); end
        return a.username < b.username;
    end);
    return tResult;
end

function hasVisibility(node, sUser)
    if not isLocation(node) or DB.findNode(DB.getPath(node)) ~= node then return false; end
    if Session.IsHost then
        if sUser == Session.UserName then return true; end
        if not validUser(sUser) then return false; end
        if DB.isPublic(node) or DB.getOwner(node) == sUser then return true; end
        for _, sHolder in ipairs(DB.getHolders(node)) do
            if sHolder == sUser then return true; end
        end
        return false;
    end
    -- En clientes sólo se consulta al usuario local y datos ya disponibles.
    return sUser == Session.UserName;
end

function hasAccess(node, sUser)
    if not isLocation(node) then return false; end
    if Session.IsHost and sUser == Session.UserName then return true; end
    if not hasVisibility(node, sUser) then return false; end
    if Session.IsHost then return findGrant(node, sUser) ~= nil; end
    -- El cliente sólo ve sus proyecciones: nunca la lista de usuarios autorizados.
    if sUser ~= Session.UserName then return false; end
    for _, state in pairs(DB.getChildren(sStates)) do
        local _, sTarget = DB.getValue(state, "structure", "", "");
        if sTarget == DB.getPath(node) and DB.getValue(state, "access", 0) == 1 then return true; end
    end
    return false;
end

local function canManage(node, sUser)
    if not Session.IsHost then return false, "Sólo el DJ puede modificar permisos."; end
    if not isLocation(node) or DB.findNode(DB.getPath(node)) ~= node then
        return false, "La Localización no existe o no es válida.";
    end
    local sOwner = DB.getOwner(node) or "";
    if sOwner ~= "" and sOwner ~= Session.UserName then
        return false, "La Localización pertenece a un jugador; no se modifican sus permisos.";
    end
    if DB.isReadOnly(node) or (DB.getModule(node) or "") ~= "" then
        return false, "Se requiere una Localización editable de campaña.";
    end
    if not validUser(sUser) then return false, "Usuario jugador no válido."; end
    for _, t in ipairs(getKnownUsers()) do
        if t.username == sUser then return true; end
    end
    return false, "El usuario no figura entre los jugadores conocidos.";
end

local function removeGrants(node, sUser)
    local record = permissionRecord(node, false);
    if not record then return; end
    for _, grant in pairs(DB.getChildren(record, "access")) do
        if DB.getValue(grant, "username", "") == sUser then DB.deleteNode(grant); end
    end
end

function setVisibility(node, sUser, bEnabled)
    local bOK, sReason = canManage(node, sUser);
    if not bOK then return false, sReason; end
    if type(bEnabled) ~= "boolean" then return false, "Estado no válido."; end
    if DB.isPublic(node) then
        if bEnabled then return true, "La Localización ya es pública."; end
        return false, "No se puede revocar Visibilidad individual en un registro público.";
    end
    if bEnabled then
        if not hasVisibility(node, sUser) then DB.addHolder(node, sUser, false); end
    else
        removeGrants(node, sUser);
        if hasVisibility(node, sUser) then DB.removeHolder(node, sUser); end
    end
    local bResult = hasVisibility(node, sUser) == bEnabled;
    return bResult, bResult and "Estado verificado en anfitrión." or "No se ha aplicado el estado solicitado.";
end

function setAccess(node, sUser, bEnabled)
    local bOK, sReason = canManage(node, sUser);
    if not bOK then return false, sReason; end
    if type(bEnabled) ~= "boolean" then return false, "Estado no válido."; end
    if not bEnabled then
        removeGrants(node, sUser);
        return findGrant(node, sUser) == nil;
    end
    bOK, sReason = setVisibility(node, sUser, true);
    if not bOK then return false, sReason; end
    if not findGrant(node, sUser) then
        local record = permissionRecord(node, true);
        local grant = record and DB.createChild(record, "access");
        grant = grant and DB.createChild(grant);
        if not grant then return false, "No se pudo crear la concesión de Acceso."; end
        DB.setValue(grant, "username", "string", sUser);
    end
    return hasAccess(node, sUser);
end

local function grantConnected(node, bAccess)
    if not Session.IsHost then return false, "Sólo el DJ puede modificar permisos."; end
    if not isLocation(node) or DB.findNode(DB.getPath(node)) ~= node then
        return false, "La Localización no existe o no es válida.";
    end
    local tResults, bAllOK = {}, true;
    -- Instantánea: no incluye futuros usuarios ni recorre el registro histórico.
    local tUsers = User.getActiveUsers();
    for _, sUser in ipairs(tUsers) do
        if validUser(sUser) then
            rememberUser(sUser);
            local bOK, sReason;
            if bAccess then bOK, sReason = setAccess(node, sUser, true);
            else bOK, sReason = setVisibility(node, sUser, true); end
            table.insert(tResults, { username = sUser, success = bOK, reason = sReason });
            if not bOK then bAllOK = false; end
        end
    end
    return bAllOK, tResults;
end

function grantVisibilityToConnected(node) return grantConnected(node, false); end
function grantAccessToConnected(node) return grantConnected(node, true); end

function subscribe(fn)
    tListeners[fn] = true;
end
function unsubscribe(fn) tListeners[fn] = nil; end

notify = function()
    for fn in pairs(tListeners) do fn(); end
end

local function migrateLegacy(node)
    local legacy = DB.getChild(node, "aptus.access");
    if not legacy then return; end
    local record = permissionRecord(node, true);
    if not record then return; end
    for _, old in pairs(DB.getChildren(legacy)) do
        local sUser = DB.getValue(old, "username", "");
        if validUser(sUser) and not findGrant(node, sUser) then
            local list = DB.createChild(record, "access");
            local grant = list and DB.createChild(list);
            if not grant then return; end
            DB.setValue(grant, "username", "string", sUser);
            if DB.getValue(grant, "username", "") ~= sUser then return; end
        end
    end
    -- Sólo después de copiar: no dejar la lista privada bajo el registro compartido.
    DB.deleteNode(legacy);
end

local function projectionFor(view, node)
    if not view then return nil; end
    local sPath = DB.getValue(view, "state_path", "");
    if not sPath:match("^aptus_location_user_states%.[^.@]+$") then return nil; end
    local state = DB.findNode(sPath);
    if not state then return nil; end
    local _, sTarget = DB.getValue(state, "structure", "", "");
    return sTarget == DB.getPath(node) and state or nil;
end

local function projectAccess(node, record)
    -- Los nombres y rutas de estas asociaciones permanecen en el nodo privado.
    for _, view in pairs(DB.getChildren(record, "views")) do
        local sUser = DB.getValue(view, "username", "");
        if not hasAccess(node, sUser) then
            local state = projectionFor(view, node);
            if state then DB.deleteNode(state); end
            DB.deleteNode(view);
        end
    end
    for _, grant in pairs(DB.getChildren(record, "access")) do
        local sUser = DB.getValue(grant, "username", "");
        if validUser(sUser) and hasAccess(node, sUser) then
            local view;
            for _, candidate in pairs(DB.getChildren(record, "views")) do
                if DB.getValue(candidate, "username", "") == sUser then view = candidate; break; end
            end
            local state = projectionFor(view, node);
            if not state then
                state = DB.createChild(sStates);
                if state then
                    DB.setValue(state, "structure", "windowreference", "aptus_structure", DB.getPath(node));
                    DB.setValue(state, "access", "number", 1);
                    if not view then
                        local list = DB.createChild(record, "views");
                        view = list and DB.createChild(list);
                    end
                    if view then
                        DB.setValue(view, "username", "string", sUser);
                        DB.setValue(view, "state_path", "string", DB.getPath(state));
                    end
                    if not view or DB.getValue(view, "state_path", "") ~= DB.getPath(state) then
                        -- Nunca publicar una proyección que no pueda revocarse desde su asociación.
                        DB.deleteNode(state);
                        state = nil;
                    end
                end
            end
            if state then
                local bHolder = false;
                for _, sHolder in ipairs(DB.getHolders(state)) do
                    if sHolder == sUser then bHolder = true; end
                end
                if not bHolder then DB.addHolder(state, sUser, false); end
            end
        end
    end
end

function refresh()
    if not Session.IsHost or bRefreshing then return; end
    bRefreshing = true;
    for _, sUser in ipairs(User.getActiveUsers()) do rememberUser(sUser); end
    for _, node in pairs(DB.getChildren(APTUSStructureManager.getRootPath())) do
        if isLocation(node) then
            for _, sUser in ipairs(DB.getHolders(node)) do rememberUser(sUser); end
            rememberUser(DB.getOwner(node));
            local sOwner = DB.getOwner(node) or "";
            local bEditable = not DB.isReadOnly(node) and (DB.getModule(node) or "") == ""
                and (sOwner == "" or sOwner == Session.UserName);
            if bEditable then migrateLegacy(node); end
            local record = permissionRecord(node, false);
            for _, grant in pairs(record and DB.getChildren(record, "access") or {}) do
                local sUser = DB.getValue(grant, "username", "");
                rememberUser(sUser);
                -- Una retirada nativa de Visibilidad también invalida la concesión.
                -- No se modifica nunca la compartición desde este observador.
                if validUser(sUser) and not hasVisibility(node, sUser)
                    and bEditable then
                    DB.deleteNode(grant);
                end
            end
            if record and bEditable then projectAccess(node, record); end
        end
    end
    bRefreshing = false;
    notify();
end

function onLogin(sUser, bConnected)
    if not Session.IsHost then return; end
    if bConnected then rememberUser(sUser); end
    refresh(); -- Una desconexión no elimina destinatarios ni concesiones.
end

local function onDataChanged()
    if Session.IsHost then refresh(); else notify(); end
end

local function watch(sPath, sEvent)
    DB.addHandler(sPath, sEvent, onDataChanged);
    table.insert(tHandlers, { path = sPath, event = sEvent });
end

function onTabletopInit()
    watch(sStates, "onChildAdded");
    watch(sStates, "onChildDeleted");
    watch(sStates .. ".*", "onChildUpdate");
    watch(sStates .. ".*.access", "onAdd");
    watch(sStates .. ".*.access", "onUpdate");
    watch(sStates .. ".*.structure", "onAdd");
    watch(sStates .. ".*.structure", "onUpdate");
    if not Session.IsHost then return; end
    DB.createNode(sRoster);
    DB.createNode(sPrivate);
    DB.createNode(sStates);
    refresh();
    User.addEventHandler("onLogin", onLogin);
    local sRoot = APTUSStructureManager.getRootPath();
    watch(sRoot, "onChildAdded");
    watch(sRoot, "onChildDeleted");
    watch(sRoot .. ".*", "onObserverUpdate");
    watch(sRoot .. ".*.type", "onAdd");
    watch(sRoot .. ".*.type", "onUpdate");
    watch(sRoot .. ".*.type", "onDelete");
    watch(sRoot .. ".*.aptus.access", "onChildUpdate");
    watch(sRoot .. ".*.aptus.access", "onChildDeleted");
    watch(sRoot .. ".*.aptus.access.*", "onChildUpdate");
    watch(sRoot .. ".*.aptus.access.*.username", "onUpdate");
    watch(sPrivate, "onChildUpdate");
    watch(sPrivate .. ".*.access", "onChildUpdate");
    watch(sPrivate .. ".*.access", "onChildDeleted");
    watch(sPrivate .. ".*.access.*.username", "onUpdate");
    watch(sRoster, "onChildUpdate");
    watch(sRoster, "onChildDeleted");
end

function onClose()
    if Session.IsHost then User.removeEventHandler("onLogin", onLogin); end
    for _, t in ipairs(tHandlers) do DB.removeHandler(t.path, t.event, onDataChanged); end
    tHandlers, tListeners = {}, {};
end
