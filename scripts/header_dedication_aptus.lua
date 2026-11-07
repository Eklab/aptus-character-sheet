local nodeChar;
local tSubscription;
local sAgePath;

function onInit()
    nodeChar = WindowManager.getTopWindow(window).getDatabaseNode();
    if not nodeChar then return; end
    sAgePath = DB.getPath(nodeChar, "age");
    DB.addHandler(sAgePath, "onUpdate", refreshDetails);
    DB.addHandler(sAgePath, "onDelete", refreshDetails);
    tSubscription = APTUSDedication.subscribe(nodeChar, refreshDetails);
    refreshDetails();
end

function onClose()
    APTUSDedication.unsubscribe(tSubscription);
    if sAgePath then
        DB.removeHandler(sAgePath, "onUpdate", refreshDetails);
        DB.removeHandler(sAgePath, "onDelete", refreshDetails);
    end
end

function refreshDetails()
    if not nodeChar then return; end
    local sDedication = APTUSDedication.getDisplayName(nodeChar, tSubscription);
    local sAge = tostring(DB.getValue(nodeChar, "age", ""));
    if sDedication == "" then sDedication = "—"; end
    if sAge == "" then sAge = "—"; end
    -- Rango sigue siendo el texto provisional existente: no se crea un nodo nuevo.
    setValue(string.format("%s - %s años - Novato", sDedication, sAge));
end
