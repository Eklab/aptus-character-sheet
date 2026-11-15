> Actualización de tipos de daño: la segunda línea muestra siempre Tipo/Tipos y
> Cualidades, con Nada cuando falten selecciones. Modelo y validación actuales en
> TIPOS_DANO_PERFILES.md; no cambian los PNG ni las tarjetas de 393 × 52.

> Diseño vigente: aplicar las correcciones de la sección final. El candado inicial
> ahora es local, la consulta no tiene Eliminar y cada perfil usa una tarjeta de 52 px.

# Consulta especializada de Arma C.C.

## Alcance

Una única presentación registrada para el identificador interno melee_weapon.
La instancia y sus operaciones siguen siendo las existentes. Sin cambios del
modelo, plantillas, creación, eliminación, otras pestañas o APTUS Dice. No se
crean registros, cualidades, perfiles de ejemplo, UUID ni propiedades nuevas.

## Recursos originales inspeccionados

La ruta real es graphics/frames/items/deafault/ (no default). Se conserva la
carpeta y todos los PNG originales, sin renombrarlos ni escribirlos. Se han
inspeccionado visualmente los ocho archivos y decodificado su canal alpha real.

| Archivo | Tamaño nativo | Transparencia real | Uso |
|---|---:|---|---|
| item_background_arma_cc.png | 651 × 433 | Sí, 382 píxeles transparentes | Fondo de consulta |
| item_background.png | 650 × 433 | No, alpha totalmente opaco | Fondo del editor existente |
| item_border_arma_cc.png | 200 × 201 | Sí, incluye alpha parcial | Borde sobre imagen de consulta |
| item_border.png | 164 × 165 | Sí | Registro común existente |
| item_task_selected.png | 168 × 32 | No, alpha totalmente opaco | Selección de pestaña del editor existente |
| item_titulos_arma_cc.png | 392 × 25 | Sí | Cabeceras de sección |
| item_titulos_perfil_arma_cc.png | 393 × 24 | Sí, incluye alpha parcial | Cabecera única de columnas |
| item_perfil_arma_cc.png | 393 × 52 | Sí, incluye alpha parcial | Tarjeta completa de perfil |

La diferencia 651/650 del fondo se comunicó antes de implementar. La ventana
permanece en 650 × 433; el icono de fondo conserva 651 × 433 y el píxel excedente
queda en el borde derecho del viewport. No hay escalado del bitmap, modificación
de la ventana ni ajuste de PNG. Confirmar ese borde en FGU durante validación.

Se utiliza el fondo exportado solicitado, no una captura de referencia ni una
composición generada con datos. Los tres recursos comunes ya están registrados
por graphics_aptus_equipment.xml; se conservan sin duplicar sus registros. El nuevo
archivo graphics_aptus_item_consultation.xml registra cinco iconos especializados
y una fuente local Roboto Condensed 14 en color oscuro para texto sobre pergamino.
Las familias y fuentes globales no se modifican.

## Superposición y distribución

El control de fondo de consulta se envía detrás de los controles con sendToBack.
La cabecera y el menubar nativo se conservan: no se cambian botones, anclajes o
tamaño de la ventana. El cuerpo especializado es un subwindow en (0,34), de
650 × 399, separado de la cabecera. onInstanceCreated configura su contenido cuando
FGU lo instancia de forma diferida al mostrarlo por primera vez. Todo el contenido utiliza controles nativos.

Coordenadas siguientes relativas a la ventana completa:

- Imagen: (22,55), 192 × 192, tokencontrol con drawmode fit y mismo prototype que
  el editor. Borde: (18,51), 200 × 201, con transparencia sobre la ilustración.
- Descripción: (24,266), 178 × 136, multilínea, lectura y scroll propio en x204.
  Conserva saltos de línea y no depende de tooltips. Se aprovecha el recuadro
  izquierdo hasta y402 sin superponer mensajes o botones.
- Cabecera PERFILES DE COMBATE: (239,53), con banda nativa de 392 × 25.
- Encabezados Perfil/Habilidad/Daño/Crítico: una sola vez, en y82.
- Lista derecha: (239,106), 393 × 269, con scrollbar independiente a su derecha.
- Pie de consulta: sólo mensajes en (239,383), 392 × 28, sin Eliminar ni hueco
  reservado para botones. El pie común se recupera al volver al editor.

