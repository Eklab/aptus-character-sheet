-- Borrador local de instancia. Reutiliza controles/cualidades/perfiles del catálogo,
-- pero nunca sus funciones de guardado, copia o creación de plantillas.
local sExpected, sTypeId;
local tCollections;
local sPage = "data";
local bClosed = false;
local bAction = false;
local bDeletePending = false;
local bLastEditable;
local bMessageError = false;
local nMessageProtectedUntil = 0;
local headerWidget;
local sMessage, sMessageDetail = "", "";
local tEditorVisibility;
local sConsultationClass;
-- Registro local por identificador interno. Añadir aquí sólo vistas implementadas.
local tConsultationViews = { melee_weapon={ class="aptus_item_melee_view", background="aptus_item_melee_background" } };

function isViewLocked()
    local top = WindowManager.getTopWindow(self);
    if top.isInstanceLocked then return top.isInstanceLocked(); end
    return DB.getValue(getDatabaseNode(), "locked", 0) ~= 0;
end
function canEditCurrentInstance()
    return not isViewLocked() and APTUSInventoryManager.canEditInstance(getDatabaseNode());
end

function getConsultationClass()
    if not isViewLocked() then return nil; end
    local view = tConsultationViews[DB.getValue(getDatabaseNode(), "properties.type_id", "")];
    return view and view.class;
end
function restoreEditorControls()
    if not tEditorVisibility then return; end
    for _, entry in ipairs(tEditorVisibility) do entry.control.setVisible(entry.visible); end
    tEditorVisibility = nil;
end
function applyPresentation()
    local class = getConsultationClass();
    if not class then
        consultation.setVisible(false);
        consult_background.setVisible(false);
        return;
    end
    tEditorVisibility = {};
    for _, control in ipairs(getControls()) do
        local name = control.getName();
        if name ~= "metadata" and name ~= "consultation" and name ~= "consult_background" then
            table.insert(tEditorVisibility, { control=control, visible=control.isVisible() });
            control.setVisible(false);
        end
    end
    consult_background.setIcon(tConsultationViews[DB.getValue(getDatabaseNode(), "properties.type_id", "")].background);
    consult_background.sendToBack();
    consult_background.setVisible(true);
    if sConsultationClass ~= class then
        sConsultationClass = class;
        consultation.setValue(class, DB.getPath(getDatabaseNode()));
    end
    consultation.setVisible(true);
    onConsultationCreated();
end
function onConsultationCreated()
    -- CoreRPG puede instanciar el subwindow sólo al dibujarlo por primera vez.
    if consultation.subwindow then consultation.subwindow.configure(self, bDeletePending); end
end
function getMessage() return sMessage, sMessageDetail; end
function onPersistentDataChanged()
    if bClosed or bAction then return; end
    update();
end
local tPages = {
    data = { title="Datos de instancia", y=214, controls={ "label_name", "draft_name", "label_is_wealth", "draft_is_wealth", "label_type", "type_display", "type_change",
        "label_description", "draft_description", "description_scroll", "label_picture", "draft_picture" } },
    container = { title="Contenedor y Carga", y=245, controls={ "label_stackable", "draft_stackable", "label_max_stack", "draft_max_stack",
        "label_load_every", "draft_load_every", "label_load_value", "draft_load_value", "label_is_container", "draft_is_container", "label_capacity", "draft_capacity" } },
    combat = { title="Propiedades de combate", y=276, controls={ "section_protections", "separator_protections", "section_requirements", "separator_requirements",
        "label_required_fue", "draft_required_fue", "label_required_agi", "draft_required_agi", "label_pro", "draft_pro", "label_def", "draft_def", "label_agi", "draft_agi",
        "label_per", "draft_per", "section_profiles", "add_profile", "profile_headers", "profile_list", "profile_list_scroll" } },
    qualities = { title="Cualidades de instancia", y=307, controls={ "section_qualities", "add_quality", "quality_list", "quality_list_scroll" } },
};

function onInit()
    instance_context.setValue("");
    instance_context.setTooltipText("");
    reload();
end
function onFirstLayout() updateHeader(); end
function onClose()
    bClosed = true;
    for _, row in ipairs(profile_list.getWindows()) do row.closeConfiguration(); end
end

