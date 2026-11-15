# Tipos de daño descriptivos por perfil

## Modelo y catálogo

El catálogo único está en scripts/manager_aptus_equipment.lua. No se añade un
catálogo persistido ni un gestor global adicional. getDamageTypes devuelve una
copia de sus nueve entradas, con identificadores estables y orden fijo:

| ID | Nombre |
|---|---|
| bludgeoning | Contundente |
| slashing | Cortante |
| piercing | Perforante |
| fire | Fuego |
| ice | Hielo |
| electric | Eléctrico |
| chemical | Químico |
| radiation | Radiación |
| supernatural | Sobrenatural |

Cada perfil puede seleccionar cualquier combinación. Son datos descriptivos:
no intervienen en tiradas, daño, resistencias, vulnerabilidades o efectos.

La persistencia usa un nodo damage_types dentro del perfil y un hijo numérico
por ID seleccionado. Ejemplo de instancia:

    charsheet.<personaje>.inventorylist.<objeto>.properties.profiles.<perfil>
      damage_types
        slashing = (number) 1
        fire     = (number) 1

En plantillas, la misma estructura cuelga de
aptus_equipment_templates.<plantilla>.properties.profiles.<perfil>; también se
conserva en los registros de módulo que ya utiliza el catálogo.

No se guarda una tabla Lua literal, JSON ni nombres visibles. La representación
transitoria sigue el árbol tipado existente:

    damage_types = {
      slashing = { kind="number", value=1 },
      fire = { kind="number", value=1 }
    }

Los IDs como claves hacen imposible duplicar un tipo dentro del mismo perfil.
No seleccionado significa hijo ausente, no un cero persistido. El nodo puede
faltar o estar vacío: ambas formas significan cero tipos. Los perfiles nuevos
inician su borrador con la colección vacía; los serializadores existentes pueden
omitirla o conservar un nodo vacío. No se materializa al leer perfiles antiguos.

validateDamageTypes acepta ausencia, colección vacía y las selecciones conocidas
con valor numérico uno. Rechaza IDs desconocidos, tipos erróneos o campos extra
antes del guardado. Los datos incompatibles no se convierten ni se borran:
se conserva la información y se rechaza guardar, utilizando el sistema de errores
existente. No hay migración automática ni cambio de versión de esquema.

## Creación, lectura, guardado y copia

newProfile prepara la colección opcional. La lectura existente de colecciones
conserva el subárbol damage_types sin filtrar sus campos. validateCollections
invoca la validación nueva, de modo que se reutiliza tanto para plantillas como
para instancias y su creación desde catálogo.

El guardado de árboles tipados, compactado, verificación y recuperación existentes
ya serializa los nodos nuevos. No se modifica el gestor de inventario. La copia
de properties desde plantilla a instancia es profunda y conserva estos valores;
las modificaciones posteriores de la plantilla no se propagan a instancias.
No se escriben defaults en perfiles antiguos al abrirlos o leerlos.

No cambian damage, critical, profile_id, habilidades, modificadores ni cualidades.
Cambiar sólo tipos no modifica las expresiones de daño/crítico. La concurrencia
y recuperación de errores incluyen la colección al formar parte del árbol del perfil.

## Editor de perfiles

Se reutiliza aptus_equipment_profile_row para plantillas e instancias. El viewport
actual es 408 × 97 y ya tiene scrollbar. Se conservan todos los controles originales
entre y0 e y96. Se añade TIPOS DE DAÑO en y101 y una cuadrícula de 3 × 3:

- Columna: x2, x136 o x270, paso de 134 px.
- Fila: y122, y144 o y166, paso de 22 px.
- Casillas nativas buttonc_checkbox: 20 × 20, sin datasource.
- Etiquetas: x+24, ancho108, alto20, fuente local existente de 12 px.
- Separador inferior en y190; altura del bloque de editor: 195 px.

El apartado nuevo completo ocupa menos de los 97 px del viewport y se alcanza
con el desplazamiento existente. Tres columnas permiten ver sus nueve selecciones
juntas sin cambiar la ventana ni comprimir los controles de combate actuales.
Los nombres se obtienen del catálogo central, no se duplican en el XML.

configureDamageTypes inicializa las casillas con una guarda para que la carga no
modifique la colección. damageTypeChanged aplica cada selección exclusivamente
al borrador, respetando setEditable y owner.isEditable. En lectura, las casillas
están bloqueadas. Guardar es el único punto que persiste. Descartar/releer crea
el borrador desde DB y elimina las selecciones no guardadas. El funcionamiento del
candado local, sus permisos y los botones de la instancia no se modifica.

## Consulta de Arma C.C.

La primera línea, los PNG, tamaños, columnas, scroll y tarjetas de 393 × 52 no
cambian. La segunda línea utiliza formatProfileDamageTypes y el resumen de
cualidades existente:

- Tipo: Cortante · Cualidades: Ocultable
- Tipos: Cortante, Perforante · Cualidades: Precisa
- Tipos: Cortante, Fuego · Cualidades: Nada
- Tipo: Nada · Cualidades: Nada

La enumeración sigue el orden del catálogo, independientemente del orden físico
de los nodos. Se utiliza Tipo con cero/uno y Tipos con varios. Nunca se muestran
IDs internos ni una segunda línea vacía por falta de cualidades.

