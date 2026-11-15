# Ocultar contenido de contenedores

## Modelo y configuración

Propiedad opcional de instancia `properties.hide_contents`: número 0/1 como las
casillas existentes. Ausente equivale a 0. No cambia el contrato, no migra datos,
no escribe al abrir una ficha y no modifica plantillas ni el catálogo.

La ficha de instancia incorpora «Ocultar contenido» en Contenedor y Carga,
junto a Capacidad. Sólo aparece al DJ para un objeto marcado como contenedor.
Con el candado abierto se edita en el borrador; Guardar persiste y Descartar
conserva lo anterior. Con el candado cerrado el DJ puede consultarlo. Los
jugadores no ven el control; el gestor rechaza intentos de cambiar la propiedad
desde un borrador de jugador, incluso si se intenta saltar la interfaz.

Al guardar un objeto que deja de ser contenedor se normaliza la propiedad a 0,
como limpieza de esa condición. La comprobación de cambios administrativos se
hace antes de normalizar: no autoriza al jugador a editar la casilla. Un dato
antiguo en un no contenedor permanece inactivo durante la lectura. Se conserva
la prohibición existente de quitar Contenedor si todavía contiene objetos.

## Vista e interacción

`getCharacterInventory()` mantiene todos los objetos y relaciones para calcular
CAR/Almacenaje; añade `hide_contents` y `visible_to_user` al snapshot. Para el DJ
todos los objetos son visibles. Para el jugador se recorren los antecesores:
un contenedor oculto se ve, pero todos sus descendientes se excluyen de la vista.
Al desactivar una ocultación exterior siguen vigentes las ocultaciones interiores.

La tabla actual tiene una sola indentación visual y no controles de plegado.
No se introduce un segundo sistema de árbol. La búsqueda nunca visita ramas
ocultas del jugador, por lo que tampoco descubre coincidencias en sus nombres.
Las conexiones se calculan sobre las filas visibles, como hasta ahora.

El DJ ve un candado nativo `padlock_closed` de CoreRPG, 20×20 en origen,
representado mediante un widget 12×12 después del nombre y del indicador de
Almacenaje, con 3 px de separación. Se reserva localmente 15 px al final, sin
nueva columna ni alineación al extremo derecho. Se mantiene el color original
del candado: no se aplica tintado ni queda código de diagnóstico.

El nombre y su indicador de Almacenaje usan gris claro `FFB8B8B8` cuando el
propio contenedor tiene `hide_contents=1`. Sólo se colorean los dos widgets de
texto, no el control padre ni otros iconos. Esto no se hereda a los objetos
contenidos. Al desactivar la propiedad, el nombre recupera el color de su fuente
y el indicador recupera su color habitual (rojo si está sobrecargado). Mientras
la ocultación está activa, el gris tiene prioridad también en el indicador.
El candado continúa siendo exclusivo del DJ; no se crean nuevos recursos.

`isItemVisible()` comprueba la misma política al abrir fichas y en las operaciones
comunes. Las acciones directas de Cantidad, Estado, Ubicación y eliminación no
admiten objetos ocultos. El selector Ubicación filtra destinos mediante la
validación existente, que ahora incluye visibilidad: no ofrece contenedores
ocultos por antecesores. El propio contenedor visible sigue siendo gestionable.

Los handlers existentes de propiedades refrescan la vista al guardar el cambio.
Los nuevos handlers de ficha cierran vistas de descendientes que dejan de ser
accesibles. Mientras la pestaña está abierta, un cambio de ocultación cancela
los selectores de Estado/Cantidad abiertos del jugador para no conservar
opciones ahora ocultas. Ubicación observa por sí misma la política del personaje
de su selección activa, incluso si la ficha se cerró, y cancela opciones antiguas.
No se ejecutan callbacks al cancelar. En todo caso, las operaciones revalidan
el acceso al confirmar. No se usan temporizadores ni sondeos.

## Carga y movimientos

No se filtran los datos del cálculo: todos los objetos, ocultos o no, siguen
contando para el contenido bruto y el Almacenaje sin encadenamiento. El total
conserva las reglas de Estado y sólo suma las raíces activas. Ocultar/desocultar
no cambia count, carried, aptus.container, carga individual ni capacidades.

Mover el contenedor visible con su contenido conserva la propiedad y todas sus
relaciones. Las comprobaciones internas del plan de árbol conservan permisos DB
reales, sin confundir la ocultación de interfaz con falta de permiso sobre los
hijos. La llamada directa desde una interfaz sobre un hijo oculto sigue bloqueada.
El borrado del contenedor visible conserva su confirmación y comportamiento
recursivo existentes; no se enseñan nombres de descendientes en esa confirmación.

Las copias y traslados existentes conservan el árbol de propiedades, incluida
esta propiedad. No se implementan traslados nuevos de árboles entre personajes,
Localizaciones ni Vehículos. El sistema actual sigue limitado a los inventarios
de personaje que ya soporta; las futuras interfaces deberán reutilizar la política.

