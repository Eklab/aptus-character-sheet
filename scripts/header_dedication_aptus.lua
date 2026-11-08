local nodeChar;
local tSubscription;
local sAgePath;
local sRankPath;

function onInit()
    nodeChar = WindowManager.getTopWindow(window).getDatabaseNode();
    if not nodeChar then return; end
    sAgePath = DB.getPath(nodeChar, "age");
    sRankPath = DB.getPath(nodeChar, APTUSRank.getPath());
    DB.addHandler(sRankPath, "onUpdate", refreshDetails);
    DB.addHandler(sRankPath, "onDelete", refreshDetails);
    DB.addHandler(sAgePath, "onUpdate", refreshDetails);
    DB.addHandler(sAgePath, "onDelete", refreshDetails);
    tSubscription = APTUSDedication.subscribe(nodeChar, refreshDetails);
    refreshDetails();
end

function onClose()
    APTUSDedication.unsubscribe(tSubscription);
    if sRankPath then
        DB.removeHandler(sRankPath, "onUpdate", refreshDetails);
        DB.removeHandler(sRankPath, "onDelete", refreshDetails);
    end
    if sAgePath then
        DB.removeHandler(sAgePath, "onUpdate", refreshDetails);
        DB.removeHandler(sAgePath, "onDelete", refreshDetails);
    end
end

function refreshDetails()
    if not nodeChar then return; end
    local sDedication = APTUSDedication.getDisplayName(nodeChar);
    local sAge = tostring(DB.getValue(nodeChar, "age", ""));
    if sDedication == "" then sDedication = "—"; end
    if sAge == "" then sAge = "—"; end
    setValue(string.format("%s - %s años - %s", sDedication, sAge, APTUSRank.getLabel(nodeChar)));
end
