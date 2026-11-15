-- Ventana local sin datasource: sólo confirmar una opción ejecuta el callback.
local apply;
function configure(current, callback)
    apply = callback;
    for value = 0, 2 do
        self["current_" .. value].setVisible(value == current);
    end
end
function onClose() apply = nil; end
function selectState(value)
    if value ~= 0 and value ~= 1 and value ~= 2 then return; end
    local callback = apply;
    apply = nil;
    close();
    if callback then callback(value); end
end
