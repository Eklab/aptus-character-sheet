# Skin genérica de EQUIPO

## Composición y recursos reales

No se han renombrado ni modificado PNG. Los nombres que existen en este checkout
son `items/deafault`, `item_cualidadest.png` e `item_butom_secundary.png`.

| Archivo | Tamaño | Alfa observado |
|---|---|---|
| graphics/frames/items/deafault/item_background.png | 650 × 433 | Opaco |
| graphics/frames/items/deafault/item_border.png | 164 × 165 | Transparencia |
| graphics/frames/items/deafault/item_task_selected.png | 168 × 32 | Opaco |
| graphics/icons/item_data.png | 20 × 23 | Transparencia |
| graphics/icons/item_container.png | 24 × 23 | Transparencia |
| graphics/icons/item_combat.png | 24 × 23 | Transparencia |
| graphics/icons/item_cualidadest.png | 23 × 22 | Transparencia |
| graphics/icons/item_butom_primary.png | 119 × 28 | Transparencia |
| graphics/icons/item_butom_secundary.png | 124 × 28 | Transparencia |

El fondo incluye borde exterior, marco de imagen, cuatro botones de navegación,
cabecera y pergamino. No es una textura neutra de nueve zonas que admita cualquier
redimensionado: estirarlo deformaría los elementos de la columna izquierda.
Se documentó esta limitación antes de sustituir la presentación.

La ficha se fija a **650 × 433**, con fondo a 1:1. No ofrece redimensionado libre.
Para recuperarlo será necesario disponer de recursos separables o definir otra
composición, sin estirar este PNG. Los iconos, selector y fondos de botones se
dibujan a tamaño real. `item_border.png` se registra como recurso, pero no se
superpone: repetiría el marco ya dibujado en el fondo.

## Interfaz

- Imagen: área cuadrada 150 × 150 en (20,48), `drawmode=fit` nativo. Mantiene
  proporciones, permanece visible y no depende de la pestaña seleccionada.
- Cuatro pestañas en la izquierda. Selector 168 × 32 en X=12, Y=214/245/276/307.
  Se reutilizan fuentes APTUS y el controlador funcional nativo de ventana.
- Datos comunes: nombre, Tipo, descripción con scroll y referencia de imagen.
- Contenedor y Carga: seis propiedades existentes, sin cálculos nuevos.
- Combate: cuatro modificadores y lista desplazable de perfiles.
- Cualidades: lista desplazable de cualidades generales.
- Las cualidades generales y de perfil utilizan el catálogo CUALIDADES y su
  ventana independiente de asociaciones.
  Sus columnas se estrechan localmente para caber en el panel derecho.
- Descartar/Releer y Guardar permanecen en el pie, fuera de todas las listas y
  desplazamientos. Se conserva la visibilidad de Guardar según permisos/bloqueo.
- Los mensajes aparecen en el espacio inferior izquierdo; su tooltip conserva
  el texto completo. Los metadatos técnicos no ocupan el pergamino.

Las pestañas cambian exclusivamente visibilidad. No se recrea el borrador ni se
destruyen las listas al navegar. Guardar y Descartar siguen utilizando las mismas
funciones. No se ha modificado el gestor de datos/identidad/versionado/restauración
ni el script funcional de las filas de colecciones.

## Comprobaciones realizadas

- Dimensiones leídas de las cabeceras PNG y recursos inspeccionados visualmente.
- Canales alfa comprobados decodificando PNG en memoria, sin editar recursos.
- XML balanceado y referencias resueltas contra extensión o CoreRPG.
- Controles principales dentro de 650 × 433, sin duplicados de nombre.
- Cuatro páginas y controles de navegación presentes; bloques Lua balanceados.
- SHA-256 del gestor de Equipo y script de colecciones idénticos antes/después.

No hay FGU ni compilador Lua disponibles. Estas comprobaciones no confirman que
la ventana cargue ni que el renderizado/interacción funcionen en el motor.
No se ha iniciado, recargado ni reiniciado la sesión de FGU.

## Validación manual pendiente

1. Abrir una plantilla de prueba. Verificar fondo, barra nativa de ventana,
   iconos y selector alineados sobre las cuatro pestañas. No debe aparecer un
   segundo borde nativo ni un marco duplicado alrededor de la imagen.
2. Probar imagen cuadrada, horizontal y vertical. Debe encajar sin deformarse y
   mantenerse al cambiar entre las cuatro pestañas.
3. Modificar campos en Datos, Contenedor y Combate sin guardar. Alternar páginas:
   deben conservarse los valores. Verificar una descripción extensa y su scroll.
4. Crear varios perfiles y asociaciones de cualidades. Abrir configuraciones y
   recorrer los scrolls de las listas y la ventana de asociaciones. Ningún campo debe
   salir del pergamino ni cubrir imagen, navegación o botones inferiores.
5. Guardar desde cada pestaña: un solo incremento por edición confirmada y
   ninguno al guardar sin cambios. Cerrar/reabrir para comprobar persistencia.
6. Descartar/Releer desde cada pestaña: recupera todos los campos y colecciones
   persistidos. Cerrar sin guardar conserva el comportamiento anterior.
7. Bloquear/desbloquear y abrir desde cliente/módulo de solo lectura: permanece
   la misma organización; se respetan las restricciones de edición existentes.
8. Intentar redimensionar: tamaño fijo 650 × 433. Minimizar, cerrar y arrastrar
   el enlace desde la barra nativa deben conservar sus acciones.
9. Comprobar un error de guardado y consultar su tooltip sin que los mensajes
   desplacen los botones. Revisar consola por errores XML/Lua.
10. Abrir personajes, Localizaciones y Vehículos: su presentación no cambia.
