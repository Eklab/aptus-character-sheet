-- Apariencia nativa, estado de ventana sin enlace automático a DB.
-- Inicializar/cambiar la presentación del botón nunca escribe locked.
local updating = true;
function onInit()
    ToolbarManager.initButtonField(self, "locked");
    setColor(ColorManager.getWindowMenuIconColor());
    setValue(1);
    updating = false;
end
function setLocked(value)
    updating = true;
    setValue(value and 1 or 0);
    updating = false;
end
function onValueChanged()
    if updating then return; end
    WindowManager.getTopWindow(window).onInstanceLockChanged(getValue() ~= 0);
end
