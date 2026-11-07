-- Textos narrativos independientes; sin inicialización ni migración de valores.
function onInit()
    onLockModeChanged(WindowManager.getWindowReadOnlyState(self));
end

function onLockModeChanged(bReadOnly)
    WindowManager.callSafeControlsSetLockMode(self, {
        "aptus.identity.history.past", "aptus.identity.history.present",
    }, bReadOnly);
end
