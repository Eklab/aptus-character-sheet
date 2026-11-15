# Ubicación desde la fila de EQUIPO

## Implementación

La relación continúa en `aptus.container`: ID de nodo del contenedor inmediato,
del mismo `inventorylist`. Ausente o vacío equivale a raíz. La visualización sigue
mostrando el nombre del contenedor inmediato o `-` en raíz.

Texto y selector gráfico de Ubicación conservan bounds, fuente e icono; ahora
responden al clic izquierdo. Se abre la variante visual local
`aptus_inventory_location`, copiada de `select_dialog`, y se invoca su método
nativo `requestSelectionByData()`. DialogManager abre siempre `select_dialog`,
por lo que esta sustitución de clase permite personalizar sólo Ubicación. Se
conservan el script nativo, opciones, referencias, selección y callback. No se
incrusta un combobox en las filas ni se implementa otro protocolo de selección.

`getLocationOptions()` consulta `getCharacterInventory()` y el validador de destino
que ya usa `transfer()`. Ofrece Raíz y los contenedores válidos accesibles del
mismo personaje. Excluye el objeto y sus descendientes; mantiene la validación
`properties.is_container=1`, referencias, ciclos y permisos. Los nombres anidados
incluyen su ruta (Mochila / Bolsa); las coincidencias idénticas se numeran. Las
referencias nativas del selector contienen las rutas, nunca se resuelve por nombre.

`requestLocation()` comprueba de nuevo identidad/revisión del origen y pertenencia
del destino al mismo personaje antes de llamar a `transfer()`. El gestor existente
conserva cantidades/propiedades/Estado almacenado y fusiona sólo pilas compatibles
en el mismo contenedor. Al entrar se establece carried 0; al salir a raíz se
establece carried 1 (Transportado). Los contenidos siempre muestran un guion,
incluso si conservan un carried antiguo distinto de cero. Cambiar entre
contenedores conserva carried 0. Volver a elegir el destino actual no escribe
ni fusiona: para fusionar continúa existiendo la operación explícita.
Mover un contenedor conserva su árbol. No se modifica la operación de traslado.

Los handlers DB existentes actualizan las pilas y ubicaciones; el callback solicita
un refresco final con la función capturada del padre. No hay writes en la generación
de opciones ni en los controles de la fila. Cancelar no mueve nada. Un selector
obsoleto rechaza la operación si el origen cambió; el destino se revalida al confirmar.

CARGA se actualiza conforme al Estado: sólo cuentan raíces con carried 1 o 2.
No cambian los límites de capacidad ni el diálogo de cantidades. Este
selector no ofrece otros personajes, localizaciones o vehículos. No se insertan
datos de prueba automáticamente ni se modifica ninguna campaña desde herramientas.

## Pruebas

```text
node utility/tests/inventory_location_static_test.js
node utility/tests/inventory_instance_static_test.js
node utility/tests/inventory_units_static_test.js
```

Son comprobaciones estáticas de referencias, geometría, delegación y ausencia de
escrituras directas. No garantizan la interacción de FGU.

La suite funcional existente `lua utility/tests/inventory_create_test.lua` incluye
ahora opciones y callbacks reales de Ubicación a través de `inventory_units_test.lua`:
Mochila, pilas 50+50+20, entradas/salida, 120 unidades conservadas, exclusión de
sí mismo/descendientes, ciclos y rechazo de revisión obsoleta. No se ha ejecutado:
este entorno no tiene Lua y se respeta la indicación de no instalar herramientas.

## Escenario manual: Miguel García

Preparar en una campaña de prueba, mediante la interfaz existente:

1. Crear o abrir el personaje **Miguel García**.
2. Añadir una Mochila con `is_container=1`, cantidad 1 y no apilable.
3. Añadir un Machete. Dejar ambos en raíz.
4. Cargar el módulo de municiones y añadir 120 unidades de 9×19 mm desde +.
   Comprobar las tres pilas 50+50+20 en raíz antes de continuar.
5. Pulsar el texto o la flecha de Ubicación en la primera pila de 50. Seleccionar
   Mochila y aceptar. Debe mostrar «Mochila» y conservar cantidad 50.
6. Repetir con la segunda pila de 50. Deben quedar dos pilas de 50 en Mochila y
   una de 20 en raíz: ninguna puede superar 50.
7. Desde una pila de Mochila seleccionar Raíz. La pila de 20 debe completarse a
   50 y quedar una de 20 en raíz; la otra de 50 continúa en Mochila. Total: 120.
8. Cancelar una selección: no deben cambiar cantidades ni ubicaciones.
9. En Ubicación de Mochila, comprobar que no se ofrece ella misma. Añadir una
   Bolsa contenedora dentro de Mochila: tampoco debe ofrecerse como destino de ésta.
10. Mover un contenedor con contenido a otro contenedor válido: sus descendientes
    deben acompañarlo sin cambios de cantidad, conservando Ubicación inmediata.
11. Probar contenedores con nombres duplicados, búsqueda/filtros activos y scroll.
    Comprobar los nombres del menú, refresco inmediato y conservación de unidades.
12. Abrir el selector y cambiar el origen desde otra interfaz antes de confirmar:
    debe rechazar el selector obsoleto. Eliminar o cambiar permisos del destino
    antes de confirmar también debe rechazar el movimiento sin pérdida de objetos.
13. Ejecutar /reload: comprobar ubicaciones y cantidades persistidas. Verificar
    que no han cambiado el panel CARGA ni la ventana de cantidades.

## Apariencia LANE local

`campaign/inventory_location_aptus.xml` hereda el tamaño nativo 400×400,
los scrollbars, la barra de cierre y los botones de aceptar/cancelar. Reutiliza
`aptus_lane_aux_recordsheet` y `aptus_lane_aux_windowtitle`, altura de cabecera
37 px y offsets 30,0,30,0, como Modificar cantidad. El anclaje superior de
contenido pasa a 38 px para dejar espacio a la cabecera.

Se eliminan los frames groupbox heredados de descripción y lista: ambos
quedan sobre el fondo oscuro existente, sin añadir paneles que los oculten.
Las fuentes locales de EQUIPO son claras; las filas conservan enlaces y
casillas nativas. La opción seleccionada cambia su texto a blanco, manteniendo
el callback nativo, y las rutas completas se conservan en tooltips.

No se cambia select_dialog global ni Modificar cantidad. No se crean PNG,
frames o fuentes. Las tres suites estáticas documentadas pasan; la ejecución
Lua y FGU sigue pendiente. Validar visualmente marco/cabecera/cierre, ausencia
de blanco en ambos paneles, casillas y enlaces, selección exclusiva, rutas
anidadas largas con tooltip y scroll, aceptar/cancelar y persistencia tras reload.
