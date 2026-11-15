-- Consulta: una tarjeta original de 393x52 por perfil, sin escritura de datos.
local qualityWidget;
function configure(kind, values)
    local profile = kind == "profile";
    profile_art.setVisible(profile);
    section_art.setVisible(not profile);
    section_title.setVisible(not profile);
    for _, name in ipairs({ "profile_name", "skill", "damage", "critical" }) do self[name].setVisible(profile); end
    profile_qualities.setVisible(profile);
    if profile then
        profile_name.setValue(values.name);
        profile_name.setTooltipText(values.name);
        skill.setValue(values.skill);
        skill.setTooltipText(values.skill);
        damage.setValue(values.damage);
        damage.setTooltipText(values.damage);
        critical.setValue(values.critical);
        critical.setTooltipText(values.critical);
        if not qualityWidget then
            qualityWidget = profile_qualities.addTextWidget({ font=profile_qualities.getFont(), text="" });
        end
        local line = (values.damage_types or "Tipo: Nada")
            .. ((values.ammunition or "") ~= "" and (" · " .. values.ammunition) or "") .. " · Cualidades: "
            .. (values.qualities ~= "" and values.qualities or "Nada");
        qualityWidget.setText((line:gsub("[\r\n\t]", " ")));
        qualityWidget.setMaxWidth(381);
        local width = qualityWidget.getSize();
        qualityWidget.setPosition("left", math.floor(width / 2), 0);
        local details = values.details or "";
        profile_qualities.setTooltipText(line .. (details ~= "" and ("\n\n" .. details) or ""));
        -- La zona inferior pertenece al mismo PNG: nunca aumenta la tarjeta.
        qualities.setValue("");
        qualities.setVisible(false);
        qualities.setAnchor("top", "", "top", "absolute", 0);
    else
        -- Cualidades generales independientes: conservan altura multilínea automática.
        qualities.setAnchor("top", "", "top", "absolute", 28);
        qualities.setValue(values.qualities);
        qualities.setTooltipText(values.details);
        qualities.setVisible(values.qualities ~= "");
    end
end