En edición sólo se ajusta la imagen de la instancia al tamaño solicitado de
157 × 157, con fit, dentro del marco común. La plantilla no cambia; las cuatro
páginas, sus campos, posiciones, controles y validaciones permanecen iguales.

## Selección de presentación y borradores

El registro local tConsultationViews del controlador de instancia contiene sólo:

    melee_weapon → aptus_item_melee_view + aptus_item_melee_background

Consulta el tipo persistido y el candado local de la ventana, nunca el nombre
traducido ni el tipo del borrador. Cada ventana nueva comienza bloqueada sin
escribir locked; los gestos manuales conservan la sincronización de ese metadato. Para añadir una futura presentación se podrá añadir una entrada y su
clase real; no se crean clases vacías ni casos de otros tipos ahora.

Con candado abierto se muestra el editor; con candado cerrado y melee_weapon,
la consulta. Los demás tipos cerrados siguen usando el editor común en lectura.
Antes de aplicar el modo se restauran visibilidades de controles; después se
vuelven a aplicar las reglas del editor y sólo se ocultan sus controles si hay
consulta. No se cierra, recarga o reconstruye el borrador al alternar modos.
Los perfiles del editor conservan sus controles y colecciones locales.

La cabecera muestra sólo el nombre persistido en consulta especializada. En
edición y tipos sin vista conserva Nombre (Tipo). Continúan el truncado nativo y
el tooltip completo. Guardar/Descartar actualizan desde DB; cerrar el candado
con cambios pendientes muestra los valores guardados sin perder el borrador.

El observador de inventario ya existente llama a onPersistentDataChanged:
actualiza la presentación sin releer el borrador. El guardado local sigue
inhibiendo sus refrescos intermedios. No se añaden observadores DB globales ni
segundas fuentes de datos. Mensajes y errores se reflejan en el pie de consulta
mediante getMessage/setMessage; su prioridad y persistencia no cambian.

## Perfiles, cualidades y desplazamiento

La vista usa el lector de colecciones de APTUSEquipmentManager y crea una ventana
por perfil real, ordenado por clave igual que el editor. No existen cuatro filas
fijas ni se completan huecos. Cada tarjeta de perfil conserva 393 × 52 sin estirarse. La banda negra de
393 × 24 se utiliza sólo en los encabezados de columnas.

La habilidad utiliza attack_skill_id y el catálogo de habilidades existente,
con la misma denominación Pelea/Puntería como fallback del editor. El modificador
attack_modifier se presenta con signo y d sólo cuando no es cero. damage y
critical se leen independientemente y no se interpretan o calculan.

summary y details de APTUSQualityManager resuelven los nombres separados por comas
y los tooltips, igual que el editor. Cada perfil utiliza exclusivamente sus
propias asociaciones. La última ventana de la lista es la sección CUALIDADES
DEL EQUIPO con las asociaciones generales. Si no hay cualidades, no se añaden
nombres ni una línea vacía; sólo queda la cabecera de sección correspondiente.

Las cualidades del perfil se recortan en una única línea dentro de la tarjeta,
con tooltip completo. Cada tarjeta tiene 52 px y 6 px de separación. Sólo las
cualidades generales conservan altura multilineal automática. La windowlist
coloca cada bloque después del anterior, sin setSize ni estirar los PNG. Los
nombres de perfil largos conservan tooltip completo y límites de su columna.
El scroll derecho incluye todos los perfiles y después las cualidades generales;
la imagen y la descripción no se desplazan con él. La descripción tiene su propio
scrollbar sobre stringcontrol readonly. Se reutilizan los mecanismos de CoreRPG
empleados por el editor para listas, scrollbars, imágenes fit y tooltips.

La vista se suscribe al gestor de cualidades existente para refrescar nombres y
descripciones cuando sus definiciones cambian, y se desuscribe al cerrar. No
contiene operaciones de escritura en DB.

Referencias técnicas:

