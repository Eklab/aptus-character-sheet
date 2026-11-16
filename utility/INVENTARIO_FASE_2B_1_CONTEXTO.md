# Fase 2B.1 — Contexto local de Impersonar y autorización

## Alcance implementado

Se amplía el contexto efímero de la ficha de personaje y se aplica a las lecturas,
acciones y diálogos de su inventario. No hay impersonación global, OOB, nuevos
registros persistentes, transferencias nuevas entre inventarios ni cambios al
XML/script de Ubicación. No cambian esquema, reglas de CAR/CARGA, estados,
apilamiento, contención ni el comportamiento pendiente de Riqueza.

## Contexto local

`char_container_aptus.lua:getInventoryContext()` entrega:

- actor_real: Session.UserName.
- actor_effective: usuario real, o propietario actual de la ficha al Impersonar.
- character_path: ruta nativa del personaje.
- impersonating: booleano.
- mode/username: compatibilidad con el contexto existente de estructuras.
- isValid(): cierre sobre revisión local, nodo, propietario y modo capturados.
- onInvalidate(): cancelación local de diálogos dependientes, sin registro global.

Una revisión local se incrementa al refrescar el contexto (cambio de modo/observadores)
y al cerrar. Los contextos antiguos no vuelven a ser válidos aunque se active y
desactive Impersonar hasta regresar al modo anterior. Se revalida también la
sesión real y la existencia/propiedad del personaje. En clientes se usa DB.isOwner;
DB.getOwner para resolver propietarios ajenos se utiliza en el anfitrión.
No se modifica Session.IsHost, ownership, grants ni identidad conectada.

EQUIPO obtiene este contexto para sus acciones. Los inventarios independientes de
estructuras reciben nil: conservan los permisos reales de la sesión. Las APIs del
gestor mantienen ese valor opcional para los consumidores anteriores.

## Autorización reutilizable

El gestor común añade isContextValid/isContextHost y estas consultas sin escrituras:

| Consulta | Función |
| --- | --- |
| Ver un inventario/grupo | canViewInventory: estructura visible o personaje propio/DJ |
| Leer los objetos | canReadInventory: acceso y Almacenaje para estructuras |
| Utilizar recursos | canAccessInventory: permisos efectivos, propietario y activación |
| Seleccionar origen | canSelectTransferSource: instancia compatible, relación válida y objeto visible |
| Seleccionar destino | canSelectTransferDestination: raíz autorizada o contenedor accesible, sin ciclos |
| Autorizar transferencia futura | canTransfer: origen/destino y cantidad; contenedores indivisibles |
| Administrar propiedades/candado | canManageInstance/canEditInstance |

Los predicados de transferencia NO ejecutan una transferencia. Es posible que
canTransfer autorice funcionalmente recoger un recurso de una estructura, mientras
transfer siga rechazando la ejecución: esta fase prepara la autorización, no añade
la operación. El bloqueo anterior de estructuras entre inventarios permanece.

Acceso no concede edición general. Un actor efectivo jugador no administra
estructuras aunque la sesión que lo ejecuta sea el DJ. Los objetos propios del
personaje sí admiten las operaciones que permite el motor al propietario.

Para el anfitrión en Impersonar, la propiedad se resuelve desde el nodo hacia sus
padres, respetando el primer propietario explícito. Las comprobaciones existentes
de readonly, contrato, colecciones, cantidades y compatibilidad siguen aplicándose.
La correspondencia con la herencia nativa de ownership requiere validación en FGU.

## Acciones adaptadas

- Añadir desde catálogo y mediante drop: contexto en la creación y en callbacks
  de selección/cantidad, con revisión antes de ejecutar.
- Cantidades y eliminación de unidades: contexto en solicitud, aceptación y gestor.
- Fusión: contexto en el reparto y candidatos, sin fusionar con objetos ocultos.
- Estado: contexto en solicitud, aceptación y movimiento/extracción ya existentes.
- Ubicación: mismo selector y opciones del inventario actual; contexto en opciones,
  callback y transferencia interna. Los contenedores ocultos/inaccesibles no se
  admiten como destinos del actor efectivo. No se amplía la lista a otros inventarios.
