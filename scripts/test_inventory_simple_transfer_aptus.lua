-- PRUEBA MANUAL OPT-IN. No incluir en la extensión de uso habitual.
-- Añadir temporalmente como script en una copia de prueba de extension.xml.
-- Nunca crea fixtures ni mueve nada al cargar. Sólo actúa al ejecutar el comando.
local lastRequest,lastContext;
local function show(result)
    ChatManager.SystemMessage("APTUS prueba: "..tostring(result.status).." · "..tostring(result.message)
        .." · destino="..tostring(result.result_path)..(result.replayed and " · solicitud repetida, no ejecutada de nuevo" or ""));
end
function command(_,parameters)
    if parameters=="repeat" then
        if not lastRequest then ChatManager.SystemMessage("No hay solicitud anterior.");return;end
        local id,problem=APTUSInventoryManager.submitSimpleTransferRequest(lastRequest,show,lastContext);
        if not id then ChatManager.SystemMessage(problem);end
        return;
    end
    local args={};for value in parameters:gmatch("%S+")do table.insert(args,value);end
    if #args<3 or #args>5 then
        ChatManager.SystemMessage("Uso: /aptus_simple_transfer_test <objeto> <inventario destino> <cantidad> [contenedor|-] [personaje contexto]. repeat repite la última solicitud.");return;
    end
    local node,owner=DB.findNode(args[1]),DB.findNode(args[2]);
    local parent=args[4] and args[4]~="-" and DB.findNode(args[4]) or nil;
    if not node or not owner or (args[4] and args[4]~="-" and not parent) then ChatManager.SystemMessage("Ruta no encontrada.");return;end
    local context;
    if args[5] then
        local window=Interface.findWindow("charsheet",args[5]);
        if not window or not window.getInventoryContext then ChatManager.SystemMessage("Abre primero la ficha APTUS del personaje de contexto.");return;end
        context=window.getInventoryContext();
    end
    local request,problem=APTUSInventoryManager.buildSimpleTransferRequest(node,owner,tonumber(args[3]),parent,context);
    if not tonumber(args[3]) then ChatManager.SystemMessage("Cantidad no válida.");return;end
    if not request then ChatManager.SystemMessage(problem);return;end
    lastRequest,lastContext=request,context;
    local id,issue=APTUSInventoryManager.submitSimpleTransferRequest(request,show,context);
    if not id then ChatManager.SystemMessage(issue);end
end
function onInit()Comm.registerSlashHandler("aptus_simple_transfer_test",command);end