- CoreRPG common/scripts/combobox.lua y windowtitlebar.lua (widgets y truncado).
- CoreRPG common/template_lists.xml y los controles de lista/scroll del editor.
- https://www.fantasygrounds.com/refdoc/windowcontrol.xcp (sendToBack, anclajes).
- https://www.fantasygrounds.com/refdoc/subwindow.xcp (instanciación diferida y onInstanceCreated).
- https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/996644858/windowinstance
- https://www.fantasygrounds.com/refdoc/stringcontrol.xcp

## Archivos

Creados:

- graphics/graphics_aptus_item_consultation.xml.
- campaign/record_item_melee_consultation_aptus.xml.
- scripts/item_melee_consultation_aptus.lua.
- scripts/item_melee_block_aptus.lua.
- utility/tests/item_melee_consultation_static_test.js.
- utility/ARMA_CC_CONSULTA.md.

Modificados:

- extension.xml: inclusión de recursos y clases.
- campaign/record_inventory_item_aptus.xml: fondo/cuerpo de consulta y tamaño de
  imagen de la instancia en edición.
- scripts/record_inventory_item_aptus.lua: registro/alternancia de presentaciones,
  título adaptado y reflejo local de mensajes.
- scripts/inventory_item_window_aptus.lua: actualización desde el observador existente.
- utility/tests/inventory_instance_view_test.lua: dobles y casos nuevos de consulta.
- utility/tests/inventory_instance_static_test.js: balance léxico de los dos scripts nuevos.

## Comprobaciones ejecutadas

Desde character-sheet:

    node utility/tests/item_melee_consultation_static_test.js
    node utility/tests/inventory_instance_static_test.js
    node --check utility/tests/item_melee_consultation_static_test.js
    node --check utility/tests/inventory_instance_static_test.js

Superadas: decodificación de dimensiones y alpha de ocho PNG, huellas SHA-256,
XML balanceado, rutas de scripts/recursos e inclusión, tamaños fit, cabecera única,
scrolls separados, uso del lector de cualidades, ausencia de escrituras DB en los
scripts nuevos, y balance léxico de doce Lua. Esto no equivale a compilar Lua ni
a renderizar la interfaz en Fantasy Grounds.

La prueba Lua de vista se amplía con selección melee_weapon/otros tipos,
conservación del borrador al cerrar/abrir candado, cabecera sin tipo, seis perfiles,
modificadores cero/positivo/negativo, daño/crítico independientes y separación de
cualidades de perfil y generales. No se ha ejecutado: no hay Lua/luac ni FGU aquí.
No se instalaron herramientas. No se consideran validadas imágenes, alineación,
altura automática, rueda o interacción en el motor hasta probarlas en FGU.

## Validación en FGU

Usar una campaña de prueba y objetos reales creados desde el catálogo; sin datos
inventados insertados automáticamente.

1. Crear una Arma C.C. con nombre, imagen, descripción narrativa y un perfil.
   Abrir instancia y cerrar candado: consulta, nombre sin tipo y CTA nativos.
2. Abrir candado: editor común completo, imagen 157 × 157. Consulta: imagen
   192 × 192. Probar imagen rectangular y confirmar proporción y centrado.
3. Probar un tipo utility y otro storage bloqueados: editor común en lectura.
4. Modificar nombre, tipo, perfil o cualidades sin guardar y cerrar/abrir candado:
   consulta usa DB; el borrador se conserva. Probar Guardar y Descartar.
5. Poner una descripción con párrafos y saltos de línea que exceda ocho líneas:
   rueda y scrollbar propio permiten leerla entera sin mover imagen o perfiles.
6. Crear uno, cuatro y al menos seis perfiles. Cabeceras de columnas una sola vez;
   no aparecen filas vacías. General aparece tras el último perfil, sin solapamiento.
7. Probar Pelea con 0, +1 y -1: Pelea, Pelea +1d y Pelea -1d; daño d6 y crítico
   2d8 deben seguir distintos. No se tiran dados ni se calculan modificadores.
8. Probar nombres largos, perfiles sin cualidades y muchas cualidades: comprobar
   recorte/tooltip del nombre, truncamiento/tooltip de cualidades dentro de cada tarjeta y continuidad de los bloques.
9. Asociar cualidades generales distintas de las del perfil. Nombres con comas y
   tooltip de descripciones, sin iconos individuales. Sin generales: sin contenido falso.
