function addSkill()
    local nodeChar = getDatabaseNode()
    if not nodeChar then
        return
    end

    local nodeSkills = DB.createChild(nodeChar, "skills")
    if not nodeSkills then
        return
    end

    local nodeSkill = DB.createChild(nodeSkills)
    if not nodeSkill then
        return
    end

    local sID = "custom_" .. DB.getName(nodeSkill)

    DB.setValue(nodeSkill, "id", "string", sID)
    DB.setValue(nodeSkill, "name", "string", "Nueva habilidad")
    DB.setValue(nodeSkill, "attribute", "string", "agi")
    DB.setValue(nodeSkill, "default_attribute", "string", "agi")
    DB.setValue(nodeSkill, "level", "number", 0)
    DB.setValue(nodeSkill, "special", "number", 1)
end