-- Infraestructura de pruebas: el controlador de ilustración solo usa el nodo de su ventana.
local TEST_NODE_PATH = "aptus_test.charactersheet";

function onInit()
    Comm.registerSlashHandler("test", onTestCommand, "charactersheet");
end

function onTestCommand(sCommand, sParams)
    if StringManager.trim(sParams or ""):lower() ~= "charactersheet" then
        Comm.addChatMessage({ text = "Uso: /test charactersheet" });
        return;
    end

    local nodeTest = DB.findNode(TEST_NODE_PATH);
    if not nodeTest and Session.IsHost then
        nodeTest = DB.createNode(TEST_NODE_PATH);
    end
    if not nodeTest then
        Comm.addChatMessage({ text = "APTUS: el nodo de pruebas no está disponible. Abre esta prueba desde el director de juego." });
        return;
    end

    local w = Interface.findWindow("aptus_test_charactersheet", TEST_NODE_PATH);
    if w then
        w.bringToFront();
    else
        Interface.openWindow("aptus_test_charactersheet", TEST_NODE_PATH);
    end
end
