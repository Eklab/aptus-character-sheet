# Eliminación de instancias APTUS

Se adelanta exclusivamente la eliminación prevista para fase 7. No se implementan
otras fases, operaciones de pilas, Estado/Ubicación, transferencias, estructuras,
carga ni notificaciones generales. No hay migraciones, UUID adicionales o datos
automáticos. Se conserva el diseño de EQUIPO y la ficha de instancia.

## Operación y confirmación

`APTUSInventoryManager.canDeleteInstance(node)` comprueba instancia APTUS vigente,
personaje de campaña, permisos de propiedad/DJ y ausencia de sólo lectura en
personaje, inventorylist y registro. No consulta locked de la instancia ni del
personaje: los candados de propiedades no son permisos de inventario.

`planDeleteInstance(node)` sólo lee. Indexa los nodos físicos del inventorylist y
sus enlaces aptus.container por ID, valida ascendientes y prepara todo el subárbol
con una pila iterativa, sin límite lógico de profundidad. No usa nombres ni el
orden físico de los registros. Valida todos los candidatos antes de borrar nada.

`requestDeleteInstance(node, notify, isActive)` coordina el diálogo nativo
`DialogManager.openDialog("dialog_okcancel", {sTitle, sText, fnCallback})`, igual
que otras operaciones de confirmación de CoreRPG. La presentación del texto está
separada en getDeleteConfirmation; la ejecución es una función local privada y
no se expone un método público que omita la confirmación.

- Objeto o contenedor vacío: pregunta por su nombre persistido.
- Pila: muestra Nombre ×cantidad y advierte que se eliminan todas las unidades.
- Contenedor con contenido: advierte expresamente del borrado de todo el contenido
  anidado y muestra el total de registros, incluido el contenedor seleccionado.

Cancelar no escribe y conserva la ficha y el borrador. La ventana solicita al
gestor la operación, sin llamadas DB.deleteNode en el controlador visual.

## Revalidación y seguridad

Al confirmar se vuelve a preparar el plan y se comparan conjunto, identidad de
nodos, propiedades, cantidad y relaciones. El token ignora únicamente locked:
alternar el candado no invalida una confirmación de inventario.

Si cambia el contenido o cualquier dato de un registro afectado, no se borra nada
con esa confirmación. Se abre otra confirmación nativa actualizada, con aviso de
cambio, y se exige otro Aceptar. Si el nuevo plan es inválido, se informa y se
cancela sin ejecutar. Cambios irrelevantes fuera del subárbol no invalidan el plan.

Se rechazan referencias inválidas en los ascendientes, ciclos, hijos asociados a
un no contenedor, candidatos sin permisos y cualquier descendiente heredado o
incompatible. Un registro heredado fuera del subárbol se conserva y no se convierte.
Una inconsistencia ajena cuya relación es legible y no afecta al subárbol no se
corrige ni borra.

Límite conservador: si algún registro del inventario con marcador APTUS o campo
aptus.container tiene la relación ausente o de tipo ilegible, se bloquea la
operación completa. Sin una relación interpretable no se puede excluir que fuera
parte del contenido. Se debe revisar esa inconsistencia antes de volver a pedir
el borrado; no se repara automáticamente. El fixture de fase 1 contiene casos
inválidos deliberados y puede activar este rechazo.

Una confirmación sólo se consume una vez. La ventana evita solicitudes duplicadas
mientras el diálogo está pendiente. Cerrar la ficha antes de responder invalida la
solicitud, incluso si su diálogo estaba en la cola nativa. No se guarda el borrador
al solicitar, cancelar o ejecutar la eliminación.

## Ejecución y errores

Se eliminan las hojas antes que sus padres, revalidando cada registro y verificando
su desaparición. Antes de eliminar un padre se comprueba que no quede ningún hijo
asociado. El gestor utiliza sólo DB.deleteNode sobre los registros confirmados.
No llama a ItemManager ni produce avisos de traslado o cambios de Estado.

No hay transacción general ni recreación automática de nodos borrados. Si falla
una escritura o cambia un registro durante la ejecución, se detiene el proceso.
El mensaje informa cuántos registros se eliminaron y cuántos se habían previsto;
los contenedores todavía pendientes se conservan. Lo ya eliminado no se restaura.
La causa técnica se registra en Debug.console y la ventana presenta un mensaje
local comprensible. Reintentar exige una nueva planificación y confirmación.

## Refresco y cierre de ventanas

Eliminar permanece visible y se habilita por permisos propios de inventario,
independientemente del candado. Mientras se confirma, se desactiva sólo ese botón.

Se reutilizan observadores existentes:

- Cada ficha aptus_inventory_item observa onDelete de su nodo y se cierra. Esto
  incluye las fichas de todos los descendientes borrados, en cada cliente que
  reciba la actualización DB. Sus observadores se retiran al cerrar.
- EQUIPO observa onChildDeleted de inventorylist y otros cambios del registro,
  y reconstruye las filas. No se añade otro canal de sincronización.
- El callback de éxito cierra la ficha si todavía sigue abierta. Cancelar mantiene
  la ficha y el borrador; errores se muestran en su panel local.

La persistencia y sincronización de los borrados son las nativas de DB de Fantasy
Grounds; deben comprobarse también con un jugador propietario conectado.

## Archivos de esta intervención

Modificados:

- scripts/manager_aptus_inventory.lua: permisos, planificación, confirmación,
  revalidación y ejecución privada.
- scripts/record_inventory_item_aptus.lua: solicitud de eliminación, bloqueo de
  doble pulsación y mensajes de cancelación/error locales.
