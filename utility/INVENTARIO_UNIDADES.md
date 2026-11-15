# Inventario: cantidades, pilas, traslados y CAR

## Diagnóstico previo

Existían lectura validada del contrato APTUS, copia independiente desde plantilla
(con `template_id`/versión y referencias de módulo), edición de propiedades y
borrado recursivo confirmado. La creación siempre fijaba cantidad 1. No existían
fusión, reparto, cambio de cantidades, transferencias ni CAR real: el lector
devolvía un guion. Los mecanismos genéricos de CoreRPG no conocen el contrato
APTUS ni los enlaces de contención mediante identificadores de nodo.

## Gestor común

Las operaciones se concentran en `scripts/manager_aptus_inventory.lua`, sin reglas
por tipo `ammunition`. Sirven para cualquier instancia APTUS compatible:

- `createFromTemplate(personaje, plantilla, cantidad=1, contenedor=nil)`: añade
  unidades, completa pilas compatibles y reparte el sobrante según `max_stack`.
- `setQuantity(instancia, cantidad)`: cantidad absoluta de ESA pila; conserva
  primero la pila origen hasta su máximo y reparte el sobrante. Las demás pilas
  conservan sus unidades previas. No significa establecer el total del mismo tipo.
- `mergeStacks(instancia)`: distribuye sus unidades entre pilas compatibles del
  mismo contexto; conserva el sobrante en el origen o lo elimina si queda vacío.
- `removeUnits(instancia, cantidad)`: resta unidades; no admite valores negativos,
  fracciones ni más unidades de las disponibles. No deja nodos de cantidad cero.
- `transfer(instancia, personajeDestino, cantidad=total, contenedorDestino=nil)`:
  traslado completo o parcial, con reparto/fusión en destino y descuento en origen.
- `getStackLoad(instancia)`: lectura de `ceil(count / properties.load_every) *
  properties.load_value`. Sin campos reales válidos devuelve nil; EQUIPO muestra
  un guion. No escribe datos ni agrega primero todas las unidades del mismo tipo.

Las operaciones devuelven resultado, error y, para reparto, las pilas destino.
Los objetos no apilables no se fusionan ni se dividen por `max_stack`: conservan
su comportamiento de una fila con cantidad múltiple. Un contenedor conserva
cantidad 1 y no se utiliza para representar cajas de munición.

### Compatibilidad y permisos

La firma compara todos los datos de la instancia salvo cantidad, contenedor
inmediato y candado de interfaz. Por tanto incluye identidad/versión de plantilla,
nombre, Estado almacenado, propiedades particulares, cualidades, perfiles y
referencias. Las pilas destino deben estar en el mismo contenedor inmediato.
Coincidir en nombre, imagen o tipo nunca es suficiente. Pilas personalizadas,
versiones distintas o Estados almacenados distintos permanecen separadas.

Se validan permisos de origen/destino, nodos vivos, referencias de contención y
ciclos antes de modificar. Un movimiento completo dentro del mismo inventario
conserva el identificador si la pila no se consume por fusión. Las transferencias
entre personajes crean nuevos nodos nativos, preservando identidad y propiedades.
No se introducen UUID ni se cambia el esquema de instancias.

### Recuperación y límites

Se preparan y verifican primero las copias, después se actualizan las cantidades y
al final se retira el único origen vacío. Ante un fallo se intenta restaurar las
cantidades aplicadas y retirar las copias nuevas, verificando el resultado. FGU no
ofrece aquí una transacción DB: si también falla la recuperación, se informa de
ello explícitamente para revisión del director, sin prometer atomicidad nativa.

No se migran o reparten registros al abrir una ficha. Una pila anterior que supere
su máximo puede normalizarse mediante una operación explícita. El editor impide
reducir `max_stack` por debajo de la cantidad actual: primero hay que ajustar las
unidades. Las cantidades y límites de las operaciones deben ser enteros dentro
del rango representable con exactitud (hasta 2^53−1).

Los contenedores con contenido pueden moverse dentro del mismo personaje,
conservando enlaces y descendientes. Se rechaza moverlos a otro personaje: exige
copiar/remapear y retirar un árbol completo con garantías distintas. Las unidades
sueltas, objetos sin contenido y contenedores vacíos sí pueden transferirse.

## Interfaz mínima

- El botón + conserva el selector de plantillas; después solicita las unidades a
  añadir. Cancelar no crea nada. Arrastrar una plantilla añade una unidad.
- Clic derecho en una fila: Cambiar cantidad, Fusionar pilas compatibles o Mover
  a raíz. Disminuir la cantidad elimina sólo las unidades indicadas por la diferencia.
  Elegir 0 abre la confirmación de eliminación existente, también para contenedores.
