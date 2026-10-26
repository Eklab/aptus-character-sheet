-- APTUS - Combat Tracker
-- Sincronización de heridas entre PJ y Combat Tracker

local bSyncing = false;

function onInit()
    if not Session.IsHost then
        return;
    end

    DB.addHandler("combattracker.list.*.wounds", "onUpdate", onCTWoundsChanged);
    DB.addHandler("charsheet.*.wounds", "onUpdate", onCharacterWoundsChanged);
    DB.addHandler("combattracker.list.*.link", "onUpdate", onCombatantLinked);
end

function onClose()
    if not Session.IsHost then
        return;
    end

    DB.removeHandler("combattracker.list.*.wounds", "onUpdate", onCTWoundsChanged);
    DB.removeHandler("charsheet.*.wounds", "onUpdate", onCharacterWoundsChanged);
    DB.removeHandler("combattracker.list.*.link", "onUpdate", onCombatantLinked);
end

local function clampWounds(n)
    return math.max(0, math.min(7, tonumber(n) or 0));
end

local function setWounds(node, n)
    if not node then
        return;
    end

    n = clampWounds(n);

    if DB.getValue(node, "wounds", 0) ~= n then
        DB.setValue(node, "wounds", "number", n);
    end
end

function onCTWoundsChanged(nodeWounds)
    if bSyncing then
        return;
    end

    local nodeCT = DB.getParent(nodeWounds);
    if not nodeCT then
        return;
    end

    local _, sCharPath = DB.getValue(nodeCT, "link", "", "");
    if not sCharPath or sCharPath == "" then
        return;
    end

    local nodeChar = DB.findNode(sCharPath);
    if not nodeChar then
        return;
    end

    bSyncing = true;
    setWounds(nodeChar, DB.getValue(nodeWounds));
    bSyncing = false;
end

function onCharacterWoundsChanged(nodeWounds)
    if bSyncing then
        return;
    end

    local nodeChar = DB.getParent(nodeWounds);
    if not nodeChar then
        return;
    end

    local nodeCT = CombatManager.getCTFromNode(nodeChar);
    if not nodeCT then
        return;
    end

    bSyncing = true;
    setWounds(nodeCT, DB.getValue(nodeWounds));
    bSyncing = false;
end

-- Inicializar heridas cuando se vincula una ficha al Combat Tracker
function onCombatantLinked(nodeLink)
    if not Session.IsHost then
        return;
    end

    local nodeCT = DB.getParent(nodeLink);

    if not nodeCT then
        return;
    end

    local _, sCharPath = DB.getValue(nodeCT, "link", "", "");

    if not sCharPath or not string.match(sCharPath, "^charsheet%.") then
        return;
    end

    local nodeChar = DB.findNode(sCharPath);

    if not nodeChar then
        return;
    end

    local nWounds = DB.getValue(nodeChar, "wounds", 0);
    nWounds = math.max(0, math.min(7, nWounds));

    DB.setValue(nodeCT, "wounds", "number", nWounds);
end