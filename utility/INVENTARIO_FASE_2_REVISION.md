# Revisión de la ficha de instancia — fase 2

## Alcance y componentes reutilizados

Se revisa únicamente la ficha de instancia y se añade Riqueza al modelo y editor
de plantillas. Sin fases 3–9, cálculos de carga, borrados de objetos, movimientos,
apilamiento ni modificaciones de otras pestañas, CoreRPG o APTUS Dice.

De CoreRPG se reutiliza la barra `windowmenubar_recordsheet` heredada de la
plantilla, con controles completos `toolbar_action_right` y `toolbar_field_right`,
las acciones close/minimize, el campo locked, `WindowManager.getReadOnlyState`
y sus eventos de bloqueo. Referencias examinadas, de sólo lectura:

- `/references/corerpg/common/template_toolbar.xml`.
- `/references/corerpg/common/scripts/toolbar_button_field.lua`.
- `/references/corerpg/common/scripts/record_window.lua`.
- `/references/corerpg/scripts/manager_toolbar.lua`.
- `/references/corerpg/scripts/manager_window_menu.lua`.
- `/references/corerpg/scripts/manager_window.lua`.

Del catálogo se reutilizan composición, navegación, campos de borrador, controles
Cambiar tipo/Añadir, filas de perfiles, asociaciones de cualidades y su validador.
No se modifican los componentes compartidos de perfiles o cualidades. Se conservan
Minimizar, candado y cierre; se excluyen Crear copia, duplicación, exportación y
compartición genérica. Eliminar está deshabilitado y sin callback. Eliminar una
asociación o un perfil del borrador no elimina definiciones ni objetos.

## Comportamiento y decisiones

- El candado controla campos, edición de perfiles/cualidades y Guardar en las
  cuatro páginas. Desbloqueado por defecto nativo si el campo locked no existe;
  abrir la ficha no escribe valores predeterminados. Bloquear no guarda el borrador.
- El gestor comprueba permisos y candado también al guardar. El token protege
  frente a cambios concurrentes en todo el registro, salvo locked, que es metadato
  de interfaz. Descartar permite releer tras un conflicto.
- Se editan las propiedades particulares en el nodo de la instancia. Las
  asociaciones conservan referencias quality_id a sus definiciones, no copias de
  las definiciones globales. Los perfiles y sus cualidades se guardan por separado
  de los originales. Ninguna modificación del borrador escribe en la plantilla.
- Cantidad, carried, aptus.container, esquema, identificadores y procedencia
  están excluidos del guardado. El panel inferior se reserva para mensajes
  locales de la ventana. La cabecera muestra Nombre (Tipo) persistidos y se
  refresca con cambios del inventario sin reemplazar el borrador local.
- Tipo, apilable, máximo de pila y condición de contenedor son propiedades de la
  instancia. No ejecutan operaciones de pilas. Se rechaza convertir en contenedor
  una cantidad distinta de uno, y quitar la condición a un contenedor ocupado.
  El formulario normaliza contenedores a no apilable/máximo uno, como el catálogo.
- Sólo se sustituyen las colecciones modificadas. Se conservan campos adicionales
  de perfiles y el resto de properties. Un fallo recuperable restaura escalares,
  colecciones, tipos y ausencias previas. No es una transacción atómica ante un
  cierre del proceso o pérdida de permisos durante la restauración; un fallo de
  restauración se informa explícitamente. Datos de tipo/colección incompatible
  bloquean edición y no se reparan automáticamente.
- `properties.is_wealth` es opcional, numérico 0/1, predeterminado falso. Se edita
  en Datos comunes de plantilla e instancia. Se copia al crear y nunca se propaga
  después. Ausente significa falso sin materializarlo al consultar o al guardar
  otros cambios. La vista expone is_wealth, pero el filtro y diamante siguen pendientes.
- Se conservan columnas, posiciones, dimensiones, fuentes, iconos, búsqueda,
  filtros, jerarquía, scrollbar y CARGA.

## Capacidad: preparación sin cálculo

Disponibles: `properties.load_every`, `properties.load_value`,
`properties.capacity` y `count`. No existe carga acumulada calculada fiable.

`getContainerDisplayName(item, accumulated)` formatea Nombre (carga/capacidad)
sólo si recibe explícitamente una carga real válida y la capacidad está disponible.
La fila lo llama sin acumulado y muestra el nombre sin sufijo ficticio. El tooltip
muestra capacidad máxima real cuando existe y «carga acumulada pendiente».

Antes de activar el indicador deben definirse unidades, cálculo por cantidad,
redondeo de load_every, datos ausentes, significado de capacidad cero, peso propio
de contenedores anidados y suma de todos los descendientes sin duplicidades.
No se suma nada ni se comprueba capacidad o sobrecarga en esta revisión.