10. Más contenido derecho que viewport: rueda y scrollbar llevan a las últimas
    cualidades, con imagen y descripción fijas. Confirmar altura fija de tarjetas y altura automática de cualidades generales.
11. Verificar que el fondo no se deforma y el píxel derecho excedente queda recortado;
    revisar posición del borde, scrollbars y legibilidad en varias escalas de UI.
12. Guardar, descartar, provocar un error de validación y alternar candado: mensajes
    conservan prioridad en ambos modos; confirmar Eliminar y cancelar/eliminar en
    campaña de prueba desde el editor, con el candado abierto. En consulta debe estar ausente. Mismos permisos y cierre de ventana.
13. Reiniciar campaña: sólo las propiedades guardadas persisten. Revisar consola
    sin errores, otras pestañas y editor de plantillas sin regresiones.

Se detiene aquí la implementación. Otros tipos y fases de inventario pendientes.

## Correcciones tras validación — diseño vigente

### Candado inicial cerrado sin escribir en campaña

La ventana raíz inicializa bInstanceLocked=true, no DB.locked. El control reutiliza
el template nativo toolbar_field_right, sus marcos, dimensiones, iconos, estados,
tooltips y color. El script local inventory_item_lock_aptus.lua llama a
ToolbarManager.initButtonField para configurar sólo su aspecto. No invoca el
inicializador que enlaza el botón automáticamente a DB. Una guarda evita que
setValue inicial o la sincronización de iconos ejecuten un gesto manual.

El menubar local conserva los anclajes y orden nativos: close, minimize, separador,
locked. No se modifica CoreRPG ni se registran botones globales adicionales.
La selección de consulta y los permisos de los controles utilizan el estado local
junto con las comprobaciones existentes del gestor. También el editor común de
otros tipos abre en lectura. Guardar conserva sus validaciones y añade la guarda
de ventana necesaria para respetar este modo local.

Sólo una pulsación manual puede actualizar el metadato locked existente, y sólo
si cambia su valor. Las actualizaciones externas de ese metadato sincronizan el
icono sin volver a escribir. No hay una propiedad nueva ni cambios del modelo.

Desde EQUIPO, Interface.findWindow detecta una ficha ya abierta: sólo se trae al
frente, sin reinicializarla ni recargar sus borradores. Tras cerrar realmente la
ventana, una apertura nueva vuelve a empezar bloqueada, aunque el locked guardado
sea cero. Abrir no materializa ni modifica locked ni otras propiedades.

### Consulta sin Eliminar

Se retiran el botón, su fondo y su delegación de la vista especializada. El área
de mensajes ocupa ahora todo el pie derecho: (239,383), 392 × 28, sin reservar el
hueco de un botón. El editor común recupera su Eliminar original al desbloquear.
Los otros tipos conservan el comportamiento que ya tenían en lectura.
El gestor de eliminación y sus confirmaciones no se modifican.

### Tarjeta real de perfil

El archivo real sigue la grafía del proyecto:
graphics/frames/items/deafault/item_perfil_arma_cc.png.
Inspección directa: RGBA de 8 bits, 393 × 52, alpha 0–255, 15.661 píxeles
transparentes y 3.525 parcialmente transparentes. Se registra como
aptus_item_melee_profile, sin alterar o escalar el original.

La banda negra anterior se registra como aptus_item_columns y se utiliza una
sola vez para los títulos de columna, en (239,80), 393 × 24. El título de sección
PERFILES DE COMBATE conserva su recurso anterior.

| Zona dentro de la tarjeta | X | Y | Ancho | Alto |
|---|---:|---:|---:|---:|
| PNG completo | 0 | 0 | 393 | 52 |
| Nombre del perfil | 6 | 2 | 100 | 20 |
| Habilidad y modificador | 115 | 2 | 89 | 20 |
| Daño | 214 | 2 | 74 | 20 |
| Crítico | 299 | 2 | 86 | 20 |
| Cualidades del perfil | 6 | 29 | 381 | 19 |

Los separadores superiores del PNG están en x209 y x293. Daño, Crítico y sus
cabeceras se alinean con estas zonas. Los valores usan el texto oscuro local
sobre el pergamino transparente de la tarjeta; las cabeceras negras, texto claro.