- Arrastre: lectura del objeto validada antes de emitir el enlace y autorización
  contextual al recibirlo.
- Propiedades: guardas contextuales de lectura, candado, guardado y eliminación;
  perfiles/cualidades y sus callbacks pasan por la misma autorización.
- hide_contents: el actor efectivo no puede modificar esta propiedad reservada al DJ.

La lectura del inventario propio también aplica ahora hide_contents al actor
efectivo. El cálculo conserva los datos completos para CAR/Almacenaje; sólo se
filtran las filas. Los candados siguen visibles para todos. No se expone el
recuento de descendientes en la confirmación contextual de borrado para jugadores.

## Fichas de objetos y diálogos

Las fichas abiertas desde EQUIPO con contexto reutilizan aptus_inventory_item_consult,
la misma composición de instancia, las cuatro pestañas y los controladores actuales.
El nombre de clase histórico no implica consulta incondicional: canManageInstance
resuelve si ese actor puede editar. La ventana comienza con el candado cerrado.

- Personaje propio: el jugador/Impersonar puede abrir candado, personalizar y guardar
  con las validaciones existentes. Las cantidades y relaciones no se editan desde
  esta ficha de propiedades, como antes.
- Estructuras: jugador/Impersonar mantiene consulta de propiedades; Acceso no da edición.
- DJ normal desde EQUIPO: conserva capacidades administrativas con contexto local.
- Ventanas abiertas fuera de ese contexto: comportamiento real de sesión sin cambios.

Se separan las ventanas contextuales de las independientes para no reutilizar por
accidente una ficha del DJ con otro contexto. Al cambiar el contexto se cierran las
fichas dependientes; los borradores sin guardar de esas ventanas no se confirman.
Cambios de ocultación/permisos cierran una ficha que deja de ser visible. Aunque
un callback conservase una referencia, las guardas rechazan su contexto obsoleto.

Los diálogos de cantidad, Estado y Ubicación conservan su diseño y sus controles.
Cantidad/Estado se cierran sólo si siguen siendo la instancia abierta por ese
contexto. En Ubicación y catálogo se retira únicamente la entrada propia de la
cola nativa, preservando solicitudes de otras fichas. Los callbacks siguen
revalidando y no escriben aunque quedase una referencia anterior. El borrado confirmado comprueba contexto y vigencia
antes de recalcular/ejecutar el plan. Los callbacks del catálogo y de asociaciones
no pueden confirmar cambios desde una ficha cerrada o contexto invalidado. El
diálogo compartido de cualidades incorpora un callback opcional onOpened: permite
registrar el cierre contextual cuando llega a abrirse, incluso si estaba en cola,
sin cerrar una ventana ajena. El borrado nativo conserva su diálogo compartido y
rechaza una aceptación obsoleta mediante sus guardas, aunque siga visible.

## Incompatibilidades detectadas fuera de inventario, no modificadas

La simulación completa de TODA la ficha todavía no se considera implementada:

- `char_identity_data_aptus.lua` registra y ejecuta un menú de depuración del
  simbionte basándose en Session.IsHost, con escritura directa de su modo.
- `char_principal_aptus.lua` delega la apertura del editor de atributos al controlador
  heredado, que no recibe este nuevo contexto local.
- Los controles de Identidad usan el bloqueo nativo de ventana y vinculación directa
  a DB; no se sustituyen en esta fase por un editor contextual.

Se identifican para una revisión autorizada aparte, antes de afirmar que todas las
pestañas simulan los permisos del jugador. No se modifican esas funcionalidades.
Las ventanas independientes de estructuras mantienen expresamente el rol real del DJ.

## Archivos creados

- utility/tests/inventory_context_test.lua
- utility/tests/inventory_context_static_test.js
- utility/INVENTARIO_FASE_2B_1_CONTEXTO.md

## Archivos modificados

Código:

- scripts/char_container_aptus.lua
- scripts/manager_aptus_inventory.lua
- scripts/char_equipment_aptus.lua
- scripts/char_equipment_row_aptus.lua
- scripts/inventory_item_window_aptus.lua
- scripts/record_inventory_item_aptus.lua
- scripts/quality_associations_aptus.lua (callback opcional local de apertura)

