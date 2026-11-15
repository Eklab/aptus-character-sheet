local data, entries;
function setData(t)
    data, entries = t, APTUSQualityManager.clone(t.entries);
    title.setValue(t.title or "Cualidades asociadas");
    refresh();
end
function refresh()
    if not entries then return; end
    for _, w in ipairs(list.getWindows()) do w.close(); end
    local keys = {}; for key in pairs(entries) do table.insert(keys, key); end; table.sort(keys);
    local editable = data.isValid() and data.editable();
    for _, key in ipairs(keys) do local w = list.createWindow(); w.configure(entries[key], self, key, "reference", editable); end
    save_button.setVisible(editable);
    save_art.setVisible(editable);
end
function drop(draginfo)
    if not data or not data.isValid() or not data.editable() then return false; end
    local added = APTUSQualityManager.addFromDrop(entries, draginfo);
    if added then refresh(); end
    return true; -- Consumir el gesto; no crear objetos nativos ni duplicar definiciones.
end
function removeEntry(key)
    if not data or not data.isValid() or not data.editable() then return; end
    entries[key] = nil; refresh();
end
function save()
    if not data or not data.isValid() or not data.editable() then
        ChatManager.SystemMessage("El borrador de EQUIPO ya no está disponible. Cerrar y abrir de nuevo la configuración."); return;
    end
    if data.apply(APTUSQualityManager.clone(entries)) then close();
    else ChatManager.SystemMessage("Las asociaciones cambiaron mientras esta ventana estaba abierta. Descartar y volver a abrir."); end
end
function onClose()
    DialogManager.onDialogClose("cancel", data);
end
