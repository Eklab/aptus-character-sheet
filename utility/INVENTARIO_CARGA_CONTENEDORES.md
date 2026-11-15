# CAR de contenedores y total del inventario

Se reutilizan `properties.load_every`, `properties.load_value` y
`properties.capacity`, sin campos nuevos persistidos ni cambios de esquema.
`getStackLoad()` conserva la fórmula existente por pila:

```text
CAR propia = ceil(count / load_every) * load_value
```

Una vez validada la jerarquía, `getCharacterInventory()` calcula las cargas de
abajo arriba mediante una cola, sin recursión ni límite artificial de profundidad.
Cada padre suma la CAR íntegra de sus hijos inmediatos, sin aplicar las reducciones interiores:

```text
CAR íntegra = CAR propia + suma(CAR íntegra de cada hijo)
CAR contenido = suma(CAR íntegra de cada hijo)
contenedor interior: CAR efectiva = CAR íntegra
contenedor raíz con contenido <= capacity: CAR efectiva = CAR propia
contenedor raíz con contenido > capacity: CAR efectiva = CAR íntegra
CAR total = suma(CAR efectiva de las raíces con carried 1 o 2)
```

La reducción se pierde completamente al superar la capacidad y se recupera al
volver a ella. La capacidad no bloquea movimientos ni almacenamiento. La CAR
propia no forma parte del numerador del indicador del contenedor. No se agregan
primero las unidades de un mismo tipo ni se suman de nuevo los descendientes.
Las raíces con carried 0 (Sin equipar) no aportan carga al personaje. Todos los
contenidos siguen entrando en la CAR íntegra de su contenedor, sea cual sea
su carried almacenado. Ver `INVENTARIO_ESTADO.md`.

Los resultados `own_load`, `gross_load`, `content_load`, `capacity_load`, `reduction_active`, `effective_load`,
`overloaded` y `total_load` viven exclusivamente en el snapshot de lectura.
No hay migraciones ni escrituras al abrir, filtrar o calcular. Si faltan datos
necesarios o existen registros rechazados, el total se muestra incompleto, no
como cero. Una rama con carga desconocida no obtiene una reducción supuesta.

## Presentación

La columna CAR muestra la CAR efectiva de cada objeto. Para obtener el total no
se suman todas las filas: los contenedores ya incluyen el efecto de sus contenidos.
El nombre muestra `Mochila (contenido/capacidad)`. El indicador usa un widget
de texto separado, dentro del control existente: sólo él es rojo al sobrepasar
capacidad; el nombre conserva la fuente y color normales. Se acota el ancho de
ambos widgets y el tooltip conserva nombre, indicador, CAR propia y efectiva.
Un valor desconocido aparece como guion en el indicador.

El panel lateral conserva sus recursos y muestra carga efectiva / capacidad.
`getLoadCapacity()` lee `attributes.fue.effective` y calcula `2 + FUE * 2` mediante
`getBaseLoadCapacity()`, sin persistir la capacidad. El primero es el punto de extensión
para futuros modificadores, que todavía no existen en este cálculo.

`getLoadStatus()` reutiliza el snapshot del inventario y clasifica:

- LIGERO (verde): 0 % <= carga < 50 %, sin penalizaciones.
- CARGADO (verde): 50 % <= carga < 100 %, sin penalizaciones.
- SOBRECARGADO (amarillo): 100 % <= carga < 150 %, AGI -1d.
- LASTRADO (naranja): 150 % <= carga < 200 %, AGI -2d / MOV 1/2.
- INMOVILIZADO (rojo): carga >= 200 %, AGI -2d / MOV 0.

Las consecuencias se muestran encima de la silueta en dos controles centrados
de 70×24 px, en (554,111) y (554,137), con la misma fuente local regular de 19 px
y el color del estado. LIGERO y CARGADO dejan ambas líneas vacías.
`tLoadConsequences` en la vista selecciona textos por el estado ya calculado y
alimenta también el tooltip, sin nuevos cálculos de porcentajes.

Las consecuencias son informativas; no se aplican al motor de reglas. Los límites
se comparan sin redondear. Un único resultado determina estado, color y PNG.

