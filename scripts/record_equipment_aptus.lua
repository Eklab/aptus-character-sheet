-- Controles sourceless: Guardar confirma una única edición; cerrar descarta el borrador.
local sExpected, sTypeId;
local tCollections;
local sLegacyNote;
local bCopyPending, bCopying, bClosed = false, false, false;
-- Las páginas sólo cambian visibilidad: todos los controles conservan el mismo borrador.
local sActivePage = "data";
local tPages = {
    data = { title = "Datos comunes", y = 214, controls = {
        "label_name", "draft_name", "label_is_wealth", "draft_is_wealth", "label_type", "type_display", "type_change",
        "label_description", "draft_description", "description_scroll", "label_picture", "draft_picture" } },
    container = { title = "Contenedor y Carga", y = 245, controls = {
        "label_stackable", "draft_stackable", "label_max_stack", "draft_max_stack",
        "label_load_every", "draft_load_every", "label_load_value", "draft_load_value",
        "label_is_container", "draft_is_container", "label_capacity", "draft_capacity" } },
    combat = { title = "Combate", y = 276, controls = {
        "section_protections", "separator_protections", "section_requirements", "separator_requirements",
        "label_required_fue", "draft_required_fue", "label_required_agi", "draft_required_agi", "requirements_note",
        "label_pro", "draft_pro", "label_def", "draft_def", "label_agi", "draft_agi",
        "label_per", "draft_per", "section_profiles", "add_profile", "profile_headers", "profile_list", "profile_list_scroll" } },
    qualities = { title = "Cualidades", y = 307, controls = {
        "section_qualities", "add_quality", "quality_list", "quality_list_scroll" } },
};
function applyPage(bEditable)
    for key, page in pairs(tPages) do
        for _, name in ipairs(page.controls) do
            local bShow = key == sActivePage;
            if name == "type_change" or name == "add_profile" or name == "add_quality" then bShow = bShow and bEditable; end
            if name == "requirements_note" then bShow = bShow and sLegacyNote ~= nil; end
            self[name].setVisible(bShow);
        end
        self["nav_label_" .. key].setFont(key == sActivePage and "aptus_font_navigation_black" or "aptus_font_navigation_white");
    end
    page_title.setValue(tPages[sActivePage].title);
    tab_selected.setAnchor("top", "", "top", "absolute", tPages[sActivePage].y);
    save_art.setVisible(bEditable);
end
function selectPage(key)
    if not tPages[key] then return; end
    sActivePage = key;
    update();
end

function onInit()
    reload();
end
function onClose()
    bClosed = true;
    for _, row in ipairs(profile_list.getWindows()) do row.closeConfiguration(); end
end
function reload()
    local node = getDatabaseNode();
    local t = APTUSEquipmentManager.getDraft(node);
    tCollections = t.collections;
    for _, f in ipairs(APTUSEquipmentManager.getFields()) do
        if f.key ~= "type_id" then self["draft_" .. f.key].setValue(t[f.key]); end
    end
    sTypeId = t.type_id;
    type_display.setValue(APTUSEquipmentManager.getTypeName(sTypeId));
    metadata.setValue("ID: " .. DB.getValue(node, "template_id", "sin identidad")
        .. " | Versión: " .. tostring(DB.getValue(node, "template_version", 0))
        .. " | Esquema: " .. tostring(DB.getValue(node, "schema_version", 0)));
    rebuildCollections();
    sExpected = APTUSEquipmentManager.getEditToken(node);
    status.setValue(APTUSEquipmentManager.getConflict(node) or "");
    sLegacyNote = APTUSEquipmentManager.getLegacyRequirements(node);
    requirements_note.setValue(sLegacyNote and "Requisitos anteriores: ver detalle" or "");
    requirements_note.setTooltipText(sLegacyNote or "");
    updatePreview();
    update();
end
function update()
    local node = getDatabaseNode();
    local bEditable = APTUSEquipmentManager.canEdit(node)
        and DB.getValue(node, "schema_version", 0) == 1
        and not APTUSEquipmentManager.getConflict(node);
    for _, f in ipairs(APTUSEquipmentManager.getFields()) do
        if f.key ~= "type_id" then self["draft_" .. f.key].setReadOnly(not bEditable); end
    end
    type_change.setVisible(bEditable);
    save_button.setVisible(bEditable);
    add_quality.setVisible(bEditable);
    add_profile.setVisible(bEditable);
    for _, list in ipairs({ quality_list, profile_list }) do
        for _, w in ipairs(list.getWindows()) do w.setEditable(bEditable); end
    end
    applyPage(bEditable);
    updateDependentFields();
    copy_button.setReadOnly(not canCreateCopy());
    copy_button.setTooltipText(APTUSEquipmentManager.isTemplateConfirmed(node)
        and "Crear una copia independiente de los últimos datos guardados."
        or "Guardar primero la plantilla para habilitar Crear copia.");