-- Sólo presentación local. Sin temporizadores, escrituras DB ni notificaciones globales.
function showMessage(message, kind, detail)
    if bClosed then return; end
    if kind == "mode" and (bAction or bMessageError or os.time() < nMessageProtectedUntil) then return; end
    sMessage, sMessageDetail = message, detail or message;
    instance_context.setValue(message);
    instance_context.setTooltipText(sMessageDetail);
    if consultation.subwindow then consultation.subwindow.setMessage(sMessage, sMessageDetail); end
    bMessageError = kind == "error";
    nMessageProtectedUntil = kind == "confirmation" and (os.time() + 3) or 0;
end

function updateHeader()
    if bClosed or bAction then return; end
    local node = getDatabaseNode();
    local title = DB.getValue(node, "name", "");
    if not getConsultationClass() then
        title = title .. " (" .. APTUSEquipmentManager.getTypeName(DB.getValue(node, "properties.type_id", "")) .. ")";
    end
    local origin = "Plantilla: " .. DB.getValue(node, "template_id", "")
        .. " · versión " .. tostring(DB.getValue(node, "template_version", 0));
    metadata.setValue("");
    if not headerWidget then headerWidget = metadata.addTextWidget({ font=metadata.getFont(), text="" }); end
    headerWidget.setText((title:gsub("[\r\n\t]", " ")));
    local width = metadata.getSize();
    headerWidget.setMaxWidth(math.max(1, width));
    local textWidth = headerWidget.getSize();
    headerWidget.setPosition("left", math.floor(textWidth / 2), 0);
    metadata.setTooltipText(title .. "\n" .. origin);
end

function selectPage(key)
    if not tPages[key] then return; end
    sPage = key;
    update();
end

function onLockModeChanged() update(); end

function update()
    restoreEditorControls();
    if tCollections then captureCollections(); end
    local editable = not bClosed and canEditCurrentInstance();
    local allowed = {};
    for _, f in ipairs(APTUSInventoryManager.getEditableFields()) do allowed[f.key] = true; end
    for _, f in ipairs(APTUSEquipmentManager.getFields()) do
        if f.key ~= "type_id" then self["draft_" .. f.key].setReadOnly(not editable or not allowed[f.key]); end
    end
    for key, page in pairs(tPages) do
        for _, name in ipairs(page.controls) do
            local visible = key == sPage;
            if name == "type_change" or name == "add_profile" or name == "add_quality" then visible = visible and editable; end
            self[name].setVisible(visible);
        end
        self["nav_label_" .. key].setFont(key == sPage and "aptus_font_navigation_black" or "aptus_font_navigation_white");
    end
    type_change_art.setVisible(sPage == "data" and editable);
    for _, list in ipairs({ quality_list, profile_list }) do
        for _, row in ipairs(list.getWindows()) do row.setEditable(editable); end
    end
    requirements_note.setVisible(false);
    page_title.setValue(tPages[sPage].title);
    page_title.setAnchor("left", "", "left", "absolute", sPage == "combat" and 219 or 224);
    tab_selected.setAnchor("top", "", "top", "absolute", tPages[sPage].y);
    save_button.setVisible(editable);
    save_art.setVisible(editable);
    discard_button.setVisible(editable);
    discard_art.setVisible(editable);
    updateDependentFields();
    delete_button.setReadOnly(bDeletePending or not APTUSInventoryManager.canDeleteInstance(getDatabaseNode()));
    if bLastEditable ~= editable then
        -- La primera lectura bloqueada no es un cambio de modo ni genera mensajes.
        if bLastEditable ~= nil or editable then
            showMessage(editable and "Edición activa." or "Edición desactivada.", "mode");
        end
        bLastEditable = editable;
    end
    applyPresentation();
    updateHeader();
end

function reload()
    if bClosed then return; end
    local node = getDatabaseNode();
    if not APTUSInventoryManager.canViewInstance(node) then WindowManager.getTopWindow(self).close(); return; end
    -- getDraft sólo lee; no ejecuta el guardado ni materializa valores predeterminados.
    local draft = APTUSInventoryManager.getInstanceDraft(node);
    tCollections = draft.collections;
    sTypeId = draft.type_id;
    for _, f in ipairs(APTUSEquipmentManager.getFields()) do
        if f.key ~= "type_id" then
            local value = draft[f.key];
            if f.kind == "number" and (type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge) then value = f.default; end
            if f.kind ~= "number" and type(value) ~= "string" then value = f.default; end
            self["draft_" .. f.key].setValue(value);
        end
    end
    draft_hide_contents.setValue(draft.hide_contents or 0);
    type_display.setValue(APTUSEquipmentManager.getTypeName(draft.type_id));
    updateHeader();
    sExpected = APTUSInventoryManager.getInstanceEditToken(node);
    rebuildCollections();
    updatePreview();
    update();