- Arrastrar el nombre de una instancia a otro inventario mueve todas sus unidades.
  Soltar sobre un contenedor las ubica en él; soltar en el fondo o en una fila no
  contenedora usa la raíz. Se respetan los permisos de ambos personajes.
- Las transferencias parciales están disponibles en el gestor y en las pruebas;
  el arrastre de la interfaz mueve la pila completa.
- CAR se muestra por fila. El panel total y la reducción de contenedores se
  describen en `INVENTARIO_CARGA_CONTENEDORES.md`. La capacidad reductora no limita
  el almacenamiento; no se introducen umbrales de carga del personaje.

## Pruebas funcionales reales preparadas

```text
lua utility/tests/inventory_create_test.lua
lua utility/tests/inventory_read_test.lua
```

La primera suite utiliza el gestor de producción sobre su doble DB existente e
incluye `inventory_units_test.lua`. No replica el algoritmo ni se limita a calcular
resultados por separado. Cubre:

- 120 unidades → 50+50+20; 40 cartuchos → 25+15; 10 granadas → 6+4.
- Pila de 30 más alta de 40 → 50+20; fusión de dos pilas incompletas.
- Conservación de unidades, límites, cantidades inválidas, tipos/procedencias,
  modificaciones particulares y Estados diferentes.
- CAR real del lector para todos los ejemplos de munición y dos pilas separadas
  de una unidad que deben sumar 2 CAR, no 1 CAR global.
- Traslados completos/parciales, raíz/contenedores, identidad de nodo local,
  contenedores anidados, ciclos y permisos.
- No apilables, borrado de unidades, referencias nativas copiadas y plantilla intacta.
- Fallos simulados al escribir cantidades y al retirar el origen: recuperación de
  cantidades y retirada de las copias nuevas.

No se ejecutaron las suites Lua en este entorno: no hay intérprete y el usuario
indicó expresamente que no se instalara. Las comprobaciones Node de estructura,
balance léxico, XML y conexiones están disponibles en:

```text
node utility/tests/inventory_units_static_test.js
node utility/tests/inventory_instance_static_test.js
node utility/tests/ammunition_static_test.js
node utility/tests/equipment_type_filters_static_test.js
node utility/tests/profile_editor_static_test.js
node utility/tests/initial_ammunition_module_test.js
```

## Validación manual en FGU

Usar una campaña de prueba y cargar el módulo de municiones actualizado.

1. En inventarios vacíos, añadir desde + las cantidades 120 de 9×19 mm, 40 de
   Calibre 12 y 10 de Granada 40 mm. Verificar filas, sumas y los límites indicados.
2. En otro inventario vacío, añadir 30 de 9×19 mm y luego 40. Verificar 50+20 y
   confirmar que una munición diferente con la misma imagen no se fusiona.
3. Con dos pilas 50+20, reducir la primera a 30. Fusionar la segunda mediante su
   menú: debe quedar una pila de 50. Verificar también eliminación parcial y
   cantidad 0, cancelando y aceptando la confirmación existente.
4. Para cada cantidad solicitada en los ejemplos, comprobar CAR real de la fila:
   granadas 1/2/3 → 1 CAR, 4/5/6 → 2 CAR. Crear pilas en contenedores distintos
   para verificar que el redondeo no se hace globalmente por tipo.
5. Arrastrar una pila de 40 a un personaje con una pila compatible de 30: destino
   50+20, origen vacío. Probar un cliente sin permiso y comprobar rechazo sin cambios.
6. Arrastrar una pila entre dos contenedores del mismo personaje, después a raíz;
   comprobar Ubicación, Estado heredado y conservación de cantidades. Probar un
   movimiento cíclico y el traslado de un contenedor ocupado a otro personaje:
   ambos deben rechazarse sin cambios.
7. Personalizar una pila y añadir más unidades desde la plantilla. No debe fusionarse
   con la personalizada. Repetir con Estados/versiones distintos y con no apilables.
8. Ejecutar /reload y reabrir: verificar cantidades, contención, CAR y referencias
   de módulo. Abrir/desbloquear/descartar un perfil de combate no debe alterar unidades.
9. Verificar scrollbar, menú contextual, drag de nombres y ventanas de instancia
   abiertas durante una fusión. Una pila consumida debe cerrar su ficha; un borrador
   afectado por cambios externos debe conservar la comprobación de revisión existente.

No hay consumo por ataques, recargas, cargadores, depósitos ni cambios en APTUS Dice.