end
function canCreateCopy()
    local node = getDatabaseNode();
    return Session.IsHost and not bCopying and not bClosed
        and RecordIndexManager.getEditMode("aptus_equipment")
        and APTUSEquipmentManager.isTemplateConfirmed(node)
        and DB.getValue(node, "schema_version", 0) == 1
        and not APTUSEquipmentManager.getConflict(node);
end
function createCopy()
    if bCopyPending or not canCreateCopy() then return; end
    captureCollections();
    local draft = { type_id = sTypeId, collections = tCollections };
    for _, f in ipairs(APTUSEquipmentManager.getFields()) do
        if f.key ~= "type_id" then draft[f.key] = self["draft_" .. f.key].getValue(); end
    end
    if APTUSEquipmentManager.hasDraftChanges(getDatabaseNode(), draft) then
        bCopyPending = true;
        DialogManager.openDialog("dialog_okcancel", {
            sTitle = "Crear copia",
            sText = "Los cambios sin guardar no se incluirán en la copia. Se utilizará la última versión guardada. ¿Continuar?",
            fnCallback = function(result)
                bCopyPending = false;
                if result == "ok" and not bClosed then performCreateCopy(); end
            end,
        });
    else performCreateCopy(); end
end
function performCreateCopy()
    if not canCreateCopy() then return; end
    local source = getDatabaseNode();
    local path, beforeToken = DB.getPath(source), APTUSEquipmentManager.getEditToken(source);
    local root = RecordDataManager.getDataPathRoot("aptus_equipment");
    local before = {};
    for _, node in pairs(DB.getChildren(root)) do before[DB.getPath(node)] = true; end
    bCopying = true;
    -- El mismo duplicador del catálogo. Abrir sólo tras verificar su resultado.
    local called, result = pcall(CampaignDataManager.duplicateRecord, "aptus_equipment", "aptus_equipment", path, false);
    local added = {};
    for _, node in pairs(DB.getChildren(root)) do
        if not before[DB.getPath(node)] then table.insert(added, node); end
    end
    local problem;
    if not called or not result then problem = "La duplicación nativa no se completó.";
    elseif #added ~= 1 then problem = "No se pudo identificar inequívocamente la nueva plantilla.";
    elseif APTUSEquipmentManager.getEditToken(source) ~= beforeToken then problem = "La plantilla original cambió durante la operación.";
    else problem = APTUSEquipmentManager.getCopyProblem(source, added[1]); end
    bCopying = false;
    if problem then
        -- Sólo se retira un nodo recién creado e inequívoco; nunca el original.
        if #added == 1 then
            local cleaned, cleanupError = pcall(DB.deleteNode, added[1]);
            if not cleaned then Debug.console("APTUS EQUIPO [retirar copia incompleta] " .. tostring(cleanupError)); end
        end
        if not called then Debug.console("APTUS EQUIPO [duplicación] " .. tostring(result)); end
        ChatManager.SystemMessage("Crear copia: " .. problem .. " No se abre una ficha incompleta.");
        return;
    end
    RecordManager.openRecordWindow("aptus_equipment", added[1]);
end
function updateDependentFields()
    if not draft_max_stack or not draft_capacity then return; end
    local bEditable = APTUSEquipmentManager.canEdit(getDatabaseNode())
        and DB.getValue(getDatabaseNode(), "schema_version", 0) == 1
        and not APTUSEquipmentManager.getConflict(getDatabaseNode());
    draft_max_stack.setReadOnly(not bEditable or draft_stackable.getValue() ~= 1);
    draft_capacity.setReadOnly(not bEditable or draft_is_container.getValue() ~= 1);
end
function captureCollections()
    for _, list in ipairs({ quality_list, profile_list }) do
        for _, w in ipairs(list.getWindows()) do w.capture(); end
    end
