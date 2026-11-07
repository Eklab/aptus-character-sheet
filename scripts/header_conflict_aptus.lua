local tSubscription;

function onInit()
    local nodeChar = WindowManager.getTopWindow(window).getDatabaseNode();
    if nodeChar then
        tSubscription = APTUSConflicts.subscribe(nodeChar, refreshTitle);
    end
end

function onClose()
    APTUSConflicts.unsubscribe(tSubscription);
end

function refreshTitle()
    local nodeChar = WindowManager.getTopWindow(window).getDatabaseNode();
    if not nodeChar then return; end
    local tTitles = APTUSConflicts.getHeaderTitles(nodeChar);
    setValue(tTitles[tonumber(conflict_index[1])] or "");
end
