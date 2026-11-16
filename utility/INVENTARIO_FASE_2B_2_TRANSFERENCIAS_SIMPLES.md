# Fase 2B.2 — Motor de transferencias simples

## Alcance

Se añade la vía de solicitudes/ejecución de transferencias simples al gestor común.
Admite personaje↔estructura, estructura↔estructura (Localización/Vehículo) y
personaje↔personaje sólo para el DJ administrativo. Un jugador/Impersonar puede
usar sus personajes autorizados y estructuras con Visibilidad, Acceso y Almacenaje
activo. Acceso no habilita edición general de propiedades.

Se admiten objetos/pilas y contenedores vacíos, con destino raíz o contenedor
existente. Cualquier referencia de contenido directo, incluso incompatible,
impide trasladar el origen: los árboles corresponden a 2B.3.

No se integran selectores externos, selector jerárquico, elección de personajes
activos ni notificaciones de éxito al DJ. Ubicación actual, EQUIPO, ventanas de
cantidades, diseño, Riqueza, estados y reglas de CARGA no se modifican. No hay
fixtures automáticos, cambios de esquema, nuevos inventarios ni registros de
operaciones persistentes.

## Arquitectura y APIs

Todo reside en `scripts/manager_aptus_inventory.lua`. No se añade otro gestor ni
un segundo algoritmo de pilas.

- `getSimpleTransferRevision(node)`: checksum de lectura, opaco/no criptográfico,
  con dos acumuladores y longitud sobre el snapshot del objeto. Excluye locked y
  normaliza padre ausente/vacío. No crea un campo de revisión persistente.
- `buildSimpleTransferRequest(node, owner, quantity, parent, context)`: prepara una
  solicitud escalar, sin escrituras. Usa rutas reales y contexto 2B.1 opcional.
- `submitSimpleTransferRequest(request, callback, context)`: envía por OOB si es
  cliente, o encola directamente si es anfitrión. Permite repetir el mismo paquete
  para recuperar un resultado reciente sin volver a ejecutar.
- `requestSimpleTransfer(node, owner, quantity, parent, callback, context)`: combina
  preparación y envío. La cantidad debe haberse elegido antes de llamarla.
- `onSimpleTransferRequest`, `onSimpleTransferResult`, `flushSimpleTransfers`,
  `onInit`: integración de transporte y cola, no interfaces de edición general.

Las funciones devuelven id de solicitud o nil/motivo. El callback recibe una tabla:
`id`, `ok`, `status`, `message`, `result_path`; puede incluir `replayed` y, en la
respuesta de cliente, `context_stale`. Estados: success, unchanged, rejected o
uncertain. Este último exige revisión manual, no reintento automático.

`canTransfer` conserva la autorización de 2B.1 y explicita que personaje→personaje
entre propietarios/inventarios distintos requiere actor administrativo, incluso
si un jugador posee ambos personajes.

La función `transfer()` anterior conserva sus rutas/limitaciones y sigue atendiendo
la UI existente. Las nuevas transferencias deben solicitarse mediante la nueva API.
Ambas vías reutilizan **el mismo distribute()**, firma de compatibilidad, max_stack,
lector/escritor y reparto de cantidades.

## Autorización y ejecución

El anfitrión valida dentro de mutate(), inmediatamente antes de incorporar:

1. Contrato y tipos del paquete; contexto local todavía válido.
2. Identidad efectiva coincidente con el contexto.
3. Origen vivo en el inventario/ruta y contenedor esperados.
4. Revisión del origen sin cambios de datos; locked no cancela un traslado.
5. Destino vivo; padre perteneciente al inventario y revisión todavía vigente.
6. Cantidad entera, positiva, representable y disponible.
7. Predicados canTransfer/canSelectTransferSource/canSelectTransferDestination.
8. Campos/registros físicos modificables por el anfitrión.
9. Ausencia de hijos: no mover árboles en esta fase.

El reparto añade una política privada para esta operación: permite escribir las
cantidades necesarias por Acceso, sin reutilizar esa excepción en Guardar, editar
cantidades arbitrarias ni configurar propiedades. Se mantiene la prohibición de
seleccionar objetos ocultos o entrar en contenedores con contenido oculto para ese
usuario. No se limita por capacidad reductora de Almacenaje.

Un traslado a la ubicación actual es unchanged: no modifica cantidades, Estado ni
fuerza una fusión. Para destinos distintos:

- Raíz de personaje: carried=1.
- Contenedor de personaje: carried=0.
- Localización/Vehículo: carried=0.

La cantidad restante en origen conserva su Estado. Se preservan propiedades,
procedencia de plantilla/módulo, hide_contents y tipos DB. La compatibilidad de
pilas mantiene la identidad completa existente; no basta la categoría/imagen.

## Copia, verificación y errores

Se utiliza el reparto común con esta secuencia adicional:

1. Planificar fusiones y nuevas pilas respetando max_stack.
2. Crear y verificar copias, con carried antes de name como en el motor existente.
3. Aplicar y verificar incrementos en pilas compatibles del destino.
4. Revalidar origen/permisos y comprobar que la suma incorporada es la solicitada.
5. Sólo entonces reducir count en origen o eliminar el nodo agotado.

