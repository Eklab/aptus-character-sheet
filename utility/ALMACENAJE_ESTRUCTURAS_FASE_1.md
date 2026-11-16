# Almacenaje en las Localizaciones y Vehículos APTUS existentes

## Arquitectura conservada

No se crean entidades, gestores de estructuras, índices ni raíces de datos
alternativos. Se conservan:

- `APTUSStructureManager` y `aptus_structures.<id>`.
- Los tipos `location` / `vehicle`, sus categorías registradas `locations` /
  `vehicles`, sus identificadores `identity` y el flujo de creación existente.
- Las fichas narrativas `aptus_location` y `aptus_structure`, imagen, nombre,
  ubicación, descripción y notas existentes.
- La configuración y las funcionalidades de General. No se añade otra casilla
  de activación: se usa exclusivamente `features.storage.enabled`.
- Los índices CAMPAIGN y su integración actual, sin sustituir datos de CoreRPG.
- `APTUSLocationPermissions`, con destinatarios nativos, permisos privados y
  proyecciones existentes: `aptus_location_permissions`, `aptus_known_users` y
  `aptus_location_user_states`. Sus nombres se mantienen por compatibilidad.

Se retiraron los cambios parciales del intento inicial que añadían banderas de
visibilidad/acceso globales y cambiaban la resolución de la ficha narrativa.
No hay `visible_to_players`, `resources_access`, nueva categoría persistida ni
migraciones introducidas por esta fase. La creación de estructuras queda intacta.

El predicado del gestor de permisos existente admite también Vehículos. No se
crea otro sistema de permisos ni se concede acceso automáticamente. Visibilidad
permite consultar la ficha; Acceso más Almacenaje activo permite consultar los
recursos. Los jugadores no gestionan objetos en esta fase. No se añaden OOB ni
notificaciones al DJ. El anfitrión conserva la gestión según el candado actual.

## Configuración y vista

El panel existente pasa a General | Permisos | Almacenaje. Vehículos reutiliza
ese mismo panel en su pestaña Configuración; su ficha narrativa no se sustituye.
General mantiene las funcionalidades anteriores de Localizaciones y las de
Vehículos, incluidas las pendientes. Sólo Almacenaje se integra en esta fase.

La tercera pestaña está deshabilitada hasta activar Almacenaje en General.
Al desactivarlo, vuelve a General sin borrar objetos. En la ficha narrativa de
Localizaciones, la pestaña provisional existente ahora muestra el inventario.
La narrativa de Vehículos permite consultar la misma vista cuando hay Acceso y
Almacenaje activo. Los permisos y eventos existentes actualizan la disponibilidad.

`aptus_structure_inventory` es una subvista, no otra ficha de entidad: comparte
`scripts/char_equipment_aptus.lua` y las filas `aptus_char_equipment_row` con
EQUIPO. Su variante de fila únicamente ajusta los bounds para el ancho existente
(440 px en la narrativa de Localizaciones). Las columnas visibles son:

```text
Nombre | Cant. | Ubicación | CAR | Abrir
```

Se mantienen iconos, nombres truncados con tooltip, indentación visual de un
nivel, búsqueda, scrollbar, cantidad por clic, abrir la instancia y menús de
cantidades/fusión. Se reutilizan fuentes, iconos y controles existentes sobre
fondo oscuro; no hay PNG nuevos ni cambios de tamaño en las fichas existentes.
No se muestra Estado ni el panel de CARGA de personaje y no se consulta FUE.

La clase histórica `aptus_location_storage` se conserva como alias de la vista.
Su definición se sitúa después de la base en el XML nuevo para evitar copias
adelantadas durante la carga de Fantasy Grounds. El anterior script provisional
`location_storage_aptus.lua` ya no está referenciado por una ventana activa.

## Motor único y persistencia

Los objetos se guardan en:

