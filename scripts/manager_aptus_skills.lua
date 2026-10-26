--------------------------------------------------
-- APTUS - CATÁLOGO DE HABILIDADES
--------------------------------------------------

local aCommonSkills = {
    { id = "acrobacias",      name = "Acrobacias",       attribute = "agi" },
    { id = "alerta",          name = "Alerta",           attribute = "per" },
    { id = "atletismo",       name = "Atletismo",        attribute = "fue" },
    { id = "ave_intenciones", name = "Ave. Intenciones", attribute = "per" },
    { id = "conducir",        name = "Conducir",         attribute = "agi" },
    { id = "coraje",          name = "Coraje",           attribute = "esp" },
    { id = "cultura",         name = "Cultura",          attribute = "int" },
    { id = "engano",          name = "Engaño",           attribute = "esp" },
    { id = "informatica",     name = "Informática",      attribute = "int" },
    { id = "intimidacion",    name = "Intimidación",     attribute = "esp" },
    { id = "investigacion",   name = "Investigación",    attribute = "int" },
    { id = "pelea",           name = "Pelea",            attribute = "fue" },
    { id = "persuasion",      name = "Persuasión",       attribute = "esp" },
    { id = "punteria",        name = "Puntería",         attribute = "per" },
    { id = "sigilo",          name = "Sigilo",           attribute = "agi" },
    { id = "supervivencia",   name = "Supervivencia",    attribute = "per" },
    { id = "tecnologia",      name = "Tecnología",       attribute = "int" },
    { id = "mecanica",        name = "Mecánica",         attribute = "int" }
}

--------------------------------------------------
-- INICIALIZAR CATÁLOGO
--------------------------------------------------

local function initializeCommonSkills()

    local nodeCatalog = DB.createNode("aptus_skills")

    if not nodeCatalog then
        return
    end

    --------------------------------------------------
    -- IDENTIFICAR HABILIDADES EXISTENTES
    --------------------------------------------------

    local aExistingSkills = {}

    for _, nodeSkill in pairs(DB.getChildren(nodeCatalog)) do

        local sId = DB.getValue(nodeSkill, "id", "")

        if sId ~= "" then
            aExistingSkills[sId] = true
        end

    end

    --------------------------------------------------
    -- INCORPORAR HABILIDADES QUE FALTAN
    --------------------------------------------------

    for _, rSkill in ipairs(aCommonSkills) do

        if not aExistingSkills[rSkill.id] then

            local nodeSkill = DB.createChild(nodeCatalog)

            if nodeSkill then

                DB.setValue(
                    nodeSkill,
                    "id",
                    "string",
                    rSkill.id
                )

                DB.setValue(
                    nodeSkill,
                    "name",
                    "string",
                    rSkill.name
                )

                DB.setValue(
                    nodeSkill,
                    "attribute",
                    "string",
                    rSkill.attribute
                )

                DB.setValue(
                    nodeSkill,
                    "special",
                    "number",
                    0
                )

                aExistingSkills[rSkill.id] = true

            end

        end

    end

end

--------------------------------------------------
-- OBTENER HABILIDADES DE ATAQUE
--------------------------------------------------

function getAttackSkills()

    local aAttackSkills = {}

    local aAllowed = {
        pelea = true,
        punteria = true
    }

    local nodeCatalog = DB.findNode("aptus_skills")

    if not nodeCatalog then
        return aAttackSkills
    end

    for _, nodeSkill in pairs(DB.getChildren(nodeCatalog)) do

        local sId = DB.getValue(nodeSkill, "id", "")

        if aAllowed[sId] then

            table.insert(aAttackSkills, {
                id = sId,
                name = DB.getValue(nodeSkill, "name", ""),
                attribute = DB.getValue(nodeSkill, "attribute", "")
            })

        end

    end

    table.sort(aAttackSkills, function(a, b)
        return a.name < b.name
    end)

    return aAttackSkills

end

--------------------------------------------------
-- INICIALIZACIÓN DE LA EXTENSIÓN
--------------------------------------------------

function onInit()

    LibraryData.setRecordTypeInfo("aptus_skill", {
        bExport = true,
        aDataMap = { "aptus_skills" },

        sRecordDisplayClass = "aptus_skill",
        sSidebarCategory = "create",
    })

    initializeCommonSkills()

end