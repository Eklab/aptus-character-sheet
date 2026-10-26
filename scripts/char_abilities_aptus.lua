function onInit()
    aptus_skills_list.applyFilter()
    aptus_skills_list.applySort()
end


function openSkillsEditor()
    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return
    end

    Interface.openWindow("aptus_skills_editor", nodeChar)
end

-- Recibe habilidades arrastradas desde el catálogo APTUS
function onDrop(x, y, draginfo)
    if draginfo.getType() ~= "shortcut" then
        return false
    end

    local sClass, sRecord = draginfo.getShortcutData()

    -- Solo aceptamos registros de habilidades APTUS
    if sClass ~= "aptus_skill" then
        return false
    end

    local nodeSource = DB.findNode(sRecord)

    if not nodeSource then
        return false
    end

    local nodeChar = getDatabaseNode()

    if not nodeChar then
        return false
    end

    local nodeSkills = DB.createChild(nodeChar, "skills")

    if not nodeSkills then
        return false
    end

    -- Identificamos la habilidad por su referencia de origen
    local sSource = nodeSource.getPath()

    -- Comprobamos que no esté incorporada previamente
    for _, nodeSkill in pairs(DB.getChildren(nodeSkills)) do
        if DB.getValue(nodeSkill, "source", "") == sSource then
            return true
        end
    end

    -- Creamos la habilidad en el personaje
    local nodeSkill = DB.createChild(nodeSkills)

    if not nodeSkill then
        return false
    end

    DB.setValue(nodeSkill, "name", "string",
        DB.getValue(nodeSource, "name", ""))

    DB.setValue(nodeSkill, "attribute", "string",
        DB.getValue(nodeSource, "attribute", ""))

    DB.setValue(nodeSkill, "default_attribute", "string",
        DB.getValue(nodeSource, "attribute", ""))

    DB.setValue(nodeSkill, "level", "number", 0)

    DB.setValue(nodeSkill, "special", "number",
        DB.getValue(nodeSource, "special", 0))

    DB.setValue(nodeSkill, "source", "string", sSource)

    aptus_skills_list.applyFilter()

    return true
end

-- Todas las habilidades del personaje
function filterSkills(w)
    return w.getDatabaseNode() ~= nil
end

-- Habilidad Genérica primero; resto alfabéticamente
function sortSkills(w1, w2)
    local node1 = w1.getDatabaseNode()
    local node2 = w2.getDatabaseNode()

    if not node1 or not node2 then
        return false
    end

    local id1 = DB.getValue(node1, "id", "")
    local id2 = DB.getValue(node2, "id", "")

    -- Habilidad Genérica siempre al final
    if id1 == "generic_skill" then
        return true
    end

    if id2 == "generic_skill" then
        return false
    end

    -- Orden alfabético ascendente en pantalla
    local name1 = DB.getValue(node1, "name", ""):lower()
    local name2 = DB.getValue(node2, "name", ""):lower()

    return name1 > name2
end