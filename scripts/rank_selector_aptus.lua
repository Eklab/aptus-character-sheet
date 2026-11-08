-- Selector nativo mediante menú contextual: no aplica recursos de creación.
local sRankPath;

function onInit()
    sRankPath = DB.getPath(window.getDatabaseNode(), APTUSRank.getPath());
    DB.addHandler(sRankPath, "onUpdate", refreshRank);
    DB.addHandler(sRankPath, "onDelete", refreshRank);
    if APTUSRank.canEdit(window.getDatabaseNode()) then
        for n, tRank in ipairs(APTUSRank.getOptions()) do
            registerMenuItem(tRank.label, "button_edit", n);
        end
    end
    refreshRank();
end

function onClose()
    if not sRankPath then return; end
    DB.removeHandler(sRankPath, "onUpdate", refreshRank);
    DB.removeHandler(sRankPath, "onDelete", refreshRank);
end

function refreshRank()
    local sLabel = APTUSRank.getLabel(window.getDatabaseNode());
    setValue(sLabel);
    setTooltipText("Rango: " .. sLabel .. ". Clic derecho para seleccionar.");
end

function onMenuSelection(selection)
    local tRank = APTUSRank.getOptions()[selection];
    if not tRank then return; end
    if APTUSRank.setRank(window.getDatabaseNode(), tRank.id) then refreshRank(); end
end
