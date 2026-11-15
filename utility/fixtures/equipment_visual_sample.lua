-- Archivo de la maqueta anterior; no se carga ni se mezcla con inventario real.
local tSample = {
    { id="pistol", name="Pistola", icon="arma_proy", count="1", state="Equipada", location="Personaje", load="2", group=2 },
    { id="ammo", name="Munición", icon="arma_cc", count="12", state="Transportada", location="Personaje", load="1", group=2 },
    { id="pack", name="Mochila", icon="contenedor", count="1", state="Transportada", location="Personaje", load="3", group=2, children={
        { id="light", name="Linterna", icon="electrico", count="1", state="Transportada", location="Mochila", load="1" },
        { id="pouch", name="Bolsa", icon="contenedor", count="1", state="Transportada", location="Mochila", load="2", children={
            { id="kit", name="Botiquín", icon="mecanico_electrico", count="1", state="Transportada", location="Bolsa", load="1" },
            { id="bandage", name="Venda", icon="proteccion", count="1", state="Transportada", location="Bolsa", load="—" },
        } },
        { id="rope", name="Cuerda", icon="contenedor", count="1", state="Transportada", location="Mochila", load="—" },
    } },
    { id="car", name="Coche", icon="vehicle", count="1", location="Garaje", load="—", group=4 },
    { id="house", name="Casa", icon="localizacion", count="1", location="Ciudad", load="—", group=3 },
};

return tSample;
