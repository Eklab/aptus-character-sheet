# Estado y Ubicación del inventario

## Contrato y lectura

Se conserva `carried` numérico: 0 Sin equipar, 1 Transportado, 2 Equipado.
No hay nuevos campos, conversiones ni migraciones. `aptus.container` conserva
el ID del contenedor inmediato y su ausencia sigue significando raíz.

Las raíces muestran su propio estado. Los contenidos muestran siempre un guion
(`state=Contenido`, `effective_carried=0` en el snapshot), aunque un registro
antiguo conserve otro carried. La lectura no reescribe ese valor. La columna CAR
sigue mostrando la carga del objeto/contenedor; el total del personaje suma sólo
raíces con carried 1/2. Una raíz Sin equipar excluye también su contenido del total.
Todos los descendientes cuentan para el contenido de su contenedor sin filtrar
por carried. Almacenaje sólo reduce en la raíz; no se encadenan reducciones.
Capacidad, cinco estados de carga, siluetas y penalizaciones no cambian.

## Selector LANE

`campaign/inventory_state_aptus.xml` define una ventana 400×180 sin datasource.
Reutiliza marco, cabecera de 37 px, cierre, fuentes e iconos registrados de LANE.
Ofrece Equipado, Transportado y Sin equipar, con sus iconos/guion y una banda
que destaca el estado actual. Las tres filas son pulsables: seleccionar cierra
y confirma una sola vez; cerrar sin seleccionar no ejecuta ningún callback.
No se utiliza alternancia. El control de la tabla permanece sourceless.

`requestState()` conserva ruta y token del origen, comprueba su vigencia al
confirmar y llama a `setState()`. La operación valida permisos y relaciones con
los mecanismos existentes. Equipado/Transportado extraen a raíz mediante
`transfer()`; Sin equipar en un contenido no escribe ni lo extrae. Cambiar el
estado de una raíz no cambia su ubicación. Elegir el estado actual no escribe.

## Traslado y reparto

`transfer()` sigue siendo el punto común. Por defecto un destino contenedor
establece carried 0 y una extracción establece carried 1. El selector de Estado
puede indicar el carried de destino al extraer. Los traslados entre contenedores
usan 0; el mismo destino no escribe ni fuerza una fusión. Los contenedores con
contenido mantienen sus relaciones internas al extraerse o moverse.

La firma de apilamiento continúa comparando plantilla, propiedades y estado.
Durante un traslado compara el origen con el carried de destino, sin escribir
primero un estado provisional en el origen. Las copias reciben ese mismo valor,
las pilas destino conservan su estado y no se fusionan estados incompatibles.
Se mantienen máximos y conservación de unidades. Las cantidades que no cambian
no se reescriben. Las operaciones verifican las escrituras y restauran carried,
padre y cantidades si se detecta un fallo; un fallo de restauración exige revisión
por el DJ y se informa como error, sin prometer transacciones nativas del motor.

## Unidad lógica y refresco

El bloqueo `mutate()` existente cubre estado y ubicación en una sola operación.
La vista pospone sus handlers DB mientras el gestor está ocupado y se reconstruye
una sola vez al finalizar si recibió cambios. Los selectores no fuerzan después
un segundo refresco. Los listeners se retiran al cerrar la pestaña.

Los eventos DB nativos de los distintos campos siguen existiendo; no se suprimen
ni se implementa una transacción DB ni un sistema de notificaciones al DJ. El
punto final de la operación queda centralizado para su futura integración. En
clientes remotos la llegada de eventos depende del motor: validar también como
jugador conectado. Una operación sin cambios no escribe ni genera eventos DB.

## Pruebas

Ejecutadas en esta revisión:

```text
node utility/tests/inventory_state_static_test.js
node utility/tests/inventory_location_static_test.js
node utility/tests/inventory_units_static_test.js
node utility/tests/inventory_container_load_static_test.js
node utility/tests/inventory_instance_static_test.js
node utility/tests/inventory_quantity_visual_static_test.js
```

