# Fase 2A: inventario unificado y correcciones de presentación

## Vistas y distribución común

Se conserva una única tabla a la izquierda y el panel CARGA a la derecha en
Todo, Personaje, Localizaciones, Vehículos y Riqueza. Se retiran los desplazamientos
horizontales y la ampliación de 108 px aplicados anteriormente a las consultas de
estructuras. Se usan las posiciones originales de Todo/Personaje del XML:
lista 40,84,483,232; scrollbar 508,84,15,232. Nombre termina en x=215 dentro de
la fila; Cantidad empieza en 217, Ubicación en 295 (93 px) y CAR en 405.
Las vistas específicas siguen sin Estado, sin desplazar el resto de columnas.

- Todo: inventario del personaje, después Localizaciones y después Vehículos con
  al menos una instancia APTUS realmente accesible. Orden por nombre/ruta dentro
  de cada categoría. No se mezclan los datos persistentes de sus inventarios.
- Personaje: sólo inventario propio y sus acciones existentes.
- Localizaciones/Vehículos: todas las estructuras visibles, incluso sin Acceso o
  con Almacenaje desactivado. Mensajes distintos para falta de Acceso, Almacenaje
  no disponible e inventario vacío.
- Riqueza: comportamiento previo, sin nuevas funciones; CARGA sigue disponible.

## Cabeceras virtuales siempre desplegadas

No hay selector ni control adicional de expansión/contracción de estructuras.
Se eliminan collapsedGroups, toggleStructureGroup y sus eventos. Los recursos
accesibles se dibujan directamente debajo de su cabecera.

La cabecera usa las mismas posiciones que una raíz del personaje: icono x=0,
nombre x=34. Todos sus controles permanecen dentro de los 24 px de altura.
El mensaje de indisponibilidad se muestra en la misma línea, en el espacio de
Ubicación/CAR; se ocultan los guiones de esas celdas cuando hay mensaje y el
texto completo está disponible por tooltip.

**Causa del hueco anterior:** el control de mensaje ocupaba y=24..44 incluso
con texto vacío, por lo que el tamaño efectivo de la ventana de fila podía
superar los 24 px contabilizados. Ahora no existe ningún control fuera de la
altura ordinaria de la fila. No se compensa con desplazamientos negativos.

Los objetos de estructuras tienen una indentación adicional de 18 px respecto
a la cabecera; dentro de cada raíz real se mantiene la indentación existente de
sus descendientes. Las ramas usan los controles gráficos nativos anteriores.
Se mantiene el orden de recorrido y las relaciones reales, sin modificar
contenedores ni sus controles/interacciones existentes. Las cabeceras no tienen
nodos persistentes ni operaciones de inventario. Sus guiones son sólo informativos.

## Candado y ocultación

El candado padlock_closed (12×12, separación de 3 px) se mantiene después del
nombre y del indicador de Almacenaje. Su condición visual es únicamente que el
objeto sea contenedor y tenga hide_contents activado: lo ven el DJ normal, el DJ
en Impersonar y el jugador que puede ver ese contenedor. Se conserva la reserva
de ancho para evitar solapamientos y el gris FFB8B8B8 del nombre y Almacenaje.

La ocultación de descendientes sigue en el lector existente, sin cambios:
DJ normal ve todos; jugador/Impersonar ven el contenedor pero no sus contenidos
ocultos. El tooltip administrativo sigue reservado al DJ normal. No se cambian
propiedades, permisos ni el comportamiento de ocultación.

## Ubicación y consulta

Las filas externas usan un widget de texto nativo sobre el control Ubicación,
con setMaxWidth ajustado a su anchura real (93 px), centrado verticalmente y
alineado a la izquierda. Se normalizan saltos de línea sólo en la presentación.
El valor íntegro permanece en el tooltip y en los datos. No se alteran las filas
editables ni las ventanas independientes de estructuras.

