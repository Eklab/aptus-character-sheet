> Actualización posterior: se ha adelantado exclusivamente la eliminación de instancias.
> Eliminar ya es funcional, con permisos independientes del candado y confirmación
> nativa obligatoria. Detalles, pruebas y límites en INVENTARIO_ELIMINACION.md.

# Inventario APTUS — fase 2: creación desde catálogo y ficha de instancia

## Alcance

Se conserva la lectura validada de fase 1 y la única colección canónica:
`charsheet.<personaje>.inventorylist`. Se añaden creación desde plantillas y
consulta/edición de propiedades particulares de la instancia. Sin división, fusión, transferencia,
eliminación de objetos existentes, cambios de Estado/Ubicación, carga real ni
creación en estructuras. No se utiliza ItemManager ni sus avisos de traslado.

Los fixtures existentes se conservan. La revisión de la ficha añade al catálogo
únicamente la propiedad opcional Riqueza y su editor. No se registran
inicializadores de datos ni migraciones.

## Creación común

`APTUSInventoryManager.createFromTemplate(nodeChar, nodeTemplate)`:
1. Exige personaje de campaña vivo, editable y propio del usuario o del DJ,
   respetando `DB.isReadOnly`, propiedad y el estado de lectura de WindowManager.
2. Valida origen `aptus_equipment`, esquema 1, ID/versión, nombre, tipos y
   propiedades numéricas; consulta confirmación y conflictos del gestor existente.
   No llama a su guardado ni a su callback de alta.
3. Crea un nodo nuevo en inventorylist y copia exclusivamente `properties`
   como subárbol independiente, incluyendo datos particulares no mostrados en UI.
4. Inicializa count=1, carried=1, nombre, procedencia y aptus.container vacío;
   publica aptus.instance_schema=1 al final.
5. Verifica el contrato, valores iniciales y contenido tipado de la copia.
6. Ante un error recuperable retira sólo el nodo que acaba de crear. Si creó
   la colección y queda vacía, también la retira. Una limpieza no verificable
   se comunica explícitamente; nunca se borran registros previos para recuperar.

Se escribe carried antes del nombre para no activar la propagación nativa por
coincidencias textuales de location sobre objetos heredados. No se invoca el
callback nativo de incorporación de objetos ni el de creación de plantillas.

Dos altas desde la misma plantilla producen dos nodos distintos, ambos con
cantidad uno. No se apilan. La plantilla no cambia y una actualización posterior
suya no altera las propiedades ya copiadas de las instancias.

### Añadir y arrastrar

Añadir ocupa el hueco existente entre filtros y búsqueda (X=386, Y=18, 20×24),
con el icono APTUS de alta adaptado al espacio. No se mueve ninguna columna.
Sólo aparece en Todo/Personaje si el usuario puede gestionar esa ficha.

Se reutiliza `DialogManager.requestSelectionDialog` de CoreRPG, con selección
única y opciones con enlace a la plantilla y módulo. La lista se construye
consultando los mismos roots del catálogo (`aptus_equipment_templates` y
`reference.aptus_equipment_templates`) mediante DB.getChildrenGlobal. No hay
catálogo alternativo ni copias de definiciones para el selector.

Sólo se ofrecen registros disponibles para ese cliente: las plantillas de
campaña deben estar compartidas cuando corresponda y los módulos deben estar
accesibles/cargados. En el DJ se excluyen altas todavía no confirmadas; se
revalida siempre la plantilla seleccionada al crear. La marca privada de alta
sin confirmar no sustituye al control normal de qué registros comparte el DJ.

El callback y el drop terminan en `createFromCatalogue`, que llama una sola
operación del gestor. Se admite drop en la lista, filas y espacio de EQUIPO.
El destino siempre es la raíz, aunque se suelte sobre un contenedor. Los enlaces
que no son plantillas se consumen y rechazan, evitando el fallback de transferencia
nativa de la ficha. No se admite arrastrar una instancia para trasladarla.