Comprueban conexiones, valores, guardas, recursos, XML, balance léxico Lua,
refresco agrupado y preservación de la carga y Almacenaje. No ejecutan el motor.

Preparadas para un entorno con Lua, no ejecutadas aquí (sin intérprete y sin
instalar herramientas):

```text
lua utility/tests/inventory_read_test.lua
lua utility/tests/inventory_create_test.lua
```

La segunda incluye `inventory_state_test.lua`, ejecuta el gestor real contra DB
en memoria y cubre estados, no-op, ubicación, extracción, contenedores anidados,
estados antiguos, carga, firmas de pilas, permisos, errores/rollback, selección,
callback obsoleto, cierre y una sola confirmación. No inserta fixtures en campañas.

## Validación manual en FGU

1. En una campaña de prueba abrir EQUIPO y seleccionar directamente los tres
   estados de un objeto raíz. Comprobar iconos, tooltip, banda actual y cierre.
2. Repetir la opción actual y cerrar sin elegir: no deben cambiar datos ni carga.
3. Con objeto CAR 4 y contenedor propio CAR 2/Almacenaje 5: en raíz activa suma 6;
   Sin equipar en raíz deja sólo 2; dentro del contenedor el total es 2 y el objeto
   muestra guion. Su contenido sigue indicando 4 aunque el objeto almacenase 2.
4. Desde el contenido seleccionar Equipado o Transportado: vuelve a raíz con ese
   estado. Desde Ubicación sacarlo a raíz: siempre Transportado. Elegir Sin equipar
   estando contenido no lo mueve. Cambiar entre contenedores mantiene guion.
5. Repetir con contenedores llenos y tres niveles: mover el padre conserva sus
   descendientes; no se encadena Almacenaje ni se duplica la carga.
6. Probar pilas compatibles en destino con estados distintos: sólo fusionan las
   del estado de destino, respetando máximos y cantidad total.
7. Como jugador propietario y como DJ comprobar permisos, selección única y
   actualización de la vista; el jugador sin permisos no puede modificar estados.
8. Abrir selector y modificar/eliminar el origen desde otra interfaz antes de
   confirmar: rechaza la selección obsoleta sin escribir.
9. Ejecutar /reload y reabrir: estado, ubicación y cantidades persisten. Los datos
   antiguos contenidos se leen sin conversiones ni escrituras automáticas.
10. Comprobar consola Lua, cantidades por clic, Ubicación, scrollbar, búsqueda,
    filtros y CARGA. Esta intervención no aplica penalizaciones de combate.

## Archivos de esta intervención

Nuevos:

- `campaign/inventory_state_aptus.xml`
- `scripts/inventory_state_aptus.lua`
- `utility/tests/inventory_state_test.lua`
- `utility/tests/inventory_state_static_test.js`
- `utility/INVENTARIO_ESTADO.md`

Modificados:

- `extension.xml`
- `campaign/record_char_equipment_aptus.xml`
- `scripts/manager_aptus_inventory.lua`
- `scripts/char_equipment_aptus.lua`
- `scripts/char_equipment_row_aptus.lua`
- `scripts/char_equipment_state_aptus.lua`
- `utility/tests/inventory_read_test.lua`
- `utility/tests/inventory_create_test.lua`
- `utility/tests/inventory_units_test.lua`
- `utility/tests/inventory_units_static_test.js`
- `utility/tests/inventory_location_static_test.js`
- `utility/tests/inventory_instance_static_test.js`
- `utility/tests/inventory_quantity_visual_static_test.js`
- `utility/INVENTARIO_UBICACION.md`
- `utility/INVENTARIO_CARGA_CONTENEDORES.md`
- `utility/EQUIPO_FICHA_VISUAL.md`

También pasaron `identity_gender_static_test.js` e
`inventory_quantity_click_static_test.js`, sin modificarlas. Total: ocho suites
estáticas. No se han ejecutado pruebas funcionales Lua ni FGU.