```text
charsheet.<personaje>.inventorylist.<objeto>       (sin cambios)
aptus_structures.<estructura>.inventorylist.<objeto>
```

El inventario de estructura se crea perezosamente al añadir el primer objeto.
No se crean nodos al consultar. Se conserva el contrato de instancia APTUS 1,
la procedencia de plantilla y las propiedades. No hay UUID propios ni campos
duplicados de propietario: `getInventoryOwner()` resuelve el nodo padre estable.

El gestor amplía sus contextos de propietario y permisos, sin duplicar creación,
validación, repartos, firmas de compatibilidad, cantidades, borrado confirmado,
contenedores, Almacenaje o edición de propiedades. Expone `getInventory()` y
`canManageInventory()`; mantiene los nombres anteriores como alias compatibles
para los consumidores de personaje. El contrato `carried` se conserva por
compatibilidad: los objetos creados en estructuras usan 0, incluido al extraerlos
a raíz. El gestor rechaza Estado de personaje en estos contextos.

Ubicación sólo ofrece raíz o contenedores de la misma estructura. Las referencias
nativas de raíz usan `aptus_structure`; no se ofrecen otras estructuras/personajes.
El traslado existente conserva propiedades y todo el árbol al reorganizarlo
dentro del mismo inventario. Cualquier traslado que involucre una estructura y
otro inventario se rechaza antes de escribir. Los traslados ya existentes entre
personajes no se cambian ni se amplían.

CAR por fila, Almacenaje sin encadenamiento y `properties.hide_contents` utilizan
exactamente el cálculo/política comunes. Se preservan candado administrativo,
nombre/Almacenaje gris, visibilidad por antecesores y protección de acciones.
No se aplican límites ni carga global a estructuras. El jugador con Acceso sólo
consulta; no puede añadir, cambiar cantidades, mover ni borrar objetos, ni
introducir objetos en un contenedor con contenido oculto.

Al retirar Acceso o desactivar Almacenaje, las vistas dejan de mostrar recursos
y las fichas de instancia abiertas se cierran. La política se comprueba de nuevo
al confirmar operaciones. Son restricciones funcionales y de interfaz sobre la
sincronización existente; no se añade infraestructura contra inspección técnica.

## Pruebas

Once suites Node ejecutadas y aprobadas:

