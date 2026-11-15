-- Contenedor nativo sin datasource ni guardado propio.
local configured, closed;
function configure(entry, owner, key, notify)
    closed = notify;
    form.subwindow.configure(entry, owner, key, "profile", true);
    configured = true;
end
function capture()
    if configured and form.subwindow then form.subwindow.capture(); end
end
function onClose()
    capture();
    if closed then closed(); end
end