Si se crea correctamente, se limpia una búsqueda activa y se lleva el scrollbar
al nuevo objeto, conservando el filtro Todo/Personaje. Cancelar el selector no
crea nada. Cerrar EQUIPO antes de confirmar descarta el callback; revocar permisos
o descargar el origen antes de confirmar provoca rechazo sin alta.

## Ficha de instancia

Ver mantiene el icono de 25×24 y su posición validada. Ahora abre
`aptus_inventory_item` sobre el nodo concreto, nunca sobre la plantilla.

La ventana reutiliza mediante copy la composición de `aptus_equipment` y
`aptus_equipment_main`, con controlador y guardado exclusivos de instancia.
Reutiliza el candado nativo de CoreRPG (`toolbar_field_step`, `locked`), el
control nativo de minimizar, el cierre APTUS, las cuatro páginas, perfiles y
selector de asociaciones de cualidades. No incorpora copia de plantillas,
compartición, exportación ni duplicación genérica de registros.

Candado cerrado: todos los campos en consulta y sin controles de edición.
Abierto: propiedades particulares editables y Guardar disponible. Se respeta el
valor nativo predeterminado de campaña (desbloqueado cuando no existe locked),
sin escribir un candado al abrir ni migrar instancias. El token de concurrencia
excluye únicamente locked: bloquear/desbloquear conserva el borrador. El guardado
sigue comprobando el permiso, el candado actual y todos los demás datos.

### Campos editables

- Nombre, descripción, imagen, tipo y Riqueza.
- Apilable, máximo de pila, condición de contenedor, load_every, load_value y capacity.
- Modificadores defensivos y requisitos generales.
- Perfiles particulares, sus cualidades y las asociaciones generales de cualidades.

Estas propiedades no ejecutan apilamiento, división ni cálculos. Un contenedor
requiere cantidad uno, no apilable y máximo uno. No se permite desclasificar un
contenedor con objetos asociados: se rechaza sin modificar vínculos ni extraer
contenido. El nombre se puede personalizar sin cambiar identificadores.

Cantidad, carried, aptus.container, identificadores, esquema y procedencia no
forman parte del borrador editable. El panel inferior izquierdo se reserva para
mensajes locales; al abrir bloqueado permanece vacío. La cabecera se refresca
desde DB sin sustituir el borrador. Detalles en INVENTARIO_FASE_2_REVISION.md.

Guardar llama exclusivamente a saveInstance, que admite una lista cerrada de
campos, valida las colecciones con el validador existente y comprueba concurrencia.
Escribe sólo escalares distintos y colecciones modificadas, conservando el resto
de properties. Los perfiles mantienen sus campos adicionales desconocidos.
Se verifican las escrituras; ante fallo se restauran escalares y colecciones
originales, incluidos sus tipos y ausencia previa. No se llama al guardado ni
al callback de alta de plantillas. Los datos opcionales incompatibles no se
reparan al abrir y bloquean la edición en lugar de eliminarse silenciosamente.

Descartar o cerrar sin Guardar descarta las propiedades del borrador; el candado
es metadato nativo independiente. Eliminar aparece deshabilitado a la izquierda
de Descartar y Guardar. No existe callback de eliminación.

`properties.is_wealth` es un número opcional 0/1, con valor lógico predeterminado
falso. Se edita en Datos comunes del catálogo y de la instancia, se copia con
properties al crear, y no se propaga a instancias previas. Si una plantilla antigua
omite el campo, su copia también puede omitirlo y se interpreta como falso. No
se activa todavía el filtro Riqueza ni su marcador de diamante.

### Presentación futura de capacidad