end

function captureCollections()
    for _, list in ipairs({ quality_list, profile_list }) do
        for _, w in ipairs(list.getWindows()) do w.capture(); end
    end
end
function rebuildCollections()
    local parent = self;
    local bEditable = APTUSInventoryManager.canEditInstance(getDatabaseNode());
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
    if not APTUSInventoryManager.canEditInstance(getDatabaseNode()) then return; end
    if collection == "qualities" then configureGeneralQualities(); return; end
    captureCollections();
    if collection ~= "profiles" then return; end
    local newKey = APTUSEquipmentManager.newProfile(tCollections.profiles);
    rebuildCollections();
    for _, row in ipairs(profile_list.getWindows()) do row.openIfKey(newKey); end
end
function isAssociationsEditable()
    return not bClosed and APTUSInventoryManager.canEditInstance(getDatabaseNode());
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
    if not APTUSInventoryManager.canEditInstance(getDatabaseNode()) then return; end
    captureCollections();
    tCollections[collection][key] = nil;
    rebuildCollections();
end
function updateDependentFields()
    if not draft_capacity then return; end
    local editable = not bClosed and APTUSInventoryManager.canEditInstance(getDatabaseNode());
    draft_max_stack.setReadOnly(not editable or draft_stackable.getValue() ~= 1);
    draft_capacity.setReadOnly(not editable or draft_is_container.getValue() ~= 1);
    local visible = Session.IsHost and sPage == "container" and draft_is_container.getValue() == 1;
    label_hide_contents.setVisible(visible);
    draft_hide_contents.setVisible(visible);
    draft_hide_contents.setReadOnly(not visible or not canEditCurrentInstance());
end

function save()
    if bClosed or not canEditCurrentInstance() then return; end
    captureCollections();
    local draft = { collections=tCollections };
    for _, f in ipairs(APTUSInventoryManager.getEditableFields()) do
        draft[f.key] = f.key == "type_id" and sTypeId or self["draft_" .. f.key].getValue();
    end
    if draft.is_container == 1 then draft.stackable = 0; draft.max_stack = 1; end
    bAction = true;
    local ok, message = APTUSInventoryManager.saveInstance(getDatabaseNode(), draft, sExpected);
    if ok then
        reload();
        local w = WindowManager.getTopWindow(self);
        if w.onNameUpdated then w.onNameUpdated(); end
    end
    bAction = false;
    updateHeader();
    showMessage(ok and "Instancia guardada." or "No se han podido guardar los cambios.",
        ok and "confirmation" or "error", message);
end

function discard()
    if bClosed then return; end
    bAction = true;
    reload();
    bAction = false;
    updateHeader();
    showMessage("Cambios descartados.", "confirmation");
end

-- La ventana sólo solicita la operación; el gestor confirma y elimina.
function requestDelete()
    if bClosed or bDeletePending then return; end
    bDeletePending = true;
    update();
    APTUSInventoryManager.requestDeleteInstance(getDatabaseNode(), function(ok, message, outcome)
        if bClosed then return; end
        bDeletePending = false;
        update();
        if ok then WindowManager.getTopWindow(self).close();
        else showMessage(message, outcome == "cancelled" and "confirmation" or "error"); end
    end, function() return not bClosed; end);
end

function updatePreview()
    if preview and draft_picture then preview.setPrototype(draft_picture.getValue() or ""); end
end
function dropPicture(draginfo)
    if not APTUSInventoryManager.canEditInstance(getDatabaseNode()) then return false; end
    if not StringManager.contains({ "image", "portrait", "token" }, draginfo.getType()) then return false; end
    local asset = draginfo.getTokenData();
    if not asset or asset == "" then return false; end
    draft_picture.setValue(asset);
    updatePreview();
    return true;
end

-- Métodos heredados de plantilla anulados: no existe ningún camino de edición de catálogo.
function canCreateCopy() return false; end
function createCopy() end
function performCreateCopy() end
function cycleType()
    if not isAssociationsEditable() then return; end
    local types = APTUSEquipmentManager.getTypes();
    local nextIndex = 1;
    for index, entry in ipairs(types) do if entry.id == sTypeId then nextIndex = index % #types + 1; break; end end
    if types[nextIndex] then sTypeId = types[nextIndex].id; type_display.setValue(types[nextIndex].name); end
end
