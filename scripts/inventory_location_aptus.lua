-- Conserva el selector de CoreRPG. Cancela opciones antiguas si cambia la ocultación.
local watchedPath;
local closed = false;
local function unwatch()
    if not watchedPath then return; end
    for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do
        DB.removeHandler(watchedPath, event, onContentsVisibilityChanged);
    end
    watchedPath = nil;
end
function onContentsVisibilityChanged()
    if not closed then close(); end
end
function activateNextSelection()
    unwatch();
    if #getSelectionQueue() == 0 then super.activateNextSelection(); return; end
    super.activateNextSelection();
    if closed or Session.IsHost then return; end
    local queue = getSelectionQueue();
    local first = queue[1] and queue[1].options and queue[1].options[1];
    if not first or (first.linkclass ~= "charsheet" and first.linkclass ~= "aptus_structure") then return; end
    watchedPath = first.linkrecord .. ".inventorylist.*.properties.hide_contents";
    for _, event in ipairs({"onAdd", "onUpdate", "onDelete"}) do
        DB.addHandler(watchedPath, event, onContentsVisibilityChanged);
    end
end
function onClose()
    closed = true;
    unwatch();
end
