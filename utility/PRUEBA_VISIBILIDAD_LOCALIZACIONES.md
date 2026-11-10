# Prueba temporal de Visibilidad de Localizaciones

Esta prueba se ejecuta en el anfitrión mediante `/aptusvis`. No cambia los CTA,
las ventanas principales ni los permisos de Acceso. Sus mensajes se muestran
localmente al DJ mediante `ChatManager.SystemMessage`.

## Activación y retirada

Recargar APTUS Character Sheet o reabrir la campaña. El script se registra desde
`extension.xml` como `APTUSLocationVisibilityTest`, sólo en el anfitrión.
Para desactivar la prueba, retirar esa inclusión y recargar la campaña.
Esto no revoca las concesiones nativas efectuadas durante la prueba.

## Comandos

1. `/aptusvis listar`: muestra los nombres y rutas de las Localizaciones de campaña.
2. `/aptusvis seleccionar aptus_structures.id-00001`: seleccionar la ruta real
   obtenida en el paso anterior. No escribe ni abre la localización.
3. `/aptusvis estado`: consultar selección, ruta, propietario, estado público,
   conectados y destinatarios. También permite consultar conectados sin selección.
4. `/aptusvis dar UsuarioA`: concede lectura a ese usuario conectado mediante
   `DB.addHolder(node, username, false)`.
5. `/aptusvis quitar UsuarioA`: retira únicamente ese destinatario mediante
   `DB.removeHolder`. Acepta usuarios conectados o destinatarios ya registrados,
   incluidos desconectados.
6. `/aptusvis limpiar`: olvida la selección temporal; no cambia destinatarios.

Usar el nombre de usuario exacto que muestra `estado`, sin comillas y no el nombre
del personaje. Se admite el nombre completo con espacios. Una selección inválida
borra la selección anterior para evitar operar accidentalmente sobre ella.

El registro debe ser una Localización APTUS existente, de campaña, editable,
no pública y sin propietario jugador. La prueba no cambia su estado público,
propietario ni candado. Una ficha bloqueada mediante `locked` puede recibir
destinatarios: compartir no concede edición.

## Interpretación del diagnóstico

Cada intento válido sobre la selección informa del estado antes y después.
`RECHAZADA` significa que no se ha solicitado ninguna escritura.
`VERIFICADA EN ANFITRIÓN` significa que la relectura muestra el destinatario
esperado, sin alterar los demás destinatarios, propietario o estado público.
`NO VERIFICADA` requiere revisar los datos posteriores y cualquier error mostrado.
No se aplican restauraciones automáticas.

Una verificación en anfitrión NO confirma que el cliente haya recibido el cambio,
que su ventana se haya cerrado o que la autorización persista tras un reinicio.

## Procedimiento con dos clientes

Preparación: abrir la campaña con el DJ y conectar UsuarioA y UsuarioB. Utilizar
una localización de prueba no pública y sin propietario jugador. Anotar sus
destinatarios iniciales y seleccionarla explícitamente. No pulsar Compartir ni
arrastrar el registro sobre un usuario o el chat durante estas pruebas: esos
mecanismos pueden conceder permisos y alterar el resultado.

### A. Concesión individual

- Partir de A y B sin Visibilidad (si ya son destinatarios, retirarlos uno a uno
  mediante la prueba, únicamente si forman parte de la preparación autorizada).
- Ejecutar `dar UsuarioA` y consultar `estado`.
- A debe poder consultar la localización desde su índice. B no debe obtenerla.
- Comprobar que B no aparece añadido entre los destinatarios.

### B. Revocación con ventana abierta

- Ejecutar `dar UsuarioB`; ambos deben poder consultar la localización.
- A abre la localización y conserva una referencia en una tecla rápida.
- Ejecutar `quitar UsuarioA` y consultar `estado`.
- Comprobar si la ventana de A se cierra y si su entrada desaparece del índice.
- B debe seguir pudiendo consultar la misma localización.

### C. Reconexión

- Conceder a A, desconectarlo y volverlo a conectar con el mismo usuario.
- Consultar `estado` y comprobar desde A que conserva Visibilidad.
- La desconexión no ejecuta ninguna retirada desde el script de prueba.

### D. Persistencia

- Conceder a A y registrar el diagnóstico.
- Cerrar normalmente la campaña y volverla a abrir; reconectar los clientes.
- Volver a seleccionar la ruta (la selección de depuración no persiste).
- Consultar destinatarios y verificar la lectura desde A.

### E. Referencia directa

- Con A autorizado, conservar una referencia en su tecla rápida.
- Retirar su Visibilidad y pulsar después esa referencia desde A.
- Comprobar que no recupera los datos de la localización y releer destinatarios.
- No reenviar la referencia desde el DJ: podría compartir de nuevo el registro.

### F. Lectura sin edición

- Conceder a A con el comando de prueba.
- Verificar en el diagnóstico que no se convierte en propietario.
- Desde A intentar editar nombre, Ubicación, Descripción y sustituir la imagen.
- Verificar desde el DJ que los datos no cambian y que los CTA exclusivos del DJ
  no se habilitan para A.

## Pruebas de rechazo

- Registro público: seleccionar una localización ya pública y probar `dar` y
  `quitar`; debe rechazarlos sin convertirla a privada ni cambiar destinatarios.
- Propietario jugador: con un registro preparado en ese estado, ambos comandos
  deben rechazarse sin cambiar propietario ni permisos.
- Seleccionar un Vehículo, una nota o una ruta inexistente: debe rechazarse.
- Usuario desconocido: no debe concederse Visibilidad ni crear un destinatario.
- Comando ejecutado en un cliente: no se registra allí y el manejador contiene
  además una comprobación de anfitrión. No existe receptor OOB de esta prueba.
- Repetir una concesión o retirada ya aplicada: debe informar de que el estado
  ya existía y no llamar otra vez a la operación de escritura.

## Registro de resultados

Para A–F, anotar: resultado del anfitrión, resultado observado en A, resultado
observado en B y cualquier error de FGU. Las comprobaciones multijugador quedan
pendientes hasta ejecutar esta matriz en una sesión real.