```text
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

Son verificaciones estáticas: referencias reales, XML equilibrado, orden de carga,
balance léxico Lua, motor compartido, activación original, permisos reutilizados,
separación por categorías y ausencia de Estado/CARGA y nuevas banderas globales.
No garantizan renderizado ni ejecución en Fantasy Grounds.

Preparadas, **no ejecutadas aquí** (no hay Lua y no se instalan herramientas):

```text
lua utility/tests/inventory_create_test.lua
lua utility/tests/inventory_read_test.lua
lua utility/tests/inventory_instance_view_test.lua
```

La suite de creación incluye `structure_inventory_test.lua`, que ejecuta el
APTUSInventoryManager real con DB en memoria y un adaptador de permisos de prueba:
dos categorías, activación, 120 unidades repartidas 50/50/20, cantidad, contenedores
anidados, Almacenaje, ocultación, edición, borrado confirmado, propiedad 0 y
rechazo sin escrituras entre inventarios. No ejecuta el gestor de permisos real,
la red ni la creación nativa de registros. Las suites previas de personaje siguen
incluidas y pendientes de ejecución Lua. No se insertan fixtures en campañas.

## Validación en FGU (campaña de prueba)

1. Abrir desde CAMPAIGN una Localización y un Vehículo existentes. Comprobar que
   mantienen su ficha, imagen, nombre, ubicación/descripción, identidad y notas.
   También probar el flujo de creación actual, sin índices ni tipos nuevos.
2. Abrir Configuración: General | Permisos | Almacenaje en ambos. Con Almacenaje
   desactivado, la tercera pestaña no permite gestionar objetos.
3. Abrir el candado de la entidad si corresponde y activar la casilla existente
   de Almacenaje en General. Abrir la tercera pestaña y usar Añadir: seleccionar
   plantilla y cantidad. Probar 120 municiones con máximo 50: pilas 50/50/20.
4. Abrir una instancia; editar propiedades con el candado; Guardar/Descartar.
   Modificar cantidades por clic y por menú; fusionar; eliminar con confirmación.
5. Crear Mochila y Caja; introducir Caja en Mochila y objetos en Caja. Comprobar
   rutas de Ubicación, extracción a raíz, tres niveles, cantidades conservadas,
   capacidades e indicadores. No debe verse Estado ni CARGA/FUE del personaje.
6. Activar Ocultar contenido en una instancia contenedora. El DJ ve todos los
   objetos y candado tras el nombre; nombre y Almacenaje grises. Como jugador,
   respetar ocultación en tabla, búsqueda, fichas y opciones de interacción.
7. En Permisos, conceder sólo Visibilidad a un jugador conectado: consulta la
   ficha pero no Almacenaje. Conceder Acceso: consulta recursos si Almacenaje
   está activo. El jugador no puede modificar recursos ni concederse permisos.
   Repetir con Vehículo, usando el mismo gestor y los controles existentes.
8. Revocar Acceso con la vista/ficha de instancia abierta: desaparece el acceso
   y se cierran fichas. Desactivar Almacenaje sin revocar permisos: no borra nada;
   al reactivarlo se recuperan los mismos objetos e IDs.
9. Probar Almacenaje también desde la navegación narrativa existente. Revisar
   contraste LANE, truncado/tooltip, scrollbar y ausencia de recortes en los
   tamaños originales, especialmente 488×566 de Localizaciones.
10. Arrastrar una instancia a otro personaje/estructura: debe rechazarse sin
    cambios. Reorganizar dentro de la misma estructura sí debe funcionar.
11. /reload: recuperar ambas entidades, sus permisos, casilla, objetos, cantidades,
    propiedades y relaciones. Revisar consola Lua. No considerar la persistencia
    validada hasta ejecutar esta comprobación real.
12. Regresión de personaje: añadir, cantidades, Estado/Ubicación, anidamiento,
    ocultación y CARGA. Deben conservar el comportamiento anterior.

## Pendiente / fuera de fase

- Validación visual/funcional, red y persistencia reales en FGU.
- Transferencias entre estructuras y personajes u otras estructuras, incluidos
  árboles completos, y notificaciones de recogida/depósito.
- No se desarrollan Seguridad, conducción, combate, mapas ni funcionalidades
  narrativas adicionales; tampoco se cambian sus datos ni controles actuales.

## Archivos

Nuevos:

- `campaign/record_structure_inventory_aptus.xml`
- `utility/tests/structure_inventory_static_test.js`
- `utility/tests/structure_inventory_test.lua`
- `utility/ALMACENAJE_ESTRUCTURAS_FASE_1.md`

Modificados:

- `extension.xml`
- `scripts/manager_aptus_structure.lua`
- `scripts/manager_aptus_location_permissions.lua`
- `scripts/manager_aptus_inventory.lua`
- `scripts/char_equipment_aptus.lua`
- `scripts/char_equipment_row_aptus.lua`
- `scripts/inventory_item_window_aptus.lua`
- `scripts/inventory_location_aptus.lua`
- `scripts/location_configuration_aptus.lua`
- `scripts/location_configuration_general_aptus.lua`
- `scripts/structure_window_aptus.lua`
- `campaign/record_location_aptus.xml`
- `campaign/record_location_permissions_aptus.xml`
- `campaign/record_structure_aptus.xml`
- `utility/tests/inventory_create_test.lua`
- `utility/tests/inventory_instance_static_test.js`

No se modifican CoreRPG, APTUS Dice, registros de campaña, gráficos ni los índices
existentes. No se instalan herramientas ni se crean commits.
