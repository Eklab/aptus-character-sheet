-- Control gráfico genérico. No modifica coordenadas, tamaños ni datos del personaje.
local sLastIcon;
local sResourceOverride;

function onInit()
    APTUSSkin.subscribe(window, updateSkin);
end

function onClose()
    APTUSSkin.unsubscribe(window, updateSkin);
end

function updateSkin()
    local sResource = sResourceOverride or (skin_resource and skin_resource[1]);
    if not sResource then return; end
    local sIcon = APTUSSkin.getIcon(window, sResource);
    if sIcon == sLastIcon then return; end
    sLastIcon = sIcon;
    setIcon(sIcon);
end

-- Permite cambiar el fondo de una subsección sin perder su suscripción de SKIN.
function setSkinResource(sResource)
    sResourceOverride = sResource;
    updateSkin();
end