Antes de la verificación completa del destino, un fallo conserva el origen y usa
la limpieza/restauración de pilas destino ya existente. Si esa limpieza falla,
se devuelve uncertain para revisión.

Después de verificar el destino, no se deshace esa incorporación. Si falla la
retirada, el destino se conserva y se emite un aviso local al DJ identificando
las rutas de los inventarios. Pueden quedar duplicados: es el comportamiento
conservador aprobado. Si deleteNode lanza una excepción pero el nodo ya desapareció,
la comprobación de existencia permite reconocer el borrado efectivo.

No se reintenta automáticamente una solicitud incierta. Repetir su identificador
mientras esté en caché devuelve el mismo resultado y no repite aviso ni escrituras.
No hay atomicidad ni recuperación tras cierres inesperados. Errores externos que
modifiquen/borran registros fuera de este motor no quedan cubiertos por una
transacción de base de datos.

## OOB y actores

Tipos registrados:

- aptus_inventory_simple_request: sólo lo ejecuta el anfitrión.
- aptus_inventory_simple_result: respuesta dirigida al usuario solicitante.

El paquete sólo transporta id, usuarios, modo/personaje de contexto, rutas de
origen/destino/padres, cantidad y revisiones opacas. No contiene propiedades,
árboles, nombres ni contenido oculto. El cliente no ejecuta escrituras.

Se aplica el escenario de confianza aprobado: el usuario del paquete es una
identificación convencional, no autenticación contra manipulación deliberada.
El host no acepta modos administrativos o de Impersonar desde clientes: exige
context_mode=player y evalúa los permisos de ese usuario. Si se envía personaje
de contexto, comprueba que existe y sigue siendo suyo.

Para esa evaluación se construye un contexto local del ejecutor anfitrión con
actor efectivo del cliente. Reutiliza el modo técnico player_preview del lector,
pero marca origin=client, request_actor=usuario e impersonating=false: no debe
atribuirse a un DJ que simula. request.real_user identifica al solicitante;
actor_real del contexto interno identifica al proceso anfitrión que escribe.

Un DJ normal llama localmente con permisos reales. Un DJ en Impersonar pasa el
contexto original 2B.1: se valida su revisión/propietario y se aplican permisos
efectivos. No cambia Session.IsHost ni las ventanas independientes.

Las respuestas informan del resultado aunque el contexto local del cliente haya
caducado después de enviarse; incluyen context_stale. Una solicitud ya enviada
no se considera cancelada por cerrar una ventana o desconectar. Los consumidores
no deben usar el callback para iniciar otra modificación con contexto antiguo.

## Cola, repetición y actualización

- Cola local del anfitrión, máximo 64 solicitudes esperando.
- Se respeta inventoryBusy; una llamada reentrante espera al fin de la operación.
- Caché de 256 resultados recientes, en memoria, por actor real/id.
- Mismo id y paquete: devolver resultado; mismos id y otros parámetros: rechazar.
- Duplicados mientras están en cola se agrupan, no se ejecutan otra vez.
- Cliente: máximo 64 solicitudes sin respuesta y bloqueo de reenvío del mismo id
  mientras esté pendiente. No hay timeout, reenvío ni recuperación automáticos.

Dos solicitudes con una revisión antigua no consumen dos veces el origen: la
segunda encuentra el origen retirado o su cantidad/ubicación/revisión cambiadas.
La caché y revisiones no son un registro durable ni una garantía exactamente una
vez después de su expiración/reload. Los identificadores son de solicitudes,
no UUID añadidos a objetos.

Los cambios pasan por mutate() y sus listeners; se reutilizan observadores de
origen/destino ya instalados en EQUIPO/Almacenajes. CARGA se calcula sobre cada
personaje con las reglas existentes. Los clientes reciben eventos DB nativos;
no se promete una actualización visual atómica durante la replicación. Hay que
validar en FGU el estado final sin cerrar ventanas.

## Archivos

Modificados:

- scripts/manager_aptus_inventory.lua
- utility/tests/inventory_create_test.lua
- utility/tests/inventory_instance_static_test.js
- utility/tests/inventory_context_static_test.js (expectativa histórica sin OOB
  sustituida por comprobación de que la UI aún no integra el motor)

Creados:

- scripts/test_inventory_simple_transfer_aptus.lua (optativo, no registrado)
- utility/tests/inventory_simple_transfer_test.lua
- utility/tests/inventory_simple_transfer_static_test.js
- utility/INVENTARIO_FASE_2B_2_TRANSFERENCIAS_SIMPLES.md

No se modifican extension.xml, XML de ventanas, recursos, cantidades, filas externas,
selectores, CoreRPG, APTUS Dice ni datos existentes de campañas.

## Pruebas

Ejecutadas: **14/14 suites estáticas relacionadas superadas**:

