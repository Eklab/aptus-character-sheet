local callback;
function configure(title, initial, apply)
    caption.setValue(title); quantity.setValue(initial); callback = apply;
end
function confirm()
    local value = quantity.getValue();
    if type(value) ~= "number" or value < 0 or value > 9007199254740991 or value ~= math.floor(value) then
        problem.setValue("Introduce una cantidad entera no negativa."); return;
    end
    local apply = callback;
    callback = nil;
    close();
    if apply then apply(value); end
end