La barra nativa ocupa proporcionalmente sus 180 px y se satura al 200 %. El texto
de estado dispone de dos líneas dentro del espacio existente. El tooltip recuerda
las reglas, sin aplicar cambios a AGI, Defensa ni Movimiento. Si falta FUE efectiva
o la carga es incompleta, se muestra «Incompleta» y no se inventa un estado.
La carga total es del inventario completo y no cambia al buscar u ocultar filas.
Los handlers DB existentes actualizan la lectura tras cantidades, altas, bajas,
movimientos y modificaciones de propiedades, incluyendo capacidad y valores CAR. También se observan alta, cambio y eliminación
de `attributes.fue.effective` y `gender`; los handlers se retiran al cerrar la ventana.

Identidad usa un `stringfield` libre `gender` en el nodo del personaje: no hay
enumeración de sexo. Se reconoce «Femenino» sin distinguir mayúsculas ni espacios
exteriores; «Masculino», ausencia y otros valores usan hombre. Las skins generales
usan `aptus.visual.skin` según tipo de personaje, no sexo, y no se modifican.

Los diez PNG de Carga miden 70×110 px. Se registran en el XML gráfico de EQUIPO
respetando `hombre` y `Mujer`. El área existente de los textos laterales abarca
x=540–627; la barra se sitúa en x=543, ancho 7, y=100–280, y la silueta nativa
en x=554–624, y=165–275. No se escala el PNG ni se cambian columnas. Una marca
nativa beige de 11×2 en (541,189) señala el 100 %. Si los datos de carga o FUE
son incompletos se oculta la silueta para no atribuir un estado inventado.

No se modifican cantidad por clic, diálogo de cantidades, apilamiento, selectores
de Ubicación, recursos LANE, ventanas de objetos ni otras pestañas.

## Pruebas

```text
node utility/tests/inventory_container_load_static_test.js
node utility/tests/inventory_instance_static_test.js
node utility/tests/inventory_units_static_test.js
lua utility/tests/inventory_create_test.lua
lua utility/tests/inventory_read_test.lua
```

Los tres comandos Node comprueban estructura y conexiones. La suite Lua de
creación incluye `inventory_container_load_test.lua`, que llama al gestor real
sobre el doble DB existente. Cubre vacío, igualdad, sobrecarga, recuperación,
unidades/pilas, tres niveles sin encadenamiento, FUE 0–4, límites exactos y fraccionarios de los cinco estados, selección masculina/femenina,
sexo ausente o desconocido, escala 0–200 %,
cambio de FUE, modificaciones de cantidad, traslados, total,
datos incompletos, ciclos y ausencia de escrituras durante la lectura.

No se ejecutaron las pruebas Lua: el entorno no dispone de intérprete y se mantiene
la instrucción del usuario de no instalar herramientas. Tampoco se ejecuta FGU.

## Validación manual en Fantasy Grounds Unity

1. En campaña de prueba, crear Mochila con CAR propia 2 (`load_every=1`,
   `load_value=2`), capacidad 5, `is_container=1` y cantidad 1.
2. Vacía: comprobar `Mochila (0/5)`, CAR de fila 2 y total 2.
3. Introducir objetos de CAR unitaria 1. Probar contenido 1, 4 y 5: indicador
   normal y CAR efectiva 2. Con contenido 6 y 7: sólo el indicador rojo y CAR 8/9.
4. Retirar unidades hasta contenido 5 y luego 0: comprobar recuperación automática
   del color y de la reducción, sin cerrar la ficha ni ventanas emergentes nuevas.
5. Probar municiones por pila, cantidades y máximos actuales: tres pilas de
   9×19 mm (50+50+20) aportan 3 CAR de contenido, no 120 unidades al indicador.
6. Añadir Bolsa de CAR propia 1 y capacidad 3 dentro de Mochila. Introducir
   2 CAR en Bolsa: ésta aporta 3 a Mochila (1 propia + 2 de contenido). Probar contenido 4 y 5 en Bolsa:
   aporta 5/6 a Mochila, que pasa respectivamente a CAR efectiva 2/8.
7. Mover la Bolsa a raíz y devolverla: verificar todos los indicadores y que
   el total suma sólo raíces, sin duplicar contenidos. Repetir con varios niveles.
