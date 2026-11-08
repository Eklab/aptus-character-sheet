local bOnlyMine = false;
local sSkillsPath;

function onInit()
    sSkillsPath = DB.getPath(getDatabaseNode(), "skills");
    DB.addHandler(sSkillsPath, "onChildUpdate", refreshSkills);
    DB.addHandler(sSkillsPath, "onChildAdded", refreshSkills);
    DB.addHandler(sSkillsPath, "onChildDeleted", refreshSkills);
    super.onInit();
end

function onClose()
    if not sSkillsPath then return; end
    DB.removeHandler(sSkillsPath, "onChildUpdate", refreshSkills);
    DB.removeHandler(sSkillsPath, "onChildAdded", refreshSkills);
    DB.removeHandler(sSkillsPath, "onChildDeleted", refreshSkills);
end

function setSkillFilter(bMine)
    bOnlyMine = bMine == true;
    skill_filter.setValue(bOnlyMine and "Mis habilidades" or "Todas");
    refreshSkills();
end

function toggleSkillFilter()
    setSkillFilter(not bOnlyMine);
end

function filterSkills(w)
    local nodeSkill = w.getDatabaseNode();
    if not nodeSkill then return false; end
    return DB.getValue(nodeSkill, "id", "") == "generic_skill"
        or not bOnlyMine or DB.getValue(nodeSkill, "level", 0) > 0;
end

function refreshSkills()
    aptus_skills_list.applyFilter();
    aptus_skills_list.applySort();
end
