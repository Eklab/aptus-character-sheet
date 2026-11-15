# EQUIPO — Crear copia desde la ficha

## Implementación

Botón 124 × 28 en (34,373), en el espacio inferior izquierdo. Reutiliza
`aptus_equipment_button_secondary`, sin PNG nuevos ni cambios de tamaño. Guardar
y Descartar permanecen en (493,383) y (354,383); la ficha sigue en 650 × 433.

Se llama a `CampaignDataManager.duplicateRecord("aptus_equipment",
"aptus_equipment", rutaGuardada, false)`, el duplicador genérico del catálogo.
El callback existente `onRecordAdded` asigna otro template_id y versión 1.
No hay una segunda rutina de copia ni llamadas a Guardar desde Crear copia.

Se detecta la nueva entrada por diferencia entre los registros de campaña antes
y después de la llamada síncrona. Antes de abrirla se comprueban identidad,
versión, esquema, nombre nativo de copia y propiedades completas, incluidas todas
las colecciones y requisitos. Se comprueba también que el token del original
no cambie. Los campos aditivos ausentes en plantillas antiguas se comparan con
los predeterminados que el callback ya aplica a las copias nuevas.

Sólo tras verificar se usa `RecordManager.openRecordWindow`. Si falla, no se abre
una ficha incompleta. Si se identifica una única entrada recién creada, se
intenta retirar sólo esa copia fallida; nunca se limpia el original. Si varias
entradas aparecen por intervención de otros callbacks, no se elige ni elimina
ninguna arbitrariamente y se informa al DJ.

## Borrador y confirmación

Se capturan los controles de colecciones en su tabla de borrador y se comparan
todos los campos y colecciones con DB, utilizando la misma normalización de
colecciones vacías y números que el guardado. No basta con comparar versiones.

Con cambios pendientes se abre `DialogManager.openDialog("dialog_okcancel", …)`.
Continuar copia la última versión persistida en ese momento. Cancelar o cerrar
el diálogo no escribe nada. El borrador original se conserva en ambos casos.
Cerrar la ficha original mientras el diálogo está abierto invalida el callback.

## Altas todavía sin confirmar

CoreRPG persiste el nodo al pulsar Añadir, antes de Guardar. Su mera existencia
o una versión 1 no permiten distinguir una ficha nueva de una plantilla guardada
sin cambios o de una copia válida.

Se registra por ello una marca privada en:

`aptus_equipment_metadata.unconfirmed.<nombreNodo> = template_id`

Sólo las altas sin identidad previa la reciben; la duplicación nativa no. Después
de un Guardar satisfactorio, la interfaz confirma el alta retirando esa marca,
también si Guardar no incrementó versión porque no había cambios. No se modifica
el algoritmo de guardado/restauración ni la plantilla exportable. Descartar no
retira la marca. Permanece al cerrar y reabrir la ficha/campaña.

Las plantillas de campañas anteriores, sin marca, se consideran ya persistidas:
no puede reconstruirse retroactivamente si el usuario pulsó Guardar alguna vez.
Los módulos también son plantillas persistidas; el DJ puede duplicarlos con el
mismo mecanismo nativo. El bloqueo del original no impide copiarlo. Los clientes
no pueden ejecutar la duplicación.

## Validación

Comprobados estáticamente XML/referencias, bloques Lua, dimensiones y presencia
del duplicador/diálogo nativos, sin autosave. La suite aislada se amplía con marcas
de alta, primer Guardar sin cambios, detección de borradores y verificación de
copia. No se ha ejecutado Lua ni FGU: no están disponibles en el entorno.

Pruebas pendientes en FGU:

1. Crear plantilla: botón visible pero deshabilitado. Descartar no lo habilita.
   Cerrar/reabrir sin guardar mantiene ese estado.
2. Guardar sin cambios iniciales: versión 1, botón habilitado. Reiniciar campaña
   cuando corresponda y confirmar que el estado persiste.
3. Guardar una plantilla con imagen, propiedades, requisitos, varios perfiles y
   cualidades generales/específicas referenciadas por quality_id. Anotar ID/versión originales.
4. Sin cambios pendientes, Crear copia: no pide confirmación y abre la nueva
   ficha con ID diferente, versión 1 y propiedades conservadas. El bloqueo nativo
   de la copia se comporta igual que al duplicar desde el catálogo.
5. Modificar campos escalares y colecciones sin guardar. Crear copia y Cancelar:
   no hay registro nuevo y el borrador sigue intacto.
6. Repetir y Continuar: la copia contiene los valores guardados, no los cambios
   pendientes. El borrador original y su ID/versión permanecen intactos.
7. Editar/guardar la copia: original sin cambios. Repetir desde cada pestaña.
8. Probar desde un módulo de sólo lectura y con una plantilla antigua sin los
   campos generales de requisitos: copia válida con predeterminados aditivos.
9. Con un cliente jugador, comprobar botón deshabilitado. Cerrar la ficha del DJ
   con la confirmación abierta y aceptarla después: no crea copia.
10. En un entorno de prueba, provocar un fallo de duplicación: mensaje privado,
    ninguna apertura incompleta y original intacto. Revisar posibles copias
    fallidas si un error DB impidió retirarlas.

No se ha recargado ni reiniciado FGU durante el desarrollo.
