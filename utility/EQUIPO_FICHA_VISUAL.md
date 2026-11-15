> Actualización funcional de Estado: ver `INVENTARIO_ESTADO.md`. La selección
> directa y la exclusión de raíces Sin equipar sustituyen el modo de lectura
> y la herencia de Estado descritos en las fases visuales anteriores.

# EQUIPO — visual validado e inventario, fase 2

La composición visual validada se conserva. EQUIPO consulta ahora las instancias
APTUS compatibles de `charsheet.<personaje>.inventorylist`, sin datos ficticios
activos. Añadir/drop crean instancias y Ver abre su ficha particular.
Validación de lectura y fixtures: [INVENTARIO_FASE_1.md](INVENTARIO_FASE_1.md).
Creación y edición: [INVENTARIO_FASE_2.md](INVENTARIO_FASE_2.md).

## Distribución conservada

| Columna | X relativa a fila | Anchura |
| --- | ---: | ---: |
| Nombre | 0 | 215 |
| Cant. | 217 | 26 |
| Estado | 247 | 32 |
| Ubicación (selector visual) | 285 | 116 |
| CAR | 405 | 36 |
| Ver | 441 | 25 |

Fila de 24 px y lista de 483×232 en X=40/Y=84. Scrollbar nativo en
X=508/Y=84, 15×232. Ver conserva 25×24 y su separación de 2 px respecto a
la barra, sin solaparse con CAR. No se mueven cabeceras ni el panel CARGA.

Nombre conserva iconos junto al texto, fuente de 14 y conexiones nativas
beige de 1 px. La profundidad interna puede superar dos niveles, pero todos
los descendientes se dibujan a 18 px de su raíz. Los nombres truncados tienen
tooltip. La columna Ubicación muestra el contenedor inmediato, por identidad
de nodo, y `-` en raíz. Sus marcos y margen de texto permanecen iguales.

Estado muestra el valor efectivo de la raíz: verde Equipada, amarillo
Transportada y guion beige Sin estado. Su control conserva tooltip y centrado,
pero es de lectura y no avanza al pulsar. Ver abre la instancia con su icono y
dimensiones anteriores. El botón Añadir ocupa el hueco X=386..406 entre filtros
y búsqueda, sin desplazar controles; usa el catálogo existente.

Todo y Personaje consultan inventario real; búsqueda y conexiones conservan
las agrupaciones. Localizaciones, Vehículos y Riqueza están pendientes y no
muestran ejemplos simulados. El pie indica lectura y ofrece diagnósticos de
registros omitidos. Las consultas no reparan referencias ni migran registros.

El scrollbar aparece si las filas de 24 px superan el alto del viewport.
Rueda y arrastre siguen siendo nativos; el refresco vuelve al primer resultado.

CAR muestra `—` y CARGA `—`/`Pendiente`, con relleno oculto. No se infieren
fórmulas ni se presenta la antigua carga de prueba como información real.

Las fuentes locales de fila y cabecera permanecen en 14 y 12 respectivamente.
No se alteran PNG; se reutilizan los recursos existentes, incluido Añadir.

## Validación

Importar manualmente el fixture de la fase 1 sólo en una campaña nueva de
prueba: debe mostrar 19 filas reales, 11 avisos y scrollbar. Comprobar estados
heredados, ubicaciones inmediatas, nombres duplicados, búsqueda y los casos
inválidos que permanecen en DB. Pulsar Estado no debe cambiar datos.

Detalles, archivos modificados, comprobaciones estáticas y límites en
`INVENTARIO_FASE_1.md`. La maqueta anterior queda archivada fuera de la extensión
en `utility/fixtures/equipment_visual_sample.lua` y no se carga automáticamente.

## Validación adicional de fase 2

Comprobar creación por Añadir y drop (dos altas, dos objetos), apertura por Ver,
edición particular sin cambiar plantillas, permisos y persistencia. Se conserva
la geometría de columnas, scrollbar y panel de carga. Después de crear, se limpia
la búsqueda y se muestra el nuevo objeto. No se activan Estado, Ubicación,
transferencias ni apilamiento. Procedimiento completo en INVENTARIO_FASE_2.md.

## Revisión de la ficha de instancia — fase 2

Sin cambios de columnas, filas, iconos, fuentes, scrollbar ni panel CARGA.
Ver abre una ficha con candado nativo, perfiles y cualidades editables en
borrador, Riqueza opcional y Eliminar deshabilitado. Cantidad, Estado efectivo
y Ubicación inmediata permanecen informativos. Los contenedores conservan
su nombre sin carga inventada; el tooltip añade capacidad máxima cuando
existe y señala que la carga acumulada está pendiente. Validación detallada
en INVENTARIO_FASE_2_REVISION.md.