El textwidget existente mantiene ancho máximo381 dentro de la zona inferior
(6,29,381,19), con puntos suspensivos. Saltos de línea/tabulaciones en nombres de
cualidad se presentan como espacios para no generar otra línea. El tooltip incluye
la línea completa y, a continuación, el resultado sin alterar de details del gestor
de cualidades. No se duplica su resolución ni se modifican las cualidades generales.

## Archivos

Modificados:

- scripts/manager_aptus_equipment.lua: catálogo, helpers puros, creación y validación.
- scripts/equipment_profile_aptus.lua: nueve casillas y cambios en borrador.
- campaign/record_equipment_aptus.xml: templates nativos y apartado del perfil.
- scripts/item_melee_consultation_aptus.lua: lectura/formato de tipos por perfil.
- scripts/item_melee_block_aptus.lua: segunda línea y tooltip completo.
- utility/tests/equipment_save_test.lua: guardar/releer/desmarcar y legado de plantilla.
- utility/tests/inventory_create_test.lua: copia a instancias, independencia y recuperación.
- utility/tests/inventory_instance_view_test.lua: consulta, pluralización y ausencia de cualidades.
- utility/tests/inventory_instance_static_test.js: scripts y pruebas nuevos en balance léxico.
- utility/ARMA_CC_CONSULTA.md: referencia al nuevo formato.

Creados:

- utility/tests/damage_types_test.lua.
- utility/tests/damage_types_static_test.js.
- utility/TIPOS_DANO_PERFILES.md.

Sin cambios en PNG, fuentes, APTUS Dice, gestores de inventario/cualidades, datos de
campaña, bloqueo, creación/eliminación de objetos o vistas de otros tipos.

## Comprobaciones

Ejecutado y superado desde character-sheet:

    node utility/tests/damage_types_static_test.js
    node utility/tests/item_melee_consultation_static_test.js
    node utility/tests/inventory_instance_static_test.js
    node --check utility/tests/damage_types_static_test.js
    node --check utility/tests/item_melee_consultation_static_test.js
    node --check utility/tests/inventory_instance_static_test.js

Comprueban catálogo de nueve IDs sin duplicados y en orden, casillas nativas,
geometría, XML/referencias, ausencia de escrituras DB locales, tooltip/recorte,
SHA-256 de los ocho PNG originales y balance léxico de catorce Lua. El balance
léxico no sustituye la compilación o ejecución de Lua.

Preparadas/ampliadas, pero NO ejecutadas por falta de Lua/luac y FGU:

    lua utility/tests/damage_types_test.lua
    lua utility/tests/equipment_save_test.lua
    lua utility/tests/inventory_create_test.lua
    lua utility/tests/inventory_instance_view_test.lua

Cubren cero/uno/varios/nueve, orden, duplicados por selección repetida, validación,
legacy sin campo, casillas de lectura/edición, descarte local, guardado/relectura,
copia profunda e independencia de plantilla/instancias, daño/crítico intactos,
recuperación de fallo de guardado y segunda línea con tooltip. No se cargan en
extension.xml ni escriben campañas. No se instalaron dependencias.

## Validación manual en Fantasy Grounds Unity

1. En campaña de prueba, abrir una plantilla con perfil antiguo sin damage_types:
   funciona igual, sin añadir el campo al consultar. Desbloquear y acceder por
   scroll a TIPOS DE DAÑO: nueve casillas, nombres completos y ninguna marcada.
2. Marcar Cortante y Perforante: selecciones independientes. Desmarcar una. Revisar
   todos los tipos y confirmar que puede elegirse cualquier combinación, incluidos nueve.
3. Sin Guardar, pulsar Descartar: los datos persistidos y las casillas originales
   permanecen/reaparecen. Volver a seleccionar y Guardar; cerrar/reabrir confirma valores.
4. Crear una instancia desde esa plantilla. Consultar melee_weapon: nombres visibles
   en orden de catálogo, sin IDs. Editar tipos particulares y guardar: no cambia
   la plantilla ni otras instancias. Modificar luego la plantilla: instancias intactas.
5. Probar cero tipos y cero cualidades: Tipo: Nada · Cualidades: Nada. Un tipo:
   Tipo: Cortante. Varios: Tipos: Cortante, Perforante. Revisar combinaciones con
   cualidades propias distintas de las generales del equipo.
6. Probar muchos tipos y cualidades largas, con seis perfiles: truncado dentro de
   393 × 52, tooltip con línea completa y todas las descripciones, sin filas nuevas
   ni solapamientos; generales después del último perfil y scrollbar funcional.
7. Confirmar que alternar candado no guarda ni pierde el borrador; las casillas se
   bloquean en consulta. Guardar/Descartar y Eliminar mantienen sus validaciones.
8. Desmarcar todos y Guardar: colección ausente/vacía, Tipo: Nada tras reabrir.
   Revisar damage y critical sin modificaciones y reiniciar la campaña de prueba
   para confirmar persistencia. Comprobar consola sin errores nuevos.

La apariencia, los clics y el desplazamiento no se consideran validados hasta
probarlos en Fantasy Grounds. Esta implementación termina aquí.