- scripts/inventory_item_window_aptus.lua: comentario del cierre onDelete existente.
- campaign/record_inventory_item_aptus.xml: activación y callback de Eliminar,
  conservando posición, tamaño, texto y recursos del botón.
- utility/tests/inventory_create_test.lua: pruebas DB en memoria de eliminación,
  reutilizando su doble de DB y controladores reales de ventanas/observadores.
- utility/tests/inventory_instance_view_test.lua: actualización del doble del gestor
  y del control Eliminar para conservar las pruebas de presentación.
- utility/tests/inventory_instance_static_test.js: contrato y referencias actuales.
- utility/INVENTARIO_FASE_2.md: referencia a la funcionalidad adelantada.

Creado: utility/INVENTARIO_ELIMINACION.md.

## Pruebas

Ejecutado y superado:

    node utility/tests/inventory_instance_static_test.js
    node --check utility/tests/inventory_instance_static_test.js

Verifica balance léxico de nueve Lua, etiquetas XML y referencias, geometría de
los botones, callback delegado al gestor, uso de confirmación nativa, revalidación,
cierre por onDelete y conservación de campos estructurales/protecciones de edición.
El balance léxico no sustituye a un parser Lua ni al motor FGU.

Preparado pero NO ejecutado aquí por falta de Lua/luac y FGU:

    lua utility/tests/inventory_read_test.lua
    lua utility/tests/inventory_create_test.lua
    lua utility/tests/equipment_save_test.lua
    lua utility/tests/inventory_instance_view_test.lua

La suite inventory_create_test incluye objeto individual/cancelación, pila completa,
contenedor vacío, subárbol de seis registros sin orden físico, cadena de 300 niveles,
nombres duplicados, referencias inválidas, hijo heredado, no contenedor con hijos,
ciclos, relación ilegible, inserción/cambio de cantidad/movimiento mientras se
confirma, cambio del candado, permisos de jugador propietario/ajeno, descendiente
sin permisos, revocación durante el diálogo, ficha cerrada y fallo parcial de DB.
Compara registros ajenos antes/después. Carga el controlador real de ventana para
comprobar cierre por onDelete y los observadores reales de EQUIPO con renderizado
sustituido por un contador. No se ejecuta ni se incluye ninguna prueba en la extensión.

## Validación concreta en Fantasy Grounds

Usar exclusivamente una campaña de prueba. No modificar manualmente relaciones en
una campaña real. No se insertan fixtures al abrir ni se solicita importar nada
automáticamente.

1. Crear dos instancias individuales desde una plantilla, con el mismo nombre.
   Abrir ambas, cerrar el candado de una y pulsar Eliminar: debe pedir confirmación.
   Cancelar: ambas conservan nodos, propiedades y borradores. Confirmar otra vez:
   sólo desaparece la seleccionada y su ficha se cierra; la homónima sigue intacta.
2. Probar la misma operación con candado abierto. Guardar/Descartar y la edición
   de propiedades mantienen su funcionamiento anterior.
3. Preparar manualmente, sólo en datos de prueba, una pila con count=5. Confirmación
   muestra ×5 y todas las unidades; cancelar conserva count=5. Confirmar elimina
   el registro completo; no se ofrecen borrado parcial, división ni apilamiento.
4. Crear un contenedor vacío y borrarlo con confirmación individual.
5. Para relaciones anidadas, usar datos de prueba coherentes con aptus.container,
   sin añadir controles de ubicación: Mochila → Bolsa → Caja → Documento, con
   Botiquín en Bolsa y Linterna en Mochila. No importa el orden físico de los IDs.
   Abrir fichas de Mochila, Documento y un objeto ajeno al subárbol.
6. Eliminar Mochila: debe anunciar seis registros y contenido interior. Cancelar
   no cambia nada. Confirmar cierra las fichas de todos los objetos borrados,
   elimina sus seis filas y conserva objetos y fichas ajenos.
7. Desde un segundo cliente, añadir o modificar un descendiente persistido durante
   la confirmación. Aceptar el diálogo anterior no debe borrar nada: debe aparecer
   una nueva confirmación actualizada. Cancelarla conserva el contenido actualizado.
   Aceptar la nueva sí lo elimina. Repetir quitando un objeto del subárbol en los
   datos de prueba: ese objeto ya no debe estar incluido ni ser eliminado.
8. Probar ciclos, padre inexistente, enlace ilegible e hijo heredado asociado a un
   contenedor, sólo mediante fixtures/campañas aisladas: deben rechazarse sin borrar.
   Comprobar que una inconsistencia no se repara o convierte automáticamente.
9. Como jugador propietario normal, crear y eliminar instancias propias. Como
   jugador sin propiedad o con registro de sólo lectura, Eliminar no debe permitir
   el borrado. Revocar permisos mientras se confirma: Aceptar no debe eliminar.
10. Cerrar la ficha con confirmación pendiente y después aceptarla: no borrar nada.
    Probar pulsación repetida de Eliminar: una única solicitud pendiente.
11. Usar suficientes registros para mostrar scrollbar y búsqueda/filtro activos:
    tras eliminar no quedan filas fantasma ni fichas de descendientes inexistentes.
    Repetir con la ficha de un descendiente abierta en otro cliente con acceso.
12. Reiniciar la campaña: borrados persisten; objetos ajenos mantienen sus datos.
    No aparecen avisos de traslado, cambios de Estado ni notificaciones generales.

Los fallos parciales se simulan en la suite DB en memoria; no provocar fallos de
almacenamiento ni pérdida de permisos durante borrados en campañas reales.
