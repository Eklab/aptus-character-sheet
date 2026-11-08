local tSubscription;
local bRefreshing = false;
local bEditing = false;
local bReady = false;

function onInit()
    tSubscription = APTUSDedication.subscribe(getDatabaseNode(), refreshView);
    refreshView();
    bReady = true;
end

function onClose()
    bReady = false;
    APTUSDedication.unsubscribe(tSubscription);
end

function onLockModeChanged(bReadOnly)
    dedication.setReadOnly(bReadOnly);
end

function refreshView()
    local nodeChar = getDatabaseNode();
    bRefreshing = true;
    dedication.setReadOnly(not APTUSDedication.canEdit(nodeChar));
    if not bEditing then
        local sName = APTUSDedication.getDisplayName(nodeChar);
        if dedication.getValue() ~= sName then dedication.setValue(sName); end
    end
    local nodeClass = APTUSDedication.getClassRecord(nodeChar);
    description.setValue(nodeClass and DB.getValue(nodeClass, "description", "") or "");
    special.setValue(nodeClass and DB.getValue(nodeClass, "special", "") or "");
    illustration.setAsset("");
    illustration.setIcon("");
    local sAsset = nodeClass and DB.getValue(nodeClass, "picture", "") or "";
    if sAsset ~= "" then
        illustration.setDrawMode("fit");
        illustration.setAsset(sAsset);
    end
    bRefreshing = false;
end

function onDedicationEdited(sValue)
    if not bReady or bRefreshing then return; end
    bEditing = true;
    local bSaved = APTUSDedication.setFreeText(getDatabaseNode(), sValue);
    bEditing = false;
    if not bSaved then refreshView(); end
end

function onDedicationDrop(draginfo)
    return APTUSDedication.assignFromDrop(getDatabaseNode(), draginfo);
end