end
function rebuildCollections()
    local parent = self;
    local bEditable = APTUSEquipmentManager.canEdit(getDatabaseNode())
        and DB.getValue(getDatabaseNode(), "schema_version", 0) == 1
        and not APTUSEquipmentManager.getConflict(getDatabaseNode());
    for _, entry in ipairs({ { "qualities", quality_list, "quality" }, { "profiles", profile_list, "profile" } }) do
        local collection, list, mode = entry[1], entry[2], entry[3];
        for _, w in ipairs(list.getWindows()) do w.close(); end
        local keys = {};
        for key in pairs(tCollections[collection]) do table.insert(keys, key); end
        table.sort(keys);
        local context = { removeEntry = function(key) parent.removeCollectionEntry(collection, key); end,
            isEditable = function() return not bClosed and parent.isAssociationsEditable(); end };
        for _, key in ipairs(keys) do
            local w = list.createWindow();
            w.configure(tCollections[collection][key], context, key, mode, bEditable);
        end
    end
end
function addCollectionEntry(collection)
    if not APTUSEquipmentManager.canEdit(getDatabaseNode()) then return; end
    if collection == "qualities" then configureGeneralQualities(); return; end
    captureCollections();
    if collection ~= "profiles" then return; end
    local newKey = APTUSEquipmentManager.newProfile(tCollections.profiles);
    rebuildCollections();
    for _, row in ipairs(profile_list.getWindows()) do row.openIfKey(newKey); end
end
function isAssociationsEditable()
    return not bClosed and APTUSEquipmentManager.canEdit(getDatabaseNode())
        and DB.getValue(getDatabaseNode(), "schema_version", 0) == 1
        and not APTUSEquipmentManager.getConflict(getDatabaseNode());
end
function configureGeneralQualities()
    if bClosed then return; end
    captureCollections();
    local original = tCollections;
    local token = APTUSQualityManager.associationToken(original.qualities);
    DialogManager.openDialog("aptus_quality_associations", {
        title = "Cualidades de EQUIPO", entries = original.qualities,
        isValid = function() return not bClosed and tCollections == original; end,
        editable = function() return not bClosed and isAssociationsEditable(); end,
        apply = function(values)
            if bClosed or tCollections ~= original or not isAssociationsEditable()
                or APTUSQualityManager.associationToken(original.qualities) ~= token then return false; end
            captureCollections(); original.qualities = values; rebuildCollections(); return true;
        end,
    });
end
function dropGeneralQuality(draginfo)
    if not isAssociationsEditable() then return false; end
    captureCollections();
    if APTUSQualityManager.addFromDrop(tCollections.qualities, draginfo) then rebuildCollections(); end
    return true;
end
function removeCollectionEntry(collection, key)
    if not APTUSEquipmentManager.canEdit(getDatabaseNode()) then return; end
    captureCollections();
    tCollections[collection][key] = nil;
    rebuildCollections();
end
function cycleType()
    if not APTUSEquipmentManager.canEdit(getDatabaseNode()) then return; end
    local t = APTUSEquipmentManager.getTypes();
    local nNext = 1;
    for n, entry in ipairs(t) do if entry.id == sTypeId then nNext = n % #t + 1; break; end end
    sTypeId = t[nNext].id;
    type_display.setValue(t[nNext].name);
end
function updatePreview()
    if preview and draft_picture then preview.setPrototype(draft_picture.getValue() or ""); end
end
function dropPicture(draginfo)
    if not APTUSEquipmentManager.canEdit(getDatabaseNode()) then return false; end
    if not StringManager.contains({ "image", "portrait", "token" }, draginfo.getType()) then return false; end
    local sAsset = draginfo.getTokenData();
    if not sAsset or sAsset == "" then return false; end
    draft_picture.setValue(sAsset);
    updatePreview();
    return true;
end
function save()
    captureCollections();
    local t = { type_id = sTypeId, collections = tCollections };
    for _, f in ipairs(APTUSEquipmentManager.getFields()) do
        if f.key ~= "type_id" then t[f.key] = self["draft_" .. f.key].getValue(); end
    end
    local bOK, sMessage = APTUSEquipmentManager.save(getDatabaseNode(), t, sExpected);
    if bOK then
        -- Confirmación de alta privada; no altera el guardado ni su versionado.
        local confirmed, reason = pcall(APTUSEquipmentManager.confirmTemplateSaved, getDatabaseNode());
        if not confirmed then Debug.console("APTUS EQUIPO [confirmar alta] " .. tostring(reason)); end
        reload();
        local w = WindowManager.getTopWindow(self);
        if w.onNameUpdated then w.onNameUpdated(); end
    end
    status.setValue(sMessage);
    if not bOK then ChatManager.SystemMessage(sMessage); end
end
