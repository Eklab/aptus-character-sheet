function update()
    local node = getDatabaseNode();
    local bAllowed = APTUSStructureManager.isFeatureActive(node, "storage")
        and (Session.IsHost or APTUSLocationPermissions.hasAccess(node, Session.UserName));
    title.setVisible(bAllowed);
    hint.setVisible(bAllowed);
    return bAllowed;
end

function onInit()
    if not update() then close(); end
end
