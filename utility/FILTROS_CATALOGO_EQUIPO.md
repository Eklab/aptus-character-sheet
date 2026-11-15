# Filtros de tipo del catálogo de equipo

Se amplía `masterindex` mediante un script que delega en CoreRPG y crea controles
únicamente para `aptus_equipment`. Una reserva de 64 px sitúa la etiqueta y el
desplegable después de Group; la lista utiliza el espacio restante. La selección
se combina mediante AND con el resultado nativo de categorías, búsqueda y acceso.
No se sustituyen las filas nativas ni sus operaciones de arrastre/ordenación.

`aptus_equipment_select_dialog` deriva de `select_dialog`, conserva su cola,
selección, botones y callbacks, e inserta la misma franja antes de la lista.
La llamada desde el botón + sólo cambia el origen visual y la clase del diálogo;
la creación continúa pasando por `APTUSInventoryManager.createFromTemplate`.
El filtro oculta filas y desmarca selecciones ocultas sin reconstruir los registros.

Ambos controles consultan `APTUSEquipmentManager.getTypes()` al crearse y utilizan
`matchesTypeFilter`. No hay enumeración duplicada ni escritura DB. Todos incluye
plantillas sin tipo reconocido; no se les asigna un tipo. El selector muestra el
catálogo completo: una plantilla incompatible puede verse, pero su creación seguirá
siendo rechazada por las validaciones anteriores. No se implementa Munición.

Las opciones reflejan los tipos registrados antes de abrir las ventanas. Si otro
componente registra un tipo mientras una ventana ya está abierta, se debe recrear
esa ventana o recargar FGU para actualizar su desplegable.

## Corrección visual del desplegable

El filtro anterior alojaba `comboboxc` en una subventana de 36 px. CoreRPG crea
la lista emergente como otro control de esa misma ventana, debajo del combobox;
esa composición dejaba su menú fuera del área útil de la subventana.
Ahora etiqueta, combobox, flecha y lista emergente pertenecen a la ventana principal.
El espaciador no pinta ningún fondo ni tapa controles; únicamente reserva altura.

La etiqueta utiliza `reference-header`, exactamente la fuente de Group. Ocupa una
línea propia (y=4, alto=22); el desplegable está debajo (y=34, alto=20), dentro de
la reserva de 64 px. Se conserva el combobox nativo y sus marcos, sin PNG nuevos.
En el catálogo se mide la etiqueta Group para alinear el inicio del desplegable
con el selector nativo. En Añadir equipo se conservan los márgenes de contenido.

## Comprobaciones

`node utility/tests/equipment_type_filters_static_test.js` verifica referencias,
aislamiento, delegación nativa y ausencia de escrituras. La prueba aislada
`lua utility/tests/equipment_type_filters_test.lua` cubre el predicado común,
tipos ausentes/desconocidos y registro dinámico. No hay Lua ni FGU disponibles
en el entorno de comprobación; no se ha ejecutado esa prueba Lua.

## Validación manual en FGU

1. Abrir EQUIPO general: comprobar Tipo de equipo debajo de Group y Todos inicial.
2. Probar cada tipo, incluido uno sin plantillas; combinar Group y búsqueda inferior.
3. Verificar orden alfabético, scrollbar, cambio de tamaño y arrastre al personaje.
4. Abrir Añadir equipo con +: comprobar filtro entre explicación y lista.
5. Cambiar de tipo con una plantilla seleccionada; no debe confirmarse una selección
   que quede oculta. Comprobar lista vacía y cancelar sin creación de objetos.
6. Seleccionar una plantilla compatible y crear una instancia: comprobar copia
   independiente y plantilla original intacta.
7. Comprobar plantillas de módulos y plantillas sin tipo en Todos. Intentar crear
   una incompatible debe mostrar el rechazo existente, sin modificar datos.
8. Abrir otros catálogos CoreRPG y otros selectores: deben conservar su presentación.
9. En ambas ventanas, comprobar el filtro cerrado, abierto y tras seleccionar:
   una sola caja, valor y flecha visibles, ninguna franja residual, y menú completo
   sobre el listado. Verificar la fuente clara de la etiqueta y la alineación con Group.

Pendiente en FGU: geometría efectiva de los anclajes nativos, comportamiento de
selección, módulos, arrastre y confirmación. No se corrigen aquí los ajustes
visuales pendientes de perfiles de combate.