8. Buscar un objeto y cambiar filtros: el total debe permanecer igual. Probar
   nombres largos y contenedores anidados: indicador y nombre no invaden Cantidad.
9. Editar capacidad y valores CAR con el editor existente; comprobar actualización
   al guardar. Comprobar por separado cantidad por clic y Ubicación sin regresiones.
10. Ejecutar /reload: cargas e indicadores deben recuperarse de las propiedades
    persistidas, sin guardar resultados calculados ni alterar relaciones o cantidades.

11. Cambiar FUE efectiva entre 0, 1, 2, 3 y 4: capacidades 2, 4, 6, 8 y 10.
    Con FUE 2 comprobar cargas 0 y 2 LIGERO; 3 y 5 CARGADO; 6 y 8
    SOBRECARGADO; 9 y 11 LASTRADO; 12 y 13 INMOVILIZADO. La barra
    tiene alturas 0/45/90/135/180 px para cargas 0/3/6/9/12.
12. Tres niveles: Mochila (propia 2, Almacenaje 5), Bolsa (propia 1), otra Bolsa
    (propia 1) y objeto CAR 3: contenido exterior 5, total 2. Cambiar objeto a
    CAR 4: contenido exterior 6, total 8, incluso si las bolsas interiores tienen
    Almacenaje suficiente. No se encadenan reducciones.
13. Comprobar ajuste de estado en el panel, sin recortes, y que AGI, Defensa y
    Movimiento no cambian al sobrecargar. Las pruebas estáticas no validan el renderizado.

## Resultado de las comprobaciones de esta revisión

Pasaron las suites Node de carga, instancias, unidades y Sexo
(`node utility/tests/identity_gender_static_test.js`).
No se han ejecutado Lua ni FGU; las verificaciones Node son estáticas y no
acreditan la ejecución ni la representación visual del motor.

14. Cambiar Sexo en Identidad a Masculino, Femenino, vacío y un valor desconocido:
    comprobar las cinco imágenes, actualización inmediata, proporciones y fallback.
    Verificar que la marca del 100 % coincide con media barra y que no se solapan
    barra, silueta, cifras ni estados. Probar /reload y cambios de FUE con EQUIPO cerrado.

15. Comprobar que SOBRECARGADO muestra únicamente «AGI -1d», LASTRADO
    muestra «AGI -2d» y «MOV 1/2», e INMOVILIZADO «AGI -2d» y «MOV 0».
    Volver a LIGERO/CARGADO: las dos líneas deben desaparecer inmediatamente.
    Revisar contraste LANE, separación uniforme, ausencia de recortes y que las
    siluetas conservan el tamaño nativo 70×110 y el borde inferior en y=275.

## Legibilidad del indicador

Fuentes locales de CARGA en Roboto Condensed Regular:
- `aptus_load_penalty`: 19 px, controles (554,111,70,24) y (554,137,70,24).
- `aptus_load_value`: 24 px, control (547,280,74,30).
- `aptus_load_state`: 14 px sin negrita, control (536,310,95,32).

Se conservan los centros horizontales y colores. Las penalizaciones están
separadas 26 px, dejando 2 px entre controles y 4 px hasta la silueta.
El valor numérico queda 5 px por debajo de la silueta y termina en y=310,
donde comienza el estado. La silueta, barra, columnas, textos y reglas no
se modifican. Tampoco se cambian fuentes compartidas ni scripts Lua.

La prueba estática lee avances hmtx/cmap y altura hhea del TTF:

| Texto | Tamaño | Ancho calculado | Ancho disponible |
|---|---:|---:|---:|
| AGI -2d | 19 | 54,81 | 70 |
| MOV 1/2 | 19 | 66,59 | 70 |
| 22 / 6 | 24 | 55,46 | 74 |
| SOBRECARGADO | 14 | 93,90 | 95 |
| INMOVILIZADO | 14 | 84,47 | 95 |

Las alturas tipográficas son 22,27 px para 19 px, 28,13 px para 24 px y
16,41 px para 14 px. Pasan las cuatro suites estáticas de carga, instancias,
unidades y Sexo. Las métricas no simulan el rasterizador FGU: comprobar
visualmente ambos estados largos completos, el valor 22 / 6, penalizadores,
colores y separación vertical en el tema LANE.