Los recursos externos siguen en consulta: no registran menús de cantidades,
fusión o movimiento; no permiten clic de cantidad, Estado, Ubicación, arrastre,
ni drops. Se recupera el icono Abrir heredado de la fila del personaje, sin
cambiar sus dimensiones ni anclajes. Las cabeceras no tienen este control y
siguen consumiendo drops.
Las acciones del inventario propio en Todo/Personaje se mantienen.

## CARGA y actualización

En todas las subpestañas se llama al mismo getLoadStatus con el snapshot del
personaje, antes de construir los grupos de estructuras. Sus recursos no se
suman ni se pasan al cálculo. No cambian capacidad, Almacenaje, estados,
siluetas, barra, colores, textos o penalizadores.

Se conservan los handlers y listeners existentes para propiedades, cantidades,
contenedores, estructuras, permisos, activación de Almacenaje y contexto de
Impersonar. Se retiran al cerrar. No se modifica Session, ownership, permisos,
persistencia ni el contexto independiente por ficha. Las ventanas originales de
Localizaciones/Vehículos siguen funcionando con su inventario editable original.

## Archivos modificados en estas correcciones

- scripts/char_equipment_aptus.lua
- scripts/char_equipment_row_aptus.lua
- scripts/char_equipment_structures_aptus.lua
- campaign/record_char_equipment_structures_aptus.xml
- utility/tests/structure_consultation_static_test.js
- utility/tests/structure_consultation_test.lua
- utility/tests/structure_inventory_static_test.js
- utility/tests/inventory_hidden_contents_static_test.js
- utility/EQUIPO_ESTRUCTURAS_FASE_2A.md

No se modifican gestores de inventario/estructuras/permisos, plantillas,
recursos gráficos, fichas independientes, CoreRPG ni APTUS Dice.

## Pruebas ejecutadas y límites

**12/12 suites estáticas relacionadas superadas:**

