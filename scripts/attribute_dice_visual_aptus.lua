-- Sólo presentación: widget nativo, ajustado sin deformar el recurso de la SKIN.
local wDice;

function onInit()
    APTUSSkin.subscribe(window, updateSkin);
end

function onClose()
    APTUSSkin.unsubscribe(window, updateSkin);
end

function updateSkin()
    if wDice then wDice.destroy(); wDice = nil; end
    local sIcon = APTUSSkin.getIcon(window, "aptus_attribute_dice");
    if sIcon == "" then return; end
    local nWidth, nHeight = Interface.getIconSize(sIcon);
    if not nWidth or not nHeight or nWidth <= 0 or nHeight <= 0 then return; end
    local nScale = math.min(26 / nWidth, 26 / nHeight);
    wDice = addBitmapWidget({
        icon = sIcon,
        w = math.floor(nWidth * nScale + 0.5),
        h = math.floor(nHeight * nScale + 0.5),
    });
end