Existen load_every, load_value y capacity, pero no un dato fiable de carga
acumulada. getContainerDisplayName(item, accumulated) prepara el formato
Nombre (carga/capacidad) sólo si un futuro llamador aporta una carga real válida.
Hoy EQUIPO no aporta ese argumento: conserva el nombre sin números simulados y
muestra la capacidad máxima real en el tooltip, con carga acumulada pendiente.
CAR y CARGA permanecen neutros. Antes de activarlo deben aprobarse la conversión
de cantidad/load_every/load_value (incluido redondeo), unidades, tratamiento de
propiedades ausentes, capacidad cero, inclusión del peso propio de contenedores
anidados y suma de todos los descendientes sin duplicarlos. No se implementa
ninguna de estas reglas ni restricciones de capacidad.

Las propiedades particulares editadas deberán formar parte de la comparación
futura de pilas: no bastará nombre, template_id o template_version. Esto incluye
propiedades numéricas, descripción, imagen, perfiles, cualidades y extensiones.

La independencia respecto a la plantilla no duplica imágenes ni definiciones de
cualidades: sus referencias continúan utilizando los recursos existentes. Descargar
un módulo puede dejar una imagen o definición inaccesible, pero no elimina las
propiedades copiadas ni convierte el objeto en una referencia a la plantilla.

## Refresco

EQUIPO conserva su lector. Los observadores de campos relevantes, incluidos los
escalares editables, reconstruyen la proyección. Renombrar un contenedor actualiza
la Ubicación visible de sus hijos sin modificar sus referencias por nodo.
Los observadores se retiran al cerrar. El editor detecta datos concurrentes y
pide Releer si su borrador ya no corresponde al registro actual.

Estado y Ubicación siguen sin operaciones de modificación desde EQUIPO.
Carga y CAR mantienen los indicadores neutros de la fase 1.

## Archivos

Creados:
- `campaign/record_inventory_item_aptus.xml`.
- `scripts/inventory_item_window_aptus.lua`.
- `scripts/record_inventory_item_aptus.lua`.
- `utility/tests/inventory_create_test.lua`.
- `utility/INVENTARIO_FASE_2.md`.

Modificados:
- `scripts/manager_aptus_inventory.lua`: permisos, plantillas disponibles,
  creación verificada y edición escalar protegida; lector conservado.
- `scripts/char_equipment_aptus.lua`: Añadir/drop y refresco.
- `scripts/char_equipment_row_aptus.lua`: apertura y drop de fila.
- `scripts/char_equipment_state_aptus.lua`: comentario actualizado; sigue de lectura.
- `campaign/record_char_equipment_aptus.xml`: Añadir, receptor drop y Ver activo.
- `extension.xml`: registro de las clases de instancia.
- `utility/EQUIPO_FICHA_VISUAL.md`: estado actual y validación.

## Pruebas disponibles

`utility/tests/inventory_create_test.lua` utiliza DB sólo en memoria y carga los
gestores reales. Cubre altas independientes, defaults, procedencia, copia de
propiedades desconocidas, independencia en ambas direcciones, campos protegidos,
conflictos de edición, recuperación de errores de copia/escritura, ramas nuevas,
permisos, módulo de lectura y rechazo de destinos estructurales/orígenes inválidos.
También comprueba conservación de registros heredados y renombrado de contenedores.

Desde character-sheet, con Lua 5.3/5.4:

    lua utility/tests/inventory_read_test.lua
    lua utility/tests/inventory_create_test.lua
    lua utility/tests/equipment_save_test.lua
    lua utility/tests/inventory_instance_view_test.lua
    node utility/tests/inventory_instance_static_test.js

Ninguna suite se incluye en extension.xml. La comprobación estática Node pasa;
las suites Lua no se ejecutaron aquí: no hay Lua/luac ni Fantasy Grounds.
No se instalaron dependencias. La revisión posterior se documenta en
INVENTARIO_FASE_2_REVISION.md.

Comprobaciones estáticas realizadas en desarrollo:
- XML balanceado, archivos referenciados disponibles y copia de clases resuelta.
- Controles aplicables reutilizados en la instancia; callbacks atendidos por su
  controlador local, sin llamadas al guardado/alta/confirmación de plantillas.
- Dimensiones de columnas, fuentes, scrollbar y CARGA conservadas; botón Añadir
  dentro del hueco sin solaparse con filtros ni búsqueda.
