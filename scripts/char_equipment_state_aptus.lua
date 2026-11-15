-- Indicador sin datasource; el diálogo delega cambios al gestor común.
local wState;
local tIcons = {
    Equipado = "aptus_equipo_equipada",
    Transportado = "aptus_equipo_transportado",
};

function refreshDisplay()
    if wState then wState.destroy(); wState = nil; end
    local sValue = self.getValue();
    local sIcon = tIcons[sValue];
    if sIcon then
        local nWidth, nHeight = Interface.getIconSize(sIcon);
        wState = addBitmapWidget({ icon = sIcon, w = nWidth, h = nHeight });
    elseif sValue == "Sin equipar" or sValue == "Contenido" then
        wState = addTextWidget({ font = "aptus_inventory_row_text", text = "—" });
    end
    -- Los widgets nativos se centran por defecto en el control de 32×24.
    setTooltipText(sValue);
end

function onClickDown(button) return button == 1; end
function onClickRelease(button)
    if button == 1 then window.chooseState(); return true; end
end
