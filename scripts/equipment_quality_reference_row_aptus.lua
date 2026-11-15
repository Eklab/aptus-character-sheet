local entry, owner, key, editable;
function onInit() APTUSQualityManager.subscribe(refresh); end
function onClose() APTUSQualityManager.unsubscribe(refresh); end
function configure(t, parent, id, _, canEdit)
    entry, owner, key = t, parent, id;
    setEditable(canEdit); refresh();
end
function capture() end -- Sólo referencias; nunca editar una definición desde EQUIPO.
function setEditable(value) editable = value == true; delete_button.setVisible(editable); end
function refresh()
    if not entry then return; end
    local title, description = APTUSQualityManager.describe(entry);
    summary.setValue(title); summary.setTooltipText(description);
end
function openDefinition()
    if not entry then return; end
    local _, _, node = APTUSQualityManager.describe(entry);
    if node then RecordManager.openRecordWindow("aptus_quality", node);
    else ChatManager.SystemMessage(select(2, APTUSQualityManager.describe(entry))); end
end
function remove() if editable then owner.removeEntry(key); end end
