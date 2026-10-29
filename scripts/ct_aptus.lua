-- APTUS - Combat Tracker
-- Sincronización de heridas e iniciativa entre PJ y Combat Tracker

local bSyncing = false;
local OOB_MSGTYPE_INITIATIVE = "aptus_initiative";
local fPreviousPostResolve = nil;

function onInit()
    fPreviousPostResolve = GameManager.getMultiKeyFunction("onActionPostResolve", "aptus");
    GameManager.setMultiKeyFunction("onActionPostResolve", "aptus", onAptusPostResolve);
    if not Session.IsHost then
        return;
    end

    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_INITIATIVE, onInitiativeMessage);

    DB.addHandler("combattracker.list.*.wounds", "onUpdate", onCTWoundsChanged);
    DB.addHandler("charsheet.*.wounds", "onUpdate", onCharacterWoundsChanged);
    DB.addHandler("combattracker.list.*.link", "onUpdate", onCombatantLinked);
end

function onClose()
    if GameManager.getMultiKeyFunction("onActionPostResolve", "aptus") == onAptusPostResolve then
        GameManager.setMultiKeyFunction("onActionPostResolve", "aptus", fPreviousPostResolve);
    end
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

-- Se ejecuta en la sesión que resuelve la tirada, también para jugadores.
function onAptusPostResolve(rSource, rTarget, rRoll)
    if fPreviousPostResolve then
        fPreviousPostResolve(rSource, rTarget, rRoll);
    end

    if not rRoll or rRoll.sType ~= "aptus"
        or rRoll.bAptusInitiative ~= true
        or rRoll.bAptusResolved ~= true
        or not (rRoll.sDesc or ""):find("[MODO:QUANTIFICATION]", 1, true) then
        return;
    end

    local sCharPath = ActorManager.getCreatureNodeName(rSource);
    local nInitiative = tonumber(rRoll.nAptusSuccesses);
    if not sCharPath or not sCharPath:match("^charsheet%.[^%.]+$")
        or not nInitiative or nInitiative < 0
        or nInitiative == math.huge or nInitiative ~= math.floor(nInitiative) then
        return;
    end

    if Session.IsHost then
        applyInitiative(sCharPath, nInitiative);
    else
        Comm.deliverOOBMessage({
            type = OOB_MSGTYPE_INITIATIVE,
            sCharPath = sCharPath,
            nInitiative = nInitiative,
        }, "");
    end
end

function onInitiativeMessage(msgOOB)
    if not Session.IsHost then
        return;
    end

    applyInitiative(msgOOB.sCharPath, msgOOB.nInitiative);
end

function applyInitiative(sCharPath, nInitiative)
    if not Session.IsHost or type(sCharPath) ~= "string"
        or not sCharPath:match("^charsheet%.[^%.]+$") then
        return;
    end

    nInitiative = tonumber(nInitiative);
    if not nInitiative or nInitiative < 0
        or nInitiative == math.huge or nInitiative ~= math.floor(nInitiative) then
        return;
    end

    local nodeChar = DB.findNode(sCharPath);
    if not nodeChar then
        return;
    end

    local nodeCT = CombatManager.getCTFromNode(nodeChar);
    if nodeCT then
        -- Sustituir el valor previo, incluso cuando el nuevo resultado es cero.
        DB.setValue(nodeCT, "initresult", "number", nInitiative);
    end
end