## Archivos

Modificados:

- `campaign/record_equipment_aptus.xml`: casilla Riqueza en Datos comunes.
- `campaign/record_inventory_item_aptus.xml`: candado/minimizar, recuperación de
  controles aplicables, Eliminar deshabilitado y espacio para CTA en cabecera.
- `scripts/manager_aptus_equipment.lua`: campo opcional y validación booleana.
- `scripts/manager_aptus_inventory.lua`: campos particulares, colecciones,
  guardado/recuperación, lectura de Riqueza y formateador pendiente de capacidad.
- `scripts/record_equipment_aptus.lua`: visibilidad de Riqueza en Datos comunes.
- `scripts/record_inventory_item_aptus.lua`: modo de edición y borradores de
  perfiles/cualidades, validaciones y contexto informativo.
- `scripts/inventory_item_window_aptus.lua`: cambios de candado/permisos y refresco
  informativo, con retirada de observadores al cerrar.
- `scripts/char_equipment_row_aptus.lua`: punto de presentación de capacidad y tooltip.
- `utility/tests/inventory_create_test.lua`: regresiones de instancias.
- `utility/tests/equipment_save_test.lua`: regresiones de Riqueza en plantillas.
- `utility/INVENTARIO_FASE_2.md`: comportamiento y validación actualizados.
- `utility/EQUIPO_FICHA_VISUAL.md`: referencia a esta revisión.

Creados:

- `utility/tests/inventory_instance_static_test.js`.
- `utility/INVENTARIO_FASE_2_REVISION.md`.

## Comprobaciones

Ejecutada y superada desde character-sheet:

    node utility/tests/inventory_instance_static_test.js

Comprueba balance léxico de bloques/delimitadores de nueve Lua (no es un parser
Lua completo), etiquetas XML balanceadas, scripts referenciados, controles de las
cuatro páginas, exclusión de campos estructurales, ausencia de guardado de catálogo
desde instancia, candado nativo, Eliminar sin acción y separación geométrica de
Riqueza y Eliminar | Descartar | Guardar, además de la herencia de la barra nativa
y la visibilidad conjunta de Guardar/Descartar.

Ampliadas, pero NO ejecutadas aquí por falta de Lua/luac y FGU:

    lua utility/tests/inventory_read_test.lua
    lua utility/tests/inventory_create_test.lua
    lua utility/tests/equipment_save_test.lua

Las pruebas DB en memoria comprueban bloqueo de guardado sin escrituras, token
estable al alternar candado, perfiles y cualidades generales/de perfil, eliminación
de asociaciones sólo en borrador, independencia de plantilla y otras instancias,
copia de Riqueza, ausencia opcional sin escrituras, rechazo de valores inválidos,
recuperación ante fallo de colección y preservación de contención. Los números
usados para probar el formateador sólo existen en la prueba aislada.

## Validación manual en Fantasy Grounds

1. En campaña de prueba, crear/guardar una plantilla con perfil y cualidad general
   y otra de perfil; marcar Riqueza. Crear dos instancias desde EQUIPO.
2. Abrir una con Ver. Comprobar cabecera, minimizar/restaurar y candado. Cerrarlo:
   las cuatro páginas deben ser de consulta, sin alta/borrado de perfiles ni Guardar.
3. Abrir candado. Editar nombre, descripción, imagen, tipo y Riqueza; en Contenedor
   y Carga editar propiedades; en Combate modificar y añadir un perfil con cualidades;
   en Cualidades modificar asociaciones generales. Guardar y reabrir cada página.
4. Comprobar que plantilla y segunda instancia siguen iguales. Modificar la plantilla
   y comprobar que ninguna instancia previa cambia; una nueva copia toma lo nuevo.
5. Probar cambios sin Guardar: Descartar y cerrar deben conservar datos guardados.
   Alternar candado con borrador pendiente no debe provocar conflicto por sí solo.
6. Abrir asociaciones de cualidades, cerrar el candado desde otro cliente/ventana
   y tratar de aplicar cambios: debe impedirlo. Repetir revocando propiedad.
   El diálogo compartido conserva sus propias protecciones; confirmar sus botones
   y legibilidad también en la versión concreta de FGU.
7. Comprobar Eliminar a la izquierda de Descartar: no puede borrar el objeto.
   Confirmar que no reaparece Crear copia de plantilla.
8. Con el fixture de fase 1, abrir contenedor anidado y objeto contenido: revisar
   Cantidad, Estado heredado y Ubicación inmediata, incluidos tooltips largos.
   Renombrar un contenedor actualiza Ubicación sin cambiar vínculos por nodo.