Las cualidades están dentro del mismo PNG: textwidget de ancho máximo 381,
truncamiento con puntos suspensivos y tooltip completo del gestor existente.
Si no hay cualidades, su zona inferior queda vacía; la tarjeta sigue midiendo
52 px. Los controles visibles de perfil no exceden esos límites. Se conservan
6 px de separación inferior, sin cambiar la pieza gráfica ni generar otra fila.

Las cualidades generales son independientes y mantienen su cabecera, texto
multilínea y tooltips. La windowlist sigue creando perfiles por clave en el orden
del editor, sin límite de cuatro, y coloca las generales después del último perfil.
No cambian el viewport ni sus scrollbars. Las imágenes, descripción y su scroll,
fondo, borde, nombre de cabecera y dimensiones de ventana permanecen iguales.

### Archivos de esta corrección

Creado:

- scripts/inventory_item_lock_aptus.lua.

Modificados:

- campaign/record_inventory_item_aptus.xml.
- scripts/inventory_item_window_aptus.lua.
- scripts/record_inventory_item_aptus.lua.
- scripts/char_equipment_row_aptus.lua.
- campaign/record_item_melee_consultation_aptus.xml.
- graphics/graphics_aptus_item_consultation.xml.
- scripts/item_melee_block_aptus.lua.
- scripts/item_melee_consultation_aptus.lua.
- utility/tests/inventory_instance_static_test.js.
- utility/tests/item_melee_consultation_static_test.js.
- utility/tests/inventory_create_test.lua.
- utility/tests/inventory_instance_view_test.lua.
- utility/ARMA_CC_CONSULTA.md.

No se modifica ningún PNG, plantilla, operación de creación/eliminación, gestor
de inventario/cualidades ni presentación de otro tipo.

### Comprobaciones y validación FGU

Ejecutadas y superadas las dos pruebas Node y ambos node --check. Se comprueban
ocho PNG y sus huellas SHA-256, XML, doce Lua con balance léxico, ausencia de
escrituras en la inicialización del candado y apertura, delegación manual,
cabecera negra única, tarjeta 393 × 52, cualidades acotadas y consulta sin Eliminar.
El balance léxico no equivale a compilar o ejecutar Lua.

Las suites Lua amplían los casos de apertura sin escrituras con locked ausente,
reapertura con locked=0, botón inicial/sincronización sin notificar gestos,
consulta cerrada con DB desbloqueada, alternancia conservando borrador, texto
inferior extenso, perfil sin cualidades y generales separadas. No se ejecutaron:
no hay Lua/luac ni FGU. No se instalan herramientas.

Pasos concretos, en una campaña de prueba:

1. Abrir Arma C.C. y utility desde EQUIPO, también con locked=0 previo: ambas
   arrancan cerradas; Arma C.C. en consulta y utility en editor de lectura.
   Comparar datos antes/después: abrir no debe añadir ni cambiar locked.
2. Desbloquear, modificar sin guardar y pulsar Ver otra vez: vuelve al frente la
   misma ficha, con candado abierto y borrador intacto. Cerrar realmente y abrir
   de nuevo: consulta inicial, sin cambios persistidos por esa apertura.
3. Guardar/Descartar y alternar candado: mismas validaciones, datos y mensajes.
   Revisar iconos, estados, separación de CTA y usuarios sin permisos.
4. Consulta especializada sin Eliminar ni su fondo. Al desbloquear reaparece en
   el editor; probar su confirmación y cancelación sin alterar otros objetos.
5. Banda negra sólo en la cabecera de columnas. Cada perfil, una tarjeta de
   393 × 52 con cualidades dentro y valores alineados con sus separadores.
6. Dos perfiles: uno sin cualidades y otro con muchas. Misma altura, truncamiento
   inferior y tooltip completo, sin solapamientos ni tarjetas adicionales.
7. Seis perfiles: scroll a todos ellos y generales después del último, con
   separación de 6 px. Revisar tooltips, daño/crítico distintos y signos del modificador.
8. Confirmar imagen 192/157, descripción completa con su scroll, fondo/borde y
   consola sin errores nuevos. La apariencia e interacción sólo se consideran
   validadas después de ejecutar estas pruebas en Fantasy Grounds.

Fin de estas correcciones. Sin otras presentaciones ni funcionalidades nuevas.