```text
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

Cubren referencias/XML/balance léxico, límites de controles y cabeceras, ausencia
de plegado virtual, distribución común, actualización de CARGA en cualquier
subpestaña con inventario propio, widget de Ubicación acotado, candado por
propiedad y guardas existentes. Son comprobaciones estáticas, no ejecución FGU.

Suite funcional Lua ampliada pero **no ejecutada** aquí por falta de intérprete:

```text
lua utility/tests/inventory_create_test.lua
```

Incluye structure_consultation_test.lua: gestores y controladores reales con
dobles DB/permisos/controles. Añade CARGA 1/6 estable en las cinco vistas pese a
recursos externos, grupos siempre desplegados, candado/gris en DJ, Impersonar y
jugador, actualización al desactivar hide_contents, widget Ubicación y tooltip.
Mantiene casos de permisos, poda de descendientes, contexto independiente,
lectura sin escrituras y acciones bloqueadas. No se han instalado herramientas.

## Validación manual en FGU

1. Preparar un personaje con FUE/carga conocidas y Localización/Vehículo con varios
   recursos, contenedores anidados y nombres largos, incluyendo «Cofre de Seguridad».
2. Activar hide_contents: DJ ve candado, nombre/capacidad grises y contenidos.
   Impersonar y cliente real ven el mismo candado/gris pero no descendientes.
   Desactivarlo debe restaurar estilo y contenidos inmediatamente.
3. En Todo comparar alineación de raíces del personaje y cabeceras de estructuras:
   mismos iconos/nombres x=0/34; sin flechas de expansión virtual. Los recursos
   accesibles aparecen directamente debajo, sin huecos, y las ramas son continuas.
4. Cambiar entre las cinco subpestañas: la tabla no invade el panel derecho y CARGA
   mantiene los mismos valores, estado, barra y silueta del personaje.
5. Modificar cantidad/carga del personaje desde sus controles: CARGA se actualiza
   también estando en Localizaciones/Vehículos/Riqueza. Modificar sólo recursos
   externos no debe cambiarla. No se aplican penalizadores automáticamente.
6. Comprobar Ubicación con nombres largos: no invade CAR ni el marco. El tooltip
   debe mostrar el nombre completo. Revisar varias filas y scrollbar.
7. Revocar/conceder Visibilidad/Acceso, alternar Almacenaje e Impersonar, añadir o
   retirar recursos: mensajes y filas se actualizan sin reload ni datos antiguos.
8. Comprobar que recursos externos no permiten editar ni transferir; el inventario
   propio y las ventanas originales conservan sus acciones y datos.
9. Abrir dos fichas, comprobar contextos independientes, cerrar/reabrir y /reload.
   Revisar consola sin errores Lua/anclajes, candados, recorte y distribución.

Las transferencias y las notificaciones al DJ siguen fuera de alcance.

## Inspección de objetos de estructuras

El icono aptus_equipo_ver se hereda de aptus_char_equipment_row en cada recurso
real, en Todo/Localizaciones/Vehículos. No se añade a cabeceras ni mensajes.
El clic de apertura se delega al EQUIPO de origen, que comprueba la pertenencia
del objeto al snapshot getViewedInventory con el contexto efectivo actual. No
basta conocer la ruta: objetos incompatibles, inaccesibles o escondidos por un
antecesor hide_contents se rechazan antes de abrir.

- DJ normal: apertura habitual aptus_inventory_item, igual que en el inventario
  independiente. Conserva el candado, borrador, edición, guardado y validaciones
  originales del gestor. Una ficha editable independiente ya abierta se conserva.
- Jugador o Impersonar: aptus_inventory_item_consult, copia de la ventana original
  que reutiliza el mismo controlador exterior, aptus_inventory_item_main y las
  mismas cuatro pestañas y consulta especializada. No es una segunda ficha.

La clase de consulta está separada para que Interface.findWindow no devuelva
accidentalmente una ficha editable del DJ del mismo objeto. No contiene clase
de contenido inicial ni tooltip DB heredado: permanece vacía hasta configurar
y validar el contexto. Abrirla directamente sin contexto no expone propiedades.
La inicialización diferida usa el patrón nativo abrir/configurar; el contenido
real se vincula sólo después de la validación. Es necesario verificar en FGU
la herencia/merge del subwindow, además de las pruebas estáticas.

El bloqueo de consulta es local, permanente y no depende del campo locked. Un
intento de desbloquear no escribe ese campo. Las funciones de Guardar, Eliminar,
perfiles, cualidades, cambio de tipo y drops de imagen/asociaciones rechazan la
acción, incluso con Session.IsHost=true y locked=0. Se mantienen además las
comprobaciones existentes canEditInstance/canDeleteInstance y las validaciones
del gestor; no se cambia el sistema de permisos. Los controles de borrador son
sourceless y sus cambios no escriben directamente en DB.

Los controles secundarios existentes de perfiles requieren un contexto editable,
y los de cualidades revalidan su callback. La consulta no abre estos editores.
Las descripciones/vistas de perfiles son controles de texto sin enlaces de
inventario; no se añaden listas de contenidos, navegación de inventario, botones
de traslado ni enlaces a descendientes. Un contenedor visible se puede consultar,
pero sus descendientes ocultos no pasan la validación de apertura.

La ventana vuelve a validar permisos, Almacenaje y ocultación al cambiar el
inventario/permisos; se cierra si deja de ser accesible. La ficha de consulta se
cierra también al cambiar el contexto de Impersonar/propietario o cerrar el EQUIPO
de origen, y recarga sus propiedades persistidas cuando cambia el inventario.
Una apertura desde otra ficha de personaje sustituye la consulta previa de la
misma clase/ruta en lugar de compartir sus contextos. No se modifican otras
ventanas editables independientes del DJ ni permisos para simular un jugador.

### Archivos de este ajuste de inspección

- campaign/record_char_equipment_structures_aptus.xml
- campaign/record_inventory_item_aptus.xml
- scripts/char_equipment_row_aptus.lua
- scripts/char_equipment_aptus.lua
- scripts/inventory_item_window_aptus.lua
- scripts/record_inventory_item_aptus.lua
- utility/tests/structure_consultation_static_test.js
- utility/tests/inventory_instance_static_test.js
- utility/tests/structure_consultation_test.lua
- utility/tests/inventory_instance_view_test.lua
- utility/tests/inventory_create_test.lua
- utility/EQUIPO_ESTRUCTURAS_FASE_2A.md

### Pruebas y validación manual de inspección

Las mismas 12 suites estáticas relacionadas vuelven a pasar. Se verifica el icono
heredado, las clases, el bloqueo diferido de contenido, los filtros de apertura
y las guardas. Las suites Lua se amplían con controladores reales y dobles de
ventanas/DB, pero NO se han ejecutado (no hay intérprete, no se instala ninguno):

```text
lua utility/tests/inventory_create_test.lua
lua utility/tests/inventory_instance_view_test.lua
```

Cubren apertura desde Todo/Localizaciones/Vehículos, distinción DJ/consulta,
rechazo de descendientes ocultos, revocación de acceso, cambios de hide_contents,
cierre al cambiar contexto y bloqueo directo de handlers aun con privilegios DJ.
La suite de creación actualiza sus dobles con getClass y servicios ya requeridos
por la composición actual. No demuestra renderizado, herencia ni eventos de FGU.

En una campaña de prueba:

1. Revisar Abrir en objetos y contenedores de Localizaciones/Vehículos desde las
   tres vistas; comprobar su alineación final y ausencia en cabeceras/mensajes.
2. DJ normal: abrir y editar con el candado, Guardar y Descartar. Comparar con la
   apertura independiente y verificar que sus permisos siguen siendo iguales.
3. Impersonar: abrir el mismo objeto mientras su ficha editable de DJ está abierta.
   Debe aparecer una consulta separada, bloqueada, que no modifica esa ficha.
4. En consulta probar las cuatro pestañas, candado, Guardar/Eliminar, perfiles y
   cualidades, menús, drops y cualquier control secundario. No puede modificarse
   el registro, ni locked, cantidad, Estado, Ubicación o contención. Repetir como
   jugador real, incluyendo un objeto cuyo locked persistido sea 0.
5. Activar hide_contents en un contenedor: jugador/Impersonar pueden inspeccionar
   el contenedor visible y ver su candado, pero no abrir sus descendientes ocultos.
   Probar nombres/rutas conocidos y comprobar que no hay navegación indirecta
   desde la ficha. Una consulta de un descendiente ya abierta debe cerrarse.
6. Revocar Visibilidad/Acceso o desactivar Almacenaje con una ficha abierta: debe
   cerrarse. Alternar Impersonar, cambiar propietario, cerrar la ficha origen y
   ejecutar /reload; comprobar ausencia de ventanas con contextos antiguos.
7. Abrir el mismo objeto desde dos personajes con propietarios distintos: no se
   reutiliza una consulta con permisos de la otra ficha. Las fichas editables
   independientes del DJ conservan su comportamiento de DJ normal.
8. Revisar consola sin errores, ausencia de escrituras al abrir/cerrar consultas
   y mismo valor de CARGA. No se añaden transferencias ni notificaciones.

## Enlaces a fichas de Localizaciones y Vehículos

Cada cabecera virtual incorpora open_structure en 441,0,25,24, exactamente el
rectángulo de open_record de las filas de objetos. No cambia kind, el icono junto
al nombre. El botón existe independientemente del mensaje, Acceso, activación o
contenido de Almacenaje, siempre que la cabecera se incluya en la vista.
Todo conserva su filtro de estructuras con recursos accesibles; las categorías
específicas permiten abrir también las visibles sin recursos/Almacenaje activo.

Recursos registrados en graphics/graphics_aptus_char_equipment.xml:

- aptus_localizacion_view: PNG original verificado 25×24 px.
- aptus_vehicle_view: PNG original verificado 27×20 px.

Se dibujan con addBitmapWidget w=25,h=24 en el mismo espacio del botón de objeto.
No se modifican los PNG. Revisar visualmente el ajuste del Vehículo al tener una
proporción original distinta; los límites del control son los solicitados.

El controlador de cabecera conserva sólo la ruta y EQUIPO de origen. Al pulsar,
openStructure vuelve a buscar el nodo, obtiene el contexto efectivo actual y
revalida canViewAs. No exige Acceso ni Almacenaje. Reutiliza findWindow/openWindow
con aptus_location para Localizaciones y aptus_structure para Vehículos. Si ya
está abierta la ficha, se trae al frente. No crea/copias registros ni escribe DB.
Se rechazan rutas eliminadas, estructuras no visibles y categorías no soportadas.

**Límite de Impersonar:** la Visibilidad del propietario limita qué ficha se puede
abrir desde EQUIPO. La ventana independiente conserva Session.IsHost real y sus
controles de administración del DJ; no se reproduce en ella la vista de jugador.
No se transmite el contexto de Impersonar ni se alteran permisos globales. Esto
incluye sus pestañas de configuración/Almacenaje y sus permisos reales de DJ.
El jugador conectado abre la ficha con sus restricciones habituales. El enlace
es independiente de la variante estricta de consulta de objetos del apartado
anterior y no cambia su bloqueo.

Archivos modificados en este ajuste:

- graphics/graphics_aptus_char_equipment.xml
- campaign/record_char_equipment_structures_aptus.xml
- scripts/char_equipment_structures_aptus.lua
- scripts/char_equipment_aptus.lua
- utility/tests/structure_consultation_static_test.js
- utility/tests/structure_consultation_test.lua
- utility/EQUIPO_ESTRUCTURAS_FASE_2A.md

Validación estática: registro/rutas/dimensiones PNG, rectángulo igual al de objetos,
Visibilidad revalidada sin condicionar a Almacenaje, clases correctas, reutilización
de ventana y ausencia de escrituras en la apertura. Suite Lua ampliada (no ejecutada
por falta de intérprete) con rutas correctas, traer al frente, vacío/desactivado/sin
Acceso, revocación de Visibilidad, DJ/Impersonar/jugador y ausencia de escrituras.

Pendiente en FGU:

1. Comprobar ambos iconos en Todo y sus categorías, alineados con Abrir de objetos,
   sin solapamiento con CAR/scrollbar; revisar proporción del PNG de Vehículo.
2. Abrir Localización/Vehículo y repetir con la ficha ya abierta: misma estructura
   y ventana original al frente, sin duplicados.
3. En categorías específicas probar Almacenaje vacío/desactivado y falta de Acceso:
   la cabecera conserva el botón y abre la ficha narrativa visible.
4. Con jugador real, conceder/revocar Visibilidad; intentar una apertura después de
   revocarla debe rechazarse. Verificar los controles existentes de esa ficha.
5. Como DJ con Impersonar comprobar filtro de Visibilidad del propietario y que la
   ficha independiente mantiene permisos reales de DJ (limitación documentada),
   sin cambiar las otras ventanas, identidades ni permisos.
6. Revisar consola, /reload, datos y CARGA sin cambios. No hay transferencias nuevas.

### Tipografía de nombres de estructuras

Las cabeceras reutilizan aptus_inventory_row_text (Roboto Condensed Regular,
14 px), igual que los nombres de objetos. Conservan bounds 34,2,181,20 y sus
iconos. El nombre se presenta en mayúsculas (incluidos acentos españoles y ñ),
sin escribir en DB. Un widget nativo limita el texto a 181 px y conserva el nombre
completo en tooltip. Los mensajes mantienen su fuente anterior de 12 px.
Modificados XML de cabeceras, su controlador, la suite estática de consulta y
este informe. Las 12 suites relacionadas pasan. Pendiente en FGU comprobar
alineación vertical, nombres largos y mayúsculas en Todo/Localizaciones/Vehículos;
los iconos de inspección permanecen en 441,0,25,24, sin cambios.
