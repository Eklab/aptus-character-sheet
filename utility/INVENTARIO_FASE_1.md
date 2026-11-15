# Inventario APTUS — fase 1: modelo mínimo y lectura

## Alcance

EQUIPO consulta exclusivamente `charsheet.<personaje>.inventorylist`. No crea,
edita, transfiere, elimina o apila objetos. No modifica plantillas ni migra
registros heredados. Los controles de Estado, cantidad y Ubicación son de
lectura; Ver permanece deshabilitado. APTUS Dice y otras pestañas no cambian.

`APTUSInventoryManager` se registra desde `extension.xml` sin inicializadores
DB. Sus únicas llamadas DB son de consulta. Los observadores de la ventana
sólo reconstruyen controles sin datasource; se retiran al cerrar la ventana.

## Contrato mínimo aceptado

| Ruta relativa al objeto | Tipo DB y condición |
| --- | --- |
| `name` | string, no vacío ni sólo espacios |
| `count` | number, entero positivo y finito |
| `carried` | number, 0, 1 o 2 |
| `template_id` | string, no vacío ni sólo espacios |
| `template_version` | number, entero positivo y finito |
| `properties` | node |
| `properties.type_id` | string, uno de los siete tipos actuales de EQUIPO |
| `properties.is_container` | number, 0 o 1 |
| `aptus.instance_schema` | number, exactamente 1 |
| `aptus.container` | string explícito; vacío para raíz, identificador de nodo para contenido |

Un contenedor requiere cantidad uno. El lector no añade valores ausentes ni
convierte textos numéricos. Los demás campos de `properties` se conservan en
un snapshot tipado de lectura, sin exigir todavía las reglas de fases futuras.
No se consulta la plantilla para completar o corregir la instancia.

Tipos e iconos: melee_weapon → arma_cc; ranged_weapon → arma_proy;
utility → utilidad; electronic → electrico; storage → contenedor;
protection → proteccion; electromechanical_system → mecanico_electrico.
Se registra el icono existente `aptus_utilidad_item`, antes no registrado en
los recursos locales de esta pestaña. No se crea ni modifica ningún PNG.

## API de lectura y relaciones

- `isInstance(node)`: valida el contrato local, devuelve booleano y motivo.
- `getCharacterInventory(nodeChar)`: devuelve `roots`, `items`, `diagnostics`
  e `ignored`; sólo acepta un personaje de campaña bajo `charsheet.<id>`.

Cada elemento aceptado incluye identidad de nodo/ruta, nombre, cantidad,
procedencia, snapshot de propiedades, padre inmediato, raíz resuelta,
Estado efectivo, Ubicación, icono y sus hijos lógicos.

La lectura ordena por identificador nativo de nodo para obtener un orden
estable. Resuelve padres exclusivamente en la misma colección; no usa el
nombre del objeto ni interpreta rutas externas. Un padre debe ser una instancia
válida y estar marcado como contenedor. El grafo se resuelve iterativamente,
sin límite artificial de profundidad y sin recursión sobre posibles ciclos.

Referencias inexistentes, padres incompatibles/no contenedores, autociclos y
ciclos entre objetos excluyen la rama afectada del listado. No se convierten
en nuevas raíces ni se inventa un Estado para ellas. Todos los objetos omitidos
se conservan intactos en DB y se enumeran en los diagnósticos del pie de EQUIPO.
El aviso visible indica cuántos hay; su tooltip contiene identificadores y motivos.

Los objetos raíz usan su propio carried. Los contenidos heredan exclusivamente
el carried de su contenedor raíz: 2 Equipada, 1 Transportada y 0 Sin estado.
El carried guardado de los hijos se conserva sin cambios. Ubicación muestra
`-` en raíz y el nombre del contenedor inmediato cuando existe.

## Integración visual

Se mantienen todas las dimensiones, iconos, fuentes, filtros y conexiones.
La jerarquía interna conserva múltiples niveles, pero todos los descendientes
se dibujan con una única indentación de 18 px.

Todo y Personaje muestran el inventario real del personaje. Localizaciones,
Vehículos y Riqueza conservan sus filtros y presentan un aviso de integración
pendiente: no se leen estructuras ni se implementa clasificación de Riqueza.
La búsqueda conserva los ascendientes necesarios y los descendientes de un
nombre coincidente; su recorrido también es iterativo.

Cada cambio observado en los campos relevantes reconstruye la vista y recalcula
Estados, nombres de ubicación, ramas y scrollbar. Se conserva el comportamiento
actual de volver al primer resultado después del refresco. No se preserva aún
la posición de desplazamiento durante cambios externos.

Estado conserva sus iconos, tooltip y área de 32×24, pero no puede avanzar.
Tiene `readonly`, no tiene datasource y su script ya no llama a `cycleValue`.

CAR muestra `—` en todas las filas: `load_value` y `load_every` no determinan
por sí solos una regla aprobada de carga total o de contenedores. El panel de
CARGA conserva su geometría, con relleno oculto, valor `—` e indicación
`Pendiente`. Nunca se presenta `6 / 24` como dato real.

La muestra Lua anterior está archivada en
`utility/fixtures/equipment_visual_sample.lua`, fuera del registro de extensión.
No se carga ni se mezcla con inventario real.

## Fixture manual de Fantasy Grounds

Archivo: `utility/fixtures/inventory_phase1_character.xml`.
No está incluido en `extension.xml`. Es un personaje nuevo exportable/importable,
no una rutina de creación de objetos. El formato `<root><character>` corresponde
al importador de personajes de CoreRPG (`CampaignDataManager.importChar`).

