# Ajustes visuales de CUALIDADES y EQUIPO

- CUALIDADES: tamaño inicial y mínimo 600 × 520, redimensionable. Conserva record_window y sus controles nativos. Marco aptus_lane_aux_recordsheet y paneles aptus_lane_aux_groupbox, con los mismos offsets de Configuración (10 y 15). No cambia otras ventanas.
- Sección General: nombre a todo el ancho, descripción multilínea con scroll propio y seis tipos distribuidos en dos columnas. Los tipos adicionales registrados siguen disponibles en la segunda lista desplazable.
- Borrar y Guardar reutilizan las imágenes secundaria y primaria de EQUIPO (124 × 28 y 119 × 28). Borrar conserva la confirmación del catálogo.
- aptus_delete.png (27 × 25) registrado como aptus_delete: botones de 29 × 27 en perfiles y asociaciones compartidas por EQUIPO y el diálogo de perfiles. Se conserva window.remove(), sin guardado automático.
- Configurar usa el fondo secundario existente a tamaño nativo, en la tercera fila del perfil. Las otras dos filas mantienen sus campos y anchos.
- Ver utiliza aptus_lupa.png (27 × 25), alineado con aptus_delete en controles de 29 × 27, con tooltip «Ver cualidad». El manejador de consulta permanece intacto.
- aptus_add conserva su identificador y apunta a aptus_add_2.png (27 × 25). Esto actualiza también los editores de atributos y habilidades que reutilizan ese recurso; no cambia sus controles ni acciones.
- El diálogo de asociaciones mide 500 × 350, con marco LANE, paneles de pergamino, lista de cinco filas desplazable y botones gráficos Descartar/Guardar. La X cierra sin aplicar cambios pendientes. Guardar sigue aplicando únicamente al borrador de EQUIPO.
- EQUIPO permanece en 650 × 433. No se modifican PNG, modelos, gestores ni manejadores de asociaciones.

## Comprobación manual en FGU

1. Abrir CUALIDADES y comprobar marco metálico, pergamino, encabezado, sección General y ausencia de scroll exterior con los seis tipos. Redimensionar y revisar anchos y márgenes.
2. Editar nombre y descripción larga; marcar varias clasificaciones, guardar y reabrir. Comprobar los mismos identificadores y filtros del catálogo.
3. Pulsar Borrar: cancelar primero y confirmar después sobre una cualidad de prueba. Verificar que un registro de módulo de solo lectura no permite editar ni borrar.
4. En EQUIPO crear varios perfiles: comprobar las tres filas, ausencia de solapamientos y el botón Configurar. Revisar los iconos de eliminar y su zona de clic.
5. Retirar un perfil y una asociación general sin guardar; Descartar debe recuperarlos. Repetir en el diálogo del perfil, confirmando al borrador y descartando después EQUIPO. La definición del catálogo debe permanecer intacta.
6. Comprobar Ver, arrastrar cualidades, referencias inaccesibles y recuperación al activar módulos. Guardar, descartar y Crear copia deben mantener el comportamiento y versionado anteriores.
7. Revisar Localizaciones, Vehículos y otras ventanas: no deben cambiar de apariencia.

Las comprobaciones estáticas no sustituyen la carga XML/Lua, el renderizado ni la interacción en Fantasy Grounds Unity.

## Validación de iconos y diálogo en FGU

Comprobar el nuevo + en ambas pestañas de EQUIPO y en los editores que comparten aptus_add. Consultar una cualidad mediante la lupa y probar una referencia inaccesible. Retirar asociaciones y comprobar que el catálogo permanece intacto. En el diálogo añadir más de cinco asociaciones y revisar scroll, contraste y tooltips. Cancelar con Descartar y con la X, verificando que no cambia el borrador original; Guardar debe actualizar solo el borrador sin aumentar la versión de plantilla. Comprobar lectura sin permisos de edición: no debe aparecer Guardar ni su fondo.
