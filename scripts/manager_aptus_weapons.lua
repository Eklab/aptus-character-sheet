--------------------------------------------------
-- APTUS - CATÁLOGO DE ARMAS
--------------------------------------------------

local aBasicWeapons = {
    {
        id = "desarmado",
        name = "Desarmado",
        attack_skill_id = "pelea",
        range = "C.C.",
        damage_dice = "d4",
        damage_type = "CON",
        critical_dice = "",
        special = "Desarmado"
    },
    {
        id = "cuchillo",
        name = "Cuchillo",
        attack_skill_id = "pelea",
        range = "C.C.",
        damage_dice = "d4",
        damage_type = "PER",
        critical_dice = "+1d4",
        special = "Ocultable"
    },
    {
        id = "pistola",
        name = "Pistola",
        attack_skill_id = "punteria",
        range = "25",
        damage_dice = "d6",
        damage_type = "PER",
        critical_dice = "+1d6",
        special = "Ocultable, Cargador 10."
    },
    {
        id = "hacha_2_manos",
        name = "Hacha a 2 manos",
        attack_skill_id = "pelea",
        range = "C.C.",
        damage_dice = "d10",
        damage_type = "COR",
        critical_dice = "+1d10",
        special = "Arma a dos manos."
    },
    {
        id = "escopeta",
        name = "Escopeta",
        attack_skill_id = "punteria",
        range = "16",
        damage_dice = "2d6",
        damage_type = "PER",
        critical_dice = "+1d6",
        special = "Doble crítico a distancia corta. Cargador 6."
    }
}

--------------------------------------------------
-- INICIALIZAR CATÁLOGO
--------------------------------------------------

local function initializeBasicWeapons()

    local nodeCatalog = DB.createNode("aptus_weapons")

    if not nodeCatalog then
        return
    end

    local aExistingWeapons = {}

    -- Identificar armas existentes
    for _, nodeWeapon in pairs(DB.getChildren(nodeCatalog)) do

        local sId = DB.getValue(nodeWeapon, "id", "")

        if sId ~= "" then
            aExistingWeapons[sId] = true
        end

    end

    -- Crear únicamente las armas que faltan
    for _, rWeapon in ipairs(aBasicWeapons) do

        if not aExistingWeapons[rWeapon.id] then

            local nodeWeapon = DB.createChild(nodeCatalog)

            if nodeWeapon then

                DB.setValue(nodeWeapon, "id", "string", rWeapon.id)
                DB.setValue(nodeWeapon, "name", "string", rWeapon.name)

                DB.setValue(
                    nodeWeapon,
                    "attack_skill_id",
                    "string",
                    rWeapon.attack_skill_id
                )

                DB.setValue(nodeWeapon, "range", "string", rWeapon.range)
                DB.setValue(nodeWeapon, "damage_dice", "string", rWeapon.damage_dice)
                DB.setValue(nodeWeapon, "damage_type", "string", rWeapon.damage_type)
                DB.setValue(nodeWeapon, "critical_dice", "string", rWeapon.critical_dice)
                DB.setValue(nodeWeapon, "special", "string", rWeapon.special)

                aExistingWeapons[rWeapon.id] = true

            end

        end

    end

end

--------------------------------------------------
-- INICIALIZACIÓN
--------------------------------------------------

function onInit()

    LibraryData.setRecordTypeInfo("aptus_weapon", {
        bExport = true,
        aDataMap = { "aptus_weapons" },
        sRecordDisplayClass = "aptus_weapon",
        sSidebarCategory = "create",
    })

    initializeBasicWeapons()

end