```text
node utility/tests/inventory_simple_transfer_static_test.js
node utility/tests/inventory_context_static_test.js
node utility/tests/structure_consultation_static_test.js
node utility/tests/structure_inventory_static_test.js
node utility/tests/inventory_instance_static_test.js
node utility/tests/inventory_hidden_contents_static_test.js
node utility/tests/inventory_state_static_test.js
node utility/tests/inventory_units_static_test.js
node utility/tests/inventory_location_static_test.js
node utility/tests/inventory_container_load_static_test.js
node utility/tests/inventory_quantity_click_static_test.js
node utility/tests/inventory_quantity_visual_static_test.js
node utility/tests/identity_gender_static_test.js
node utility/tests/equipment_type_filters_static_test.js
```

Son referencias, contratos, guardas, balance léxico y estructura; no ejecutan Lua.

Preparada, NO ejecutada por falta de intérprete (no se instalan herramientas):

```text
lua utility/tests/inventory_create_test.lua
```

Incluye inventory_simple_transfer_test.lua, que llama al motor y manejadores OOB
reales con DB/transporte dobles. Cubre la matriz de inventarios, completo/parcial,
fusión, max_stack (50/50/20 y 50/20), plantillas incompatibles con nombres iguales,
contenedores destino anidados y vacíos, no apilables, estados, CARGA, actor efectivo,
permisos revocados/Visibilidad/Almacenaje, ocultación, repetición/id alterado,
revisiones y ubicación obsoletas, dos solicitudes sobre un origen, reentrada en la
cola durante una escritura, copia fallida, retirada total/parcial fallida y error
posterior a borrado efectivo. También prueba cliente sin escrituras, respuesta
OOB dirigida y repetición sin nueva ejecución.

No se han ejecutado estas pruebas funcionales ni FGU. La inyección de fallos es
sólo en dobles DB: no se altera la API real de una campaña para provocar errores.

## Prueba manual optativa en FGU

**Sólo en una copia de la extensión y campaña de prueba.** El script de prueba no
se carga normalmente y no crea objetos al inicializarse. En la copia, añadir al
bloque base de extension.xml:

```xml
<script name="APTUSSimpleTransferTest" file="scripts/test_inventory_simple_transfer_aptus.lua" />
```

Recargar/reconectar los participantes de prueba. El comando es:

```text
/aptus_simple_transfer_test <ruta objeto> <ruta inventario destino> <cantidad> [ruta contenedor|-] [ruta personaje de contexto]
/aptus_simple_transfer_test repeat
```

Ejemplo de estructura de llamada (sustituir ids por nodos reales de la campaña de
prueba; los comandos modifican realmente esos inventarios):

```text
/aptus_simple_transfer_test charsheet.id-00001.inventorylist.id-00001 aptus_structures.id-00001 3
/aptus_simple_transfer_test aptus_structures.id-00001.inventorylist.id-00001 charsheet.id-00001 1 - charsheet.id-00001
```

El quinto argumento exige que la ficha de personaje esté abierta; obtiene su
getInventoryContext() real, incluido Impersonar. Sin él se usan los permisos reales
de la sesión (DJ administrativo o jugador). El resultado muestra status y ruta
destino. repeat conserva el paquete/id anterior; no genera una operación nueva.

1. Preparar manualmente personajes de dos usuarios (uno desconectado), Localizaciones
   y Vehículos con Almacenaje y permisos. Usar objetos/pilas con carga conocida y
   contenedores vacíos/anidados. No usar una campaña existente de producción.
2. Como DJ probar la matriz de transferencias y destino en contenedores. Comparar
   propiedades, cantidades, template_id/version, parent y carried con el origen.
3. Probar parcial y pila completa; destino con 30 unidades más entrada de 40:
   comprobar 50 y 20, misma cantidad total y ninguna pila sobre max_stack.
4. Probar municiones diferentes y objetos no apilables: no deben fusionarse.
5. Con Impersonar y su quinto argumento: estructura accesible↔personaje propio;
   rechazar estructura sin Acceso, sin Visibilidad, Almacenaje desactivado, objetos
   ocultos, contenedores inaccesibles y personaje→otro personaje sin rol DJ.
6. Desde cliente real ejecutar el comando sobre un recurso accesible. Comprobar
   escritura en el anfitrión y reflejo en ambos clientes. Confirmar que Acceso no
   habilita el editor de propiedades.
7. Ejecutar repeat: mismo resultado marcado como repetido, sin cambios adicionales.
   Con dos clientes solicitar la misma pistola/pila: no debe haber retirada doble
   con revisión antigua ni cantidades negativas. No reenviar automáticamente.
8. Transferir contenedor vacío; intentar otro con contenido: rechazo sin cambios.
9. Mantener abiertas las fichas/EQUIPO/Almacenajes de origen y destino. Comprobar
   actualización sin cerrar y CARGA de personajes antes/después, sin sumar recursos
   que permanecen en estructuras. Revisar consola Lua y errores de permisos.
10. En casos inciertos comprobar ambos inventarios con el DJ; puede haber duplicados.
    Los fallos artificiales de copia/retirada se prueban con la suite Lua aislada.
11. Retirar la línea optativa y recargar para volver a la extensión habitual.

Las pruebas manuales finales están pendientes. Detenerse aquí: 2B.3/2B.4/2B.5 no
implementadas. Los selectores externos siguen ocultos y el selector actual sigue
limitado al inventario local.
