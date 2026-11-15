# Tipo de equipo Munición y descripción por perfil

Identificador: `ammunition`. Se registra al final del catálogo común mediante
`registerType`. Los filtros existentes lo obtienen automáticamente de `getTypes()`.
Se admite en la tabla de tipos del inventario usando el icono genérico existente
`aptus_utilidad_item`; no existe en esta entrega un PNG específico de munición.
Se conservan las propiedades comunes, cantidades, indicadores de apilamiento y
relaciones de contención existentes. No se añaden operaciones de apilamiento.

## Contrato opcional del perfil

- `properties.profiles.<perfil>.ammunition_template`: `windowreference` con clase
  `aptus_equipment` y ruta completa de la plantilla, incluido `@módulo` cuando proceda.
- `properties.profiles.<perfil>.ammunition_consumption`: número entero; inicial 1.
  Cuando `uses_ammunition=1`, debe ser positivo. La validación se realiza al guardar;
  las entradas inválidas no se corrigen ni se limitan silenciosamente.
- `uses_ammunition` y `ammunition_max` conservan su significado anterior.

No se cambia el esquema de instancias ni se crea un inventario separado. Los dos
campos se guardan por el serializador genérico de perfiles, que ya maneja
`windowreference`. La copia de propiedades de plantilla a instancia se mantiene.

## Edición

La configuración mide ahora 520 × 420 px para alojar la fila adicional. Tipo,
Consumo y Cargador sólo aparecen cuando Utiliza munición está activo. Ocultar no
borra valores. Elegir consulta sólo plantillas de tipo `ammunition`; Quitar elimina
la referencia del borrador. No se crean instancias ni se modifica la plantilla.
El callback comprueba que el formulario y el borrador sigan activos.

Una referencia inaccesible muestra «Munición no disponible» y conserva su ruta;
no se busca un reemplazo. Sin referencia se muestra «Sin asignar».

Los perfiles antiguos activos sin consumo se leen con 1 y los inactivos con 0
efectivo. No se materializa ningún campo al abrir o consultar. Una edición
explícita se guarda con el mecanismo principal de Guardar; Descartar conserva
su comportamiento anterior.

## Presentación

La tabla conserva encabezados y posiciones de sus columnas. Añade un pie opcional
de 16 px con «Munición: consumo/capacidad» y amplía fondo/CTA. El cuerpo conserva
su ajuste y su máximo de 64 px, de modo que las filas con pie alcanzan hasta 80 px.
Los tooltips incluyen también el nombre de la plantilla.
La consulta especializada existente añade el mismo texto a su segunda línea sin
cambiar el PNG ni su altura. Sin uso de munición, ese texto se omite.

## Comprobaciones

- `node utility/tests/ammunition_static_test.js`
- `node utility/tests/profile_editor_static_test.js`
- `node utility/tests/damage_types_static_test.js`
- `node utility/tests/inventory_instance_static_test.js`
- `node utility/tests/item_melee_consultation_static_test.js`
- `node utility/tests/equipment_type_filters_static_test.js`

Pruebas Lua preparadas: `utility/tests/ammunition_test.lua` y la ampliación de
`utility/tests/damage_types_test.lua`. Requieren Lua 5.3/5.4; no se ejecutaron en
este entorno, donde tampoco está disponible FGU.

## Validación manual en FGU

1. Recargar; crear y guardar una plantilla Munición con propiedades comunes.
   Verificar ambos filtros y crear una instancia independiente, sin alterar la plantilla.
2. En una instancia de prueba, comprobar cantidades, contenedores y propiedades
   de apilamiento mediante los mecanismos existentes, sin esperar nuevas operaciones.
3. Activar Utiliza munición en un perfil. Asignar una plantilla; probar consumo
   1, 2 y 3 y capacidad 10/30. Guardar con la configuración abierta y reabrir.
4. Probar 0, negativos y decimales con munición activa: Guardar debe rechazarlos.
5. Cambiar y quitar la referencia; comprobar Guardar y Descartar en plantilla e
   instancia. Desactivar/reactivar debe conservar referencia, consumo y capacidad.
6. En un perfil antiguo sin campos nuevos, abrir, cerrar y consultar no debe
   materializarlos. Si usa munición, debe mostrar consumo efectivo 1.
7. Seleccionar una plantilla de módulo, guardar, cerrar el módulo y reabrir:
   conservar la referencia y mostrarla inaccesible, sin sustituirla ni producir errores.
8. Comprobar lista vacía de municiones, nombres duplicados y dos perfiles que
   compartan plantilla con consumos diferentes. No se crean depósitos por perfil.
9. Comprobar pie de tabla, segunda línea de consulta, tooltips y filas consecutivas
   de distinta altura. Un perfil sin munición conserva su presentación anterior.
10. Comparar las cantidades del inventario antes/después de editar, guardar,
    descartar y recargar: no deben cambiar.

Fuera de alcance: descuento de unidades, recargas, munición cargada, depósitos,
tiradas, efectos de munición y consulta especializada de armas de proyectiles.