Pruebas existentes (adaptación de contratos con contexto opcional y dobles):

- utility/tests/inventory_create_test.lua
- utility/tests/inventory_instance_view_test.lua
- utility/tests/structure_consultation_static_test.js
- utility/tests/structure_inventory_static_test.js
- utility/tests/inventory_instance_static_test.js
- utility/tests/inventory_hidden_contents_static_test.js
- utility/tests/inventory_state_static_test.js
- utility/tests/inventory_units_static_test.js
- utility/tests/inventory_location_static_test.js
- utility/tests/inventory_quantity_click_static_test.js
- utility/tests/equipment_type_filters_static_test.js

No se modifican XML, PNG, fuentes, scripts de Ubicación/cantidad/Estado, CoreRPG,
APTUS Dice, permisos persistentes ni datos de campañas.

## Pruebas ejecutadas

13/13 suites estáticas relacionadas superadas:

```text
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

Comprueban contratos, guardas, referencias, balance léxico y continuidad de reglas.
No ejecutan Lua ni FGU y no garantizan el comportamiento nativo de ventanas.

Pruebas funcionales preparadas, NO ejecutadas aquí por falta de Lua:

```text
lua utility/tests/inventory_create_test.lua
lua utility/tests/inventory_instance_view_test.lua
```

La primera incluye inventory_context_test.lua: usa los gestores y el controlador
real de personaje con DB en memoria; prueba actores/revisiones, dos fichas, permisos
propios/ajenos, creación, cantidades, fusión, Estado/Ubicación interna, propiedades,
ocultación, Acceso sin edición, transferencias cruzadas todavía bloqueadas y
confirmaciones pendientes sin escrituras tras invalidación y cancelación selectiva
de entradas de Ubicación sin afectar a la cola de otra ficha. También carga el
controlador real de ficha contextual y comprueba desbloqueo autorizado y rechazo
tras invalidación. No se han instalado herramientas adicionales.

## Validación manual en FGU

1. Usar campaña de prueba con personajes de Alice/Bob, objetos apilables, contenedores
   anidados y Localización/Vehículo con distintos permisos/activación de Almacenaje.
2. DJ sin Impersonar: comprobar edición habitual del inventario y propiedades.
3. Abrir dos fichas; activar Impersonar sólo en Alice. Confirmar que Bob y las
   ventanas independientes de estructuras mantienen sus permisos reales.
4. En Alice comparar con cliente real de Alice: crear, cantidades/fusión, Estado,
   Ubicación dentro de su inventario, abrir propiedades, candado, cuatro pestañas,
   Guardar/Descartar y eliminación confirmada. Verificar persistencia con /reload.
5. Activar hide_contents: DJ normal ve descendientes; Impersonar/cliente no. El
   contenedor y su candado/gris siguen visibles. No se admite su interior como
   destino; no se extraen objetos ocultos mediante referencias antiguas.
6. Desde una ficha de propiedades propia en Impersonar, editar un nombre/perfil/
   cualidad autorizado; no permitir editar Ocultar contenido ni campos estructurales.
   En recursos externos seguir sin edición general de propiedades.
7. Dejar abiertos sucesivamente cantidad, Estado, Ubicación, borrado y catálogo;
   alternar Impersonar antes de aceptar. No debe producirse una modificación con
   permisos antiguos. Repetir alternando dos veces, cambiando propietario y cerrando.
8. Abrir propiedades desde la ficha en modo DJ, luego cambiar Impersonar: la ventana
   dependiente se cierra y no guarda su borrador. Una ficha independiente ya abierta
   no cambia de rol. Repetir pérdida de visibilidad/ocultación con ficha abierta.
9. Comparar CARGA y Almacenaje antes/después de movimientos internos y cantidades:
   mismas reglas y valores. Riqueza y la distribución visual no cambian.
10. Comprobar consola sin errores Lua, herencia de ownership en objetos recién
    creados y controles que se habilitan exactamente como para el jugador real.

No continuar con 2B.2: no hay OOB, selector entre inventarios ni nuevos traslados.