9. No deben existir campos editables de Cantidad/Estado/Ubicación/procedencia.
   Intentar quitar condición de contenedor a uno ocupado: debe rechazarlo sin
   extraer nada. No probar cambios manuales de relaciones en campañas reales.
10. Revisar capacidad en tooltip: sin sufijo (0/máximo) inventado, CAR/CARGA neutros.
11. Usar registros antiguos sin is_wealth: falso en UI; abrir y guardar otros datos
    no debe añadir la propiedad. Cambiarla explícitamente sí debe guardarla.
12. Comprobar filtros, búsqueda, conexiones de una indentación, últimas filas con
    scrollbar, Ver y otras pestañas. Ningún filtro nuevo ni marcador diamante activo.
13. Con dos editores sobre la misma instancia, guardar uno y luego el otro: debe
    rechazar el borrador anterior; Descartar relee. Reiniciar la campaña y comprobar
    persistencia de las propiedades particulares, sin cambios en el catálogo.

Se detiene aquí esta revisión. Pendientes eliminación confirmada/recursiva mediante
el gestor común, filtro/marcador Riqueza, carga acumulada e integración posterior.


## Ajuste final de CTA y acciones según candado

La instancia hereda ahora la misma barra de la plantilla, incluido el anclaje
`-12,8`, las dimensiones nativas de 20×20, marcos, estados y separación. Se retiran
los controles sueltos sin marcos y el cierre aptus_close. Se reutilizan exactamente
los iconos registrados por CoreRPG: button_toolbar_window_close,
button_toolbar_window_minimize, button_toolbar_locked_false y
button_toolbar_locked_true; los marcos windowmenubar_button y
windowmenubar_button_down y el color de menú del tema, sin recursos nuevos.
La barra muestra sólo las acciones aplicables de la instancia, sin añadir
compartición, exportación, duplicación o enlace genérico de catálogo.

El guardado y los permisos no cambian. La comprobación existente del candado
apunta ahora a menubar.subwindow.locked. Guardar y Descartar, incluidos sus fondos,
se ocultan juntos al cerrar el candado y reaparecen al abrirlo. Eliminar sigue
visible, deshabilitado y sin acción.

Cambiar el candado llama a update, no a reload/save: conserva campos locales,
tipo elegido y borradores de perfiles/cualidades, sin escribir sus propiedades.
El propio metadato locked se escribe por el mecanismo nativo, como antes.
Los perfiles capturan sus cambios sólo en el borrador antes de pasar a consulta.

Archivos modificados en este ajuste:

- campaign/record_inventory_item_aptus.xml.
- scripts/inventory_item_window_aptus.lua.
- scripts/record_inventory_item_aptus.lua.
- utility/tests/inventory_instance_static_test.js.
- utility/INVENTARIO_FASE_2_REVISION.md.

La prueba estática Node pasa con las nuevas referencias y comprueba que alternar
el candado no llama a guardado/recarga ni escribe directamente en DB desde update.
No se ejecutó Fantasy Grounds ni Lua en este entorno.

Validación FGU: abrir plantilla e instancia con el mismo tema y comparar iconos,
marcos normal/pulsado, dimensiones y separación de los tres CTA aplicables.
Comprobar minimizar/restaurar, cerrar y alternar candado. Con candado abierto,
modificar texto, tipo y un perfil/cualidad sin guardar; cerrarlo: Guardar y Descartar
deben desaparecer, Eliminar permanecer deshabilitado. Reabrir el candado: deben
recuperarse los botones y todos los cambios pendientes. Guardar debe persistir
sólo entonces; repetir con Descartar debe recuperar los valores guardados. Verificar
que el candado no haya guardado las propiedades mientras estaba cerrado y que
los permisos sigan impidiendo editar a usuarios sin propiedad. No hay cambios
en el modelo, datos, inventarios, catálogo ni otras pestañas.


## Cabecera dinámica y mensajes locales de instancia

Se conserva la geometría de la cabecera y sus CTA. El área metadata (20,12,530,20)
muestra Nombre (Tipo) mediante un textwidget nativo añadido al control existente,
con la misma fuente/color. setMaxWidth limita el texto al ancho existente y añade
puntos suspensivos. El tooltip conserva título completo y procedencia. Se elimina
la configuración multilínea heredada sólo de la cabecera de instancia; saltos de
línea del nombre se presentan como espacios en su título de una línea.