- Un único punto de creación llamado por Añadir/drop; sin llamadas ItemManager,
  datos ficticios activos, código de apilamiento o traslado.
- Lista editable sin campos estructurales, copia sólo de properties y defaults
  verificados, carried inicializado antes de asignar el nombre.

## Validación en Fantasy Grounds — campaña de prueba

1. Usar una campaña de prueba con esta versión. Puede importarse manualmente
   el fixture existente de fase 1; no se modifica ni se importa automáticamente.
2. En el catálogo APTUS crear y Guardar una plantilla utility llamada «Objeto fase 2»,
   con descripción, imagen opcional y alguna propiedad defensiva distinta de cero.
3. Abrir EQUIPO en Todo o Personaje y pulsar Añadir. Elegir esa plantilla.
   Debe aparecer un objeto raíz Transportado, cantidad 1 y Ubicación `-`.
4. Añadirla otra vez: dos filas/nodos independientes, ninguna cantidad 2.
   Con el fixture inicial, 19 filas válidas pasan a 21; los 11 avisos permanecen.
5. Arrastrar la plantilla desde el índice o su enlace de ficha al cuerpo vacío
   y después sobre una fila: una instancia nueva por drop, siempre en raíz.
6. Probar Añadir con búsqueda activa: tras crear se limpia la búsqueda y el nuevo
   objeto queda visible mediante el desplazamiento nativo, sin mover columnas.
7. Abrir Ver en una de las instancias. Revisar sus páginas, procedencia, cantidad,
   Estado/Ubicación de lectura y propiedades copiadas. No debe aparecer Crear copia
   de plantillas. Abrir el candado habilita Cambiar tipo y los controles de
   perfiles/cualidades; cerrarlo deja las cuatro páginas en consulta.
8. Modificar nombre, descripción y pro; Guardar. EQUIPO actualiza el nombre y
   la instancia conserva los valores. La otra instancia y la plantilla no cambian.
9. Editar y Guardar después la plantilla. Las instancias anteriores conservan
   nombre/propiedades/versión de origen; una nueva instancia usa los nuevos valores.
10. Abrir una instancia, modificar un borrador y cerrar sin guardar; reabrir:
    deben conservarse los datos guardados. Probar Descartar.
11. Repetir con plantilla de módulo disponible: exportar una plantilla desde una
    campaña de preparación o utilizar un módulo APTUS ya existente y cargarlo.
    El selector debe mostrar su procedencia; copiar desde módulo no exige editarlo.
12. Como jugador propietario, usar una plantilla de campaña compartida o de módulo
    accesible. Como jugador sin propiedad, no debe aparecer Añadir ni aceptar altas;
    una ficha de instancia accesible debe ser de lectura si no tiene permiso.
13. Cancelar el selector, cerrar EQUIPO antes de confirmarlo, descargar el origen
    antes de confirmar e intentar soltar un enlace de instancia/item no APTUS:
    no deben generarse nodos incompletos ni movimientos nativos.
14. Con dos editores sobre la misma instancia (por ejemplo DJ y propietario),
    guardar uno y después el borrador antiguo del otro: debe exigir Releer.
15. En el fixture, renombrar una Bolsa desde Ver y Guardar: sus hijos muestran
    el nombre nuevo en Ubicación, con los mismos IDs y Estados heredados.
16. Cerrar y reabrir la campaña de prueba: verificar persistencia, valores iniciales,
    propiedades particulares y separación entre instancias y plantilla.
17. Comprobar filtros, búsqueda, jerarquía de un nivel, tooltips, scrollbar, Ver,
    Estado sin avance, CAR/carga pendientes y otras pestañas sin regresiones.

Los errores recuperables de copia/guardado se ensayan con el doble DB de la suite,
no provocando daños en una campaña real. Una interrupción del proceso o pérdida de
permisos durante recuperación no es una transacción atómica; cualquier restauración
no verificable se informa. Esto no implementa transferencias de fases posteriores.
