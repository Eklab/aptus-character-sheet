# EQUIPO — ajustes de skin y requisitos generales

## Cambios

- Se conserva la composición 650 × 433, imagen, cuatro pestañas y pie fijo.
- No aparece texto informativo inferior. El control técnico de estado permanece
  invisible para conservar las llamadas existentes; los errores de Guardar se
  comunican al DJ mediante mensaje privado. No se añade texto sustitutorio.
- Descartar conserva el callback `reload`, sin modificar su comportamiento.
- Los botones de añadir reutilizan `aptus_add`, registrado en
  `graphics/graphics_aptus.xml` con archivo `graphics/icons/aptus_add.png`
  (25 × 25). Los botones principales tienen área de interacción 32 × 28.
- Combate se divide en Protecciones, Requisitos y Perfiles. Los dos separadores
  usan el recurso nativo `separatorline`, sin crear marcos ni PNG nuevos.
- Contenedor y Carga agrupa las propiedades por pares. Máximo por pila y Capacidad
  se ponen en solo lectura cuando sus casillas están desmarcadas. Cambiar este
  estado visual no escribe ni borra valores. Se mantienen las reglas anteriores
  del guardado, incluido el tratamiento existente de contenedores No apilables.
- Las filas plegadas conservan nombre, Configurar y Eliminar con altura compacta.

## Modelo y compatibilidad

Nuevas propiedades generales:

```text
properties.required_fue       number, entero >= 0, predeterminado 0
properties.required_agi       number, entero >= 0, predeterminado 0
```

Se integran en el registro común de campos: borrador, validación, persistencia,
comparación, token de edición, restauración y duplicación. Son propiedades
copiables de la plantilla. No se modifica schema_version ni se ejecuta migración.
Los campos ausentes representan 0; guardar sin cambios no los materializa ni
incrementa versión. Guardar otras propiedades con estos campos aún ausentes
también conserva una verificación coherente entre candidato y DB.

Los perfiles nuevos ya no crean requisitos. Sus controles y capturas se retiran,
pero los valores antiguos en `properties.profiles.<clave>.required_fue/required_agi`
se preservan en las colecciones tipadas y al guardar/duplicar. No tienen efecto
funcional ni se escoge uno automáticamente como requisito del objeto.

Si existen requisitos antiguos no nulos, el bloque Requisitos muestra
«Requisitos anteriores: ver detalle», cuyo tooltip enumera nombre y valores de
cada perfil. Esto permite detectar también perfiles con requisitos diferentes.
El DJ debe decidir y editar los generales: conservar los antiguos como referencia
evita pérdidas y no necesita una migración compleja. El aviso no aparece para
campos antiguos ausentes o todos a cero. No se borran datos históricos después
de establecer los requisitos generales.

Queda documentada para Combate futura la penalización FUE de −1 al ataque por
punto faltante; AGI sigue pendiente de definición. Aquí NO se calcula ni aplica
ninguna penalización, bloqueo de equipamiento ni cambio de estadísticas.

## Espacio disponible

El panel derecho conserva el tamaño aprobado. La lista de perfiles dispone de
76 píxeles visibles después de los tres bloques; los editores desplegados
requieren desplazamiento. Se han recortado los huecos finales de filas y retirado
las dos filas antiguas de requisitos. No se crean ventanas independientes.

Si la interacción en FGU resulta incómoda, las alternativas futuras son una
subpágina temporal de configuración o un diálogo que edite el mismo borrador.
Ambas necesitarían una revisión de navegación; no se implementan en esta ronda.

## Pruebas

Comprobaciones estáticas: balance XML y bloques Lua, controles de los campos
generales presentes, ausencia de requisitos en editores de perfiles, icono
resuelto, coordenadas dentro de 650 × 433 y mecanismos de integridad conservados.

La suite aislada `utility/tests/equipment_save_test.lua` se amplía con requisitos
generales, campos ausentes, valores inválidos y conservación de dos perfiles con
requisitos diferentes. No está registrada en la extensión. No se ha ejecutado:
el entorno no dispone de Lua/luac ni FGU.

### Circuito pendiente en FGU

1. Cargar la extensión cuando el DJ lo decida. Abrir EQUIPO: cuatro pestañas,
   sin texto inferior y con Descartar. No se ha reiniciado/recargado FGU aquí.
2. Revisar alineación, separadores y botones aptus_add en listas y editores.
3. En Combate, introducir FUE mínima 3 y AGI mínima 2 y varios cambios de perfiles.
   Guardar: un incremento; reabrir: valores conservados. Guardar sin editar:
   versión igual. Duplicar: nuevo ID, versión 1, requisitos y perfiles copiados.
4. Probar requisitos negativos/fraccionarios: rechazo sin incremento. Probar cero.
5. Cambiar requisitos y Descartar, y repetir cerrando sin guardar: valores
   anteriores conservados. Confirmar que no hay requisitos en perfiles nuevos.
6. Con una plantilla antigua de prueba que tenga requisitos 3 y 5 en perfiles
   distintos, comprobar aviso y tooltip. Los generales no se eligen a partir de
   ellos. Guardar cambios no elimina los valores históricos. Editar generales
   manualmente y comprobar que ambos requisitos antiguos siguen conservados.
7. Desmarcar Apilable y Contenedor: campos dependientes no editables, valores aún
   visibles. Alternar casillas sin guardar no cambia DB. Volver a activar permite
   editar. Descartar recupera todos los valores persistidos.
8. Añadir/configurar/eliminar perfiles y asociaciones de cualidades; recorrer el
   scroll y comprobar filas plegadas compactas y estado del borrador.
9. Provocar un rechazo de validación y comprobar aviso privado al DJ, sin texto
   informativo inferior. Verificar también módulos de solo lectura y cliente.
10. Comprobar atributos, DEF/PRO y tiradas existentes: ninguna automatización nueva.
