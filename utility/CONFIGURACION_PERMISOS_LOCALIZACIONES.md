# Configuración de Localizaciones — Visibilidad y Acceso

## Estado de activación

La pestaña «Permisos» habilita Visibilidad y Acceso para pruebas desde el DJ. La ventana
abre en «General» y conserva el skin LANE. Su tamaño inicial y mínimo es 650 × 550.
«General» muestra tipo, Seguridad, Almacenaje y Sistemas; el filtro es visual y
no modifica las funcionalidades ni la interfaz de Vehículos.
Las casillas individuales y ambos CTA masivos utilizan el gestor existente.
Acceso implica Visibilidad; retirarlo conserva Visibilidad. Sólo el DJ escribe.
Almacenaje es configurable sólo en Localizaciones y todavía no contiene inventario.

Las escrituras visuales sólo nacen de `onButtonPress`, nunca de `onValueChanged`.
La interfaz agrupa los eventos durante la operación y reconstruye la tabla al
final con los permisos reales, también ante rechazos o errores. No hay un nuevo
comando ni receptor OOB. Acceso se administra desde el gestor existente.

`/aptusvis` y el botón Compartir actual conservan sus implementaciones. Compartir
todavía puede hacer pública la localización. No utilizarlo durante la matriz de
pruebas individuales de la fase 1.

## Datos

- `aptus_known_users.<id>.username`: cuentas conocidas, sin personajes ni estado
  de conexión persistido. Escrituras exclusivamente desde el anfitrión.
- `aptus_location_permissions.<id>.structure`: referencia a la localización.
- `aptus_location_permissions.<id>.access.<id>.username`: concesiones positivas,
  privadas del anfitrión. Las asociaciones de proyecciones están bajo `views`.
- `aptus_location_user_states.<id>`: proyección derivada con `structure` y
  `access=1`, compartida únicamente con su destinatario, sin nombres de usuarios.
- `aptus_structures.<id>.features.storage.enabled`: activación persistente.

La migración autorizada copia las concesiones antiguas de `aptus.access`, verifica
sus valores y sólo después elimina esa colección de la estructura compartida.
No se migran automáticamente registros de módulos/solo lectura o con propietario
jugador. En cada cliente la ausencia de una proyección propia implica sin Acceso.
- Visibilidad: estado público, propietario y destinatarios nativos. No se copia
  esa información a campos propios.

El registro se inicializa con conectados y los usuarios recuperables de
destinatarios, propietarios y concesiones existentes de Localizaciones. No
reconstruye usuarios históricos sin ningún dato recuperable. Al conectar añade
cuentas nuevas sin duplicarlas; al desconectar las conserva. El anfitrión queda
fuera de la tabla.

## Operaciones internas

El gestor expone `hasVisibility`, `hasAccess`, `setVisibility`, `setAccess`,
`grantVisibilityToConnected` y `grantAccessToConnected`.

Las escrituras rechazan clientes, nodos inexistentes o de otra categoría,
propietarios jugadores, registros de módulos/solo lectura y usuarios desconocidos.
Visibilidad se concede con `DB.addHolder(node, username, false)`. No se publica ni
se concede propiedad. No hay conversión automática de registros públicos.

Acceso efectivo requiere Visibilidad. Activarlo concede primero Visibilidad;
retirarlo conserva Visibilidad. Una retirada de Visibilidad elimina sus concesiones
de Acceso. El observador del anfitrión también limpia concesiones positivas que
hayan perdido Visibilidad por cambios nativos externos, sin modificar destinatarios.
La desconexión no retira permisos.

Los CTA masivos preparados toman los usuarios conectados del momento; no recorren
desconectados ni dejan un indicador permanente para futuras conexiones. Sus
resultados internos describen el estado del anfitrión, no una confirmación remota.

La primera integración se limita a Localizaciones. Se usa la arquitectura común
de estructuras sin habilitar cambios en Vehículos.

## Pruebas de consulta en FGU

1. Cuando el DJ decida cargar esta versión para pruebas posteriores, abrir el
   engranaje de una Localización. No recargar la sesión actual durante el desarrollo.
2. Comprobar tipo y funcionalidades en «General» (seleccionada inicialmente).
3. Abrir «Permisos» y comprobar la tabla: conectados primero, después orden
   alfabético. Alternar páginas no debe cambiar datos ni reiniciar su contenido.
4. Marcar/desmarcar Visibilidad de un usuario y contrastar los destinatarios con
   `/aptusvis estado`. Comprobar que los demás usuarios no cambian. Acceso debe
   reflejar el permiso real.
5. Conectar y desconectar un cliente: la fila permanece y cambia su indicador.
6. Usar `/aptusvis` para conceder y retirar Visibilidad: la tabla debe reflejar
   destinatarios reales, sin crear concesiones de Acceso al conceder sólo lectura.
7. Con una localización pública preparada, comprobar el aviso y Visibilidad
   efectiva para todos los usuarios conocidos. No se convierte a privada.
8. Reabrir la campaña: se conservan las cuentas conocidas, no el estado de conexión.
9. Comprobar que jugadores no pueden abrir Configuración y que Vehículos y
   Principal mantienen su presentación y comportamiento.
10. Pulsar «Dar visibilidad a todos»: sólo concede a los conectados. Repetir y
    comprobar que no cambia propietario, estado público ni Acceso, y que conserva
    los permisos de desconectados.
11. Intentar retirar Visibilidad de un registro público: debe rechazarse y
    restaurarse la casilla al estado real, sin convertir el registro a privado.

El usuario ha confirmado en FGU la concesión/retirada mediante `/aptusvis` y el
refresco automático de la tabla desde el anfitrión. La activación de los nuevos
controles y las proyecciones individuales aún necesitan prueba en FGU. La recepción/revocación efectiva en el
cliente remoto continúa pendiente; no se deduce de la casilla del anfitrión.

## Límites

- Un registro público no permite revocación individual de Visibilidad.
- Las cuentas se identifican por su nombre exacto. Un cambio de nombre de cuenta
  no reasigna permisos automáticamente.
- El gestor no delega propiedad a jugadores. No debe darse propiedad del registro
  ni de sus permisos a un cliente por otro mecanismo.
- Las comprobaciones de Acceso de clientes sólo sirven a la presentación del
  usuario local. Las futuras operaciones restringidas deberán autorizarse también
  en el anfitrión; esta fase no implementa esas funcionalidades.
