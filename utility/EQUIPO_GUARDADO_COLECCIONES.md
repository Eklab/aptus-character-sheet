# Corrección del guardado de colecciones

## Diagnóstico y límite de la evidencia

El verificador anterior comparaba firmas que representaban todos los números con
`tostring`. En Lua con enteros/flotantes diferenciados, `tostring(0)` y
`tostring(0.0)` producen textos distintos aunque `0 == 0.0`. Un perfil recién
creado conserva valores enteros por defecto; el recorrido de DB puede devolver
los mismos valores como flotantes. Eso convierte una escritura correcta en un
fallo de verificación. Los escalares ya procedentes de DB no necesariamente
reproducen esa diferencia, de ahí la relevancia de las colecciones nuevas.

Rutas susceptibles en el ejemplo: `properties.profiles.<clave>.attack_modifier`,
`required_fue`, `required_agi`, y los demás campos numéricos del perfil. No se dispone
del registro ni de una traza del cliente FGU para afirmar cuál fue su primera
discrepancia concreta. El fallo del codificador sí está identificado en el código;
la confirmación de este recorrido en esa sesión queda pendiente en FGU.

La ordenación ya era determinista y se conservan las claves internas: no se
renumeran perfiles/cualidades ni se usan sus nombres como identidad.

## Corrección

- Firmas numéricas canónicas round-trip con 17 cifras significativas; cero
  entero/flotante comparten representación. Sin tolerancias ni redondeo funcional.
- Verificación estructural por tipos, claves y valores antes de incrementar versión.
  `10`, `"10"` y `true` no son intercambiables. Un valor o tipo DB incorrecto sigue
  rechazándose. Los enteros que no sean representables como double no se colapsan.
- Primera discrepancia registrada en `Debug.console`, con fase, registro, ruta
  exacta, valor esperado y recuperado. El mensaje habitual de la ficha es breve.
- Si falla, se restaura el snapshot tipado completo de propiedades y la versión
  anterior. Se vuelve a leer y comparar; no se anuncia restauración verificada
  únicamente porque las llamadas DB no hayan lanzado un error.
- Si falla también la restauración se advierte explícitamente. No es recuperación
  resistente a cierres del proceso ni puede garantizar escrituras si DB las rechaza.

No cambian el borrador, permisos, esquema, datos de juego ni mecanismos de inventario.
La firma se calcula en memoria; no hay datos persistidos que migrar.

## Pruebas automatizadas preparadas

`utility/tests/equipment_save_test.lua` ejecuta el gestor real en un entorno Lua
aislado con DB simulada en memoria que devuelve números flotantes. No se incluye
en la extensión ni debe ejecutarse dentro de una campaña.

Desde la raíz de Character Sheet, con Lua 5.3/5.4 disponible:

```sh
lua utility/tests/equipment_save_test.lua
```

Cubre los diez escenarios solicitados, guardados sin cambios, números enteros/
flotantes, tipos incorrectos, escrituras corruptas, versión corrupta, restauración
corrupta y tokens antiguos. No escribe archivos ni necesita dependencias FGU.

En el entorno de desarrollo actual no hay intérprete Lua: suite preparada pero
NO ejecutada. Comprobado estáticamente el balance léxico de ambos Lua y la presencia
de las comprobaciones de integridad, orden de versión y diagnósticos.

## Circuito manual pendiente en FGU

Cargar esta versión cuando el DJ lo decida; no se ha recargado ni reiniciado FGU.
Usar plantillas de prueba y anotar su ID y versión antes de cada operación.

1. Generales sin colecciones: cambiar varios campos y guardar; incremento único.
2. Añadir una cualidad general, guardar y reabrir: mismo quality_id, nombre resuelto desde el catálogo.
3. Añadir un perfil sin cualidades y guardar: conserva todos sus campos.
4. Añadir una referencia del catálogo al perfil: persistencia correcta.
5. Reproducir Pistola2: Disparo/Puntería, daño d6, crítico d6, alcance 25,
   munición activada/máximo 10, referencias del catálogo Cargador y Ocultable. Guardar y
   reabrir: conserva todo y aumenta una sola versión.
6. Añadir un segundo perfil con otras cualidades: datos y claves independientes.
7. Editar un perfil guardado: persiste e incrementa una vez. Guardar otra vez
   sin cambiar nada: no incrementa.
8. Eliminar un perfil, guardar y reabrir: desaparece él y sus cualidades, sin
   afectar al otro. Eliminar todos: plantilla válida con colección vacía.
9. Editar colecciones y Descartar/Releer; repetir cerrando sin guardar: recupera
   los datos anteriores y conserva versión. Probar también añadir/eliminar una
   entrada nueva antes de guardar: no incrementar si el resultado es idéntico.
10. Duplicar una plantilla con perfiles y cualidades: propiedades iguales, ID
    nuevo y versión 1; editar la copia no cambia la original.

Si vuelve a fallar, copiar las entradas `APTUS EQUIPO` de la consola. Una ruta que
termine en `.kind` señala diferencia de tipo DB; `.value` señala diferencia de valor.
Comprobar también la fase de restauración, la versión anterior y el resultado de
reabrir la plantilla. Un fallo no debe presentarse como guardado correcto ni dejar
una versión nueva cuando la restauración se haya verificado.