## Alcance de la ocultación

Es una restricción narrativa de interfaz, no seguridad contra inspección técnica.
No cambian ownership, sincronización, compartición, almacenamiento ni permisos
nativos de los datos. Los datos completos siguen sincronizados cuando FGU lo
requiere y los totales CAR pueden reflejar su existencia. No hay cifrado,
cerraduras físicas, llaves ni dificultades.

## Pruebas

Nueve suites estáticas ejecutadas y aprobadas:

```text
node utility/tests/inventory_hidden_contents_static_test.js
node utility/tests/inventory_instance_static_test.js
node utility/tests/inventory_state_static_test.js
node utility/tests/inventory_units_static_test.js
node utility/tests/inventory_location_static_test.js
node utility/tests/inventory_container_load_static_test.js
node utility/tests/inventory_quantity_click_static_test.js
node utility/tests/inventory_quantity_visual_static_test.js
node utility/tests/identity_gender_static_test.js
```

Comprueban guardas, propiedad opcional, roles, poda de la búsqueda, recurso nativo,
UI local, balance léxico Lua, conexiones y que la ocultación no entra en el cálculo.
No ejecutan scripts Lua ni renderizan Fantasy Grounds.

Preparadas, no ejecutadas aquí por ausencia de Lua y sin instalar herramientas:

```text
lua utility/tests/inventory_create_test.lua
lua utility/tests/inventory_instance_view_test.lua
lua utility/tests/inventory_read_test.lua
```

`inventory_create_test.lua` incluye `inventory_hidden_contents_test.lua` con el
gestor real y DB en memoria: default ausente, persistencia mediante saveInstance,
DJ/jugador, tres niveles, bloqueo de acciones, destinos filtrados, desocultación,
CAR idéntica entre roles, movimientos con árbol, Estado, cambios a no contenedor
y copia existente de un contenedor vacío. No inserta fixtures en campañas.

## Validación manual en FGU

1. En campaña de prueba, DJ y jugador conectado propietario del personaje:
   crear Mochila con Linterna y Caja; Caja contiene otro contenedor y Diario.
2. En la instancia de Caja, Contenedor y Carga: comprobar casilla visible al DJ
   y ausente para jugador. Abrir candado, activar y Guardar. El DJ debe seguir
   viendo todos los objetos y un candado junto a Caja. El jugador ve Caja y los
   objetos exteriores, pero no sus descendientes ni el candado administrativo.
3. Buscar Diario y el contenedor interior como jugador: no deben aparecer. En
   Ubicación de un objeto visible no debe ofrecerse el contenedor oculto interior.
4. Abrir previamente una ficha de Diario y los selectores; activar ocultación en
   el DJ. Comprobar cierre de vistas ocultas/cancelación sin escrituras, refresco
   inmediato y consola sin errores Lua. Repetir con EQUIPO cerrado y abierto:
   cualquier confirmación obsoleta debe rechazar una acción sobre objetos ocultos.
5. Activar también Mochila: el jugador sólo ve Mochila. Desactivar Mochila:
   vuelve a ver Linterna y Caja, pero Caja mantiene ocultos sus descendientes.
6. Desactivar Caja: vuelven todos los objetos sin /reload. Confirmar que el DJ
   puede cambiar cantidades, estados y ubicaciones durante la ocultación.
7. Mover Caja con su contenido como jugador y cambiar su Estado: propiedad y
   referencias permanecen. No se habilitan traslados que antes no existían.
8. Anotar CARGA/Almacenaje antes/después de ocultar y para ambos roles: idénticos.
   Probar contenedores sobrecargados, estados 0/1/2 y tres niveles sin reducciones
   encadenadas. Cantidad, Estado y Ubicación de descendientes ocultos no operan.
9. Probar Guardar/Descartar/candado, nombres largos, filtros, scrollbar y un objeto
   no contenedor (sin control ni indicador). Un contenedor vacío que pierde esa
   condición no debe conservar ocultación activa al guardar.
10. /reload: se mantiene la propiedad guardada y cada rol recupera su vista.
    Confirmar que abrir registros antiguos no crea el campo ni altera sus datos.

## Archivos

Modificados:

- `scripts/manager_aptus_inventory.lua`
- `scripts/char_equipment_aptus.lua`
- `scripts/char_equipment_row_aptus.lua`
- `scripts/record_inventory_item_aptus.lua`
- `scripts/inventory_item_window_aptus.lua`
- `campaign/record_inventory_item_aptus.xml`
- `campaign/inventory_location_aptus.xml`
- `utility/tests/inventory_create_test.lua`
- `utility/tests/inventory_instance_view_test.lua`
- `utility/tests/inventory_instance_static_test.js`

Nuevos:

- `scripts/inventory_location_aptus.lua`
- `utility/tests/inventory_hidden_contents_test.lua`
- `utility/tests/inventory_hidden_contents_static_test.js`
- `utility/INVENTARIO_OCULTAR_CONTENIDO.md`