**Usar exclusivamente en una campaña nueva de prueba**, nunca importar encima
ni modificar una ficha de una campaña existente.

1. Crear una campaña nueva de CoreRPG y activar APTUS Character Sheet.
2. Como DJ, ejecutar `/importchar` o usar Importar personaje de CoreRPG.
3. Seleccionar `utility/fixtures/inventory_phase1_character.xml` desde el
   directorio de trabajo de esta extensión. Si se distribuye empaquetada,
   copiar sólo ese XML a una ubicación elegible por el diálogo nativo.
4. Abrir el nuevo personaje `PRUEBA APTUS — Inventario fase 1` y entrar en EQUIPO.
   No es necesario cargar plantillas: las propiedades del fixture son independientes.

El fixture contiene 30 registros: 19 válidos, 6 con relaciones inválidas y
5 incompatibles con el contrato. Deben verse 19 filas y 11 avisos. El total
visible de 456 px exige scrollbar dentro del viewport actual de 232 px.

Casos principales:
- id-00001 Mochila, raíz Transportada.
- id-00003 Bolsa, dentro de Mochila, con carried propio 0: efectivo Transportada.
- id-00004 Botiquín e id-00005 Venda ×3: dentro de Bolsa, efectivos Transportada.
- id-00012 Caja interior e id-00013 Documento profundo: tercer nivel interno,
  efectivos Transportada, con una única indentación visual en todos los casos.
- id-00007 Pistola: raíz Equipada; id-00008 Munición ×12: Transportada;
  id-00009 Objeto dejado en el suelo: Sin estado.
- id-00010 otra Bolsa: raíz Equipada; id-00011 otra Linterna, dentro de esa
  Bolsa, efectiva Equipada. Los nombres duplicados no mezclan relaciones.
- id-00014 a id-00019: raíces adicionales y los tres estados.
- id-00020 a id-00025: padre ausente, ciclo de dos, hijo de ciclo, autociclo
  y padre que no es contenedor. Ninguno debe dibujarse ni repararse.
- id-00026 a id-00030: heredado sin contrato, esquema futuro, cantidad de tipo
  string, tipo desconocido y relación de contención ausente. Se ignoran sin borrar.

### Validaciones concretas en FGU

1. Confirmar 19 filas, ausencia de Coche/Casa ficticios y los 11 avisos del pie.
2. Revisar las ubicaciones inmediatas: Bolsa muestra Mochila; Botiquín y Venda
   muestran Bolsa; Documento profundo muestra Caja interior. Las raíces muestran `-`.
3. Comprobar los estados efectivos anteriores; pulsar o usar Ctrl sobre Estado
   no debe cambiar icono, tooltip ni campo carried. Cantidades sólo de lectura.
4. Buscar `Botiquín`: aparecen Mochila, Bolsa y Botiquín, todos los contenidos
   con una sola indentación. Buscar `Bolsa`: ambas ramas homónimas conservan
   sus propios descendientes y estados. Vaciar la búsqueda recupera las 19 filas.
5. Arrastrar el scrollbar y usar la rueda: la última fila `Objeto de prueba 19`
   debe verse completa, incluido Ver, con sus 2 px de separación de la barra.
6. Cambiar filtros: Todo y Personaje muestran datos reales; los otros tres
   muestran el aviso pendiente. Ningún filtro muestra la muestra antigua.
7. Revisar CAR `—` y CARGA `Pendiente`, sin relleno o valores simulados.
8. Cerrar y abrir la ficha. El subárbol `inventorylist` del fixture debe conservar
   todos sus registros y valores. Si se compara mediante exportación nativa,
   comparar inventario y propiedades: otros gestores ya existentes de la ficha
   pueden inicializar sus propios campos ajenos a EQUIPO.
9. En esta campaña desechable, cambiar carried de Mochila mediante una herramienta
   de edición de datos autorizada por el DJ o reimportar una copia modificada del
   fixture: se actualizan todos sus descendientes efectivos sin escribir su carried.
10. Probar también una ficha vacía, una con sólo registros nativos y un cliente
    jugador propietario: no migrar, crear ni modificar objetos; no mostrar errores.

## Pruebas y límites del entorno de desarrollo

Se añade `utility/tests/inventory_read_test.lua`, aislado de la extensión,
con DB doble en memoria cuyos mutadores fallan. Cubre contrato y tipos,
herencia, nombres duplicados, cantidad, cambios externos, ausencia de cálculo
CAR, referencias inválidas, ciclos, 128 niveles y cero escrituras.

Desde `character-sheet`, en un entorno con Lua 5.3/5.4:

    lua utility/tests/inventory_read_test.lua

No ejecutarlo como script global de una campaña ni incluirlo en extension.xml.

En este entorno se verificaron estáticamente etiquetas XML, referencias,
contratos de los fixtures, ausencia de mutadores DB del lector, aislamiento
de muestras y dimensiones de todos los controles. No están disponibles Lua,
luac ni Fantasy Grounds; la suite Lua y las pruebas dentro del cliente quedan
pendientes de ejecución. No se instalaron dependencias.

Limitaciones deliberadas: schema 1 y siete tipos actuales; contratos incompletos
no visibles; ramas inválidas omitidas con avisos; sin migración, edición,
creación, apertura, transferencias, apilamiento, inventarios de estructuras,
Riqueza funcional ni cálculo de carga. La búsqueda mantiene el comportamiento
actual de `string.lower` y no incorpora normalización Unicode completa.