updateHeader lee name y properties.type_id directamente de DB y resuelve la
etiqueta con APTUSEquipmentManager.getTypeName. No lee el nombre ni el tipo del
borrador. Se llama al abrir, después del primer layout, al finalizar Guardar o
Descartar y con las notificaciones de inventario existentes. Durante las
operaciones locales se inhiben refrescos intermedios para no mostrar escrituras
parciales antes de su resultado. Guardar y el Descartar existente conservan su
persistencia/recarga; el botón de Descartar sólo añade una envoltura informativa.

instance_context conserva posición, tamaño, fuente y líneas del antiguo panel,
pero ya no muestra Instancia/Cantidad/Estado/Ubicación. Al abrir bloqueado se
inicializa vacío. Sólo un cambio real de editabilidad genera Edición activa o
Edición desactivada; las llamadas internas redundantes a update no generan mensajes.
Guardar muestra Instancia guardada o No se han podido guardar los cambios, con
el detalle completo del gestor en tooltip. Descartar muestra Cambios descartados.
Los errores se presentan localmente, sin enviar notificaciones al chat.

Prioridad: durante Guardar/Descartar se inhiben mensajes de cambio de modo; después
se presenta su resultado. Las confirmaciones se protegen de mensajes de modo
unos tres segundos usando os.time (ya usado en CoreRPG). Los errores quedan hasta
otro Guardar/Descartar, aunque se cambie de modo. El estado es privado de cada
ventana. Cerrar no deja callbacks o temporizadores pendientes.

No hay desaparición automática a los tres segundos: los mensajes permanecen hasta
la siguiente acción relevante. No se encontró un temporizador documentado en las
APIs consultadas ni uno reutilizable en CoreRPG. No se añaden sondeos, servicios,
peticiones de red, manejadores globales ni bucles de espera para simularlo.

Referencias nativas verificadas:

- CoreRPG common/scripts/combobox.lua y windowtitlebar.lua: addTextWidget,
  setText, getSize, setPosition y setMaxWidth.
- https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/996644775/textwidget
- https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/996644632/Interface
- https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/1481998353/Utility

Archivos de esta intervención:

- campaign/record_inventory_item_aptus.xml: callback local de Descartar y cabecera
  de una línea; sin cambios de bounds o CTA.
- scripts/record_inventory_item_aptus.lua: título persistido, mensajes y prioridad.
- scripts/inventory_item_window_aptus.lua: el observador actualiza la cabecera,
  sin recuperar la antigua información del panel.
- utility/tests/inventory_instance_static_test.js: verificaciones actualizadas.
- utility/tests/inventory_instance_view_test.lua: nueva prueba aislada de vista.
- utility/INVENTARIO_FASE_2.md y este documento.

Comprobaciones ejecutadas y superadas: prueba estática Node y node --check.
Incluyen XML balanceado, referencias, nueve Lua con balance léxico, control
Descartar heredado sin cambios de tamaño, título leído de DB con recorte/tooltip,
mensajes locales y protección de campos estructurales. No es validación del motor
FGU ni compilación Lua. La nueva prueba de vista simula guardado, descarte,
bloqueo automático, error, apertura bloqueada, cambios pendientes y nombres largos,
pero NO se ejecutó aquí por falta de Lua. No se instalaron herramientas.

Validación en FGU:

1. Abrir bloqueado: panel vacío y Nombre (Tipo) guardados en cabecera.
2. Abrir candado, cambiar nombre y tipo: cabecera antigua hasta Guardar. Guardar:
   título nuevo y confirmación local; cerrar/reabrir confirma persistencia.
3. Cambiar otra vez sin guardar y pulsar Descartar: título y campos vuelven a los
   valores persistidos y aparece Cambios descartados.
4. Cambiar de modo en ambas direcciones: mensajes correctos, sin perder borrador.
   Cambiar de pestaña no debe generar otro mensaje ni borrar el anterior.
5. Guardar y alternar candado inmediatamente: debe prevalecer la confirmación
   durante unos tres segundos. Después, otra acción de modo puede reemplazarla.
   El mensaje no desaparece por tiempo automáticamente.
6. Probar validación de guardado con nombre vacío: error local persistente y causa
   en tooltip; no debe aparecer un nombre no guardado en cabecera. Cambiar el modo
   no borra el error. Un Guardar correcto o Descartar lo reemplaza.
7. Con un nombre largo, verificar puntos suspensivos, tooltip completo y ausencia
   de solapamiento con los CTA, en diferentes escalas de interfaz.
8. Abrir dos instancias: mensajes y errores independientes. Cerrar con un mensaje
   y reabrir bloqueado: panel vacío, sin mensajes atrasados.
9. Confirmar que perfiles/cualidades y las cuatro pestañas siguen editándose como
   antes; Eliminar permanece visible deshabilitado y Guardar/Descartar mantienen
   su visibilidad por candado. Plantillas, modelo e inventarios sin cambios.
