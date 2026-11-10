# Prueba de Almacenaje provisional y Acceso

No se ha recargado ni reiniciado FGU durante el desarrollo. Los cambios de archivo
no sustituyen el código ya cargado en la sesión actual. Cargar esta versión cuando
el DJ decida iniciar las pruebas; después, alternar estados no requiere recargar.

## Datos y privacidad

- Activación: `aptus_structures.<id>.features.storage.enabled`, compartido junto
  con la localización y administrado por el DJ.
- Concesiones: `aptus_location_permissions.<id>.access.<id>.username`, privadas.
- Proyecciones: `aptus_location_user_states.<id>` con referencia `structure` y
  `access=1`. Cada nodo recibe un único destinatario sin propiedad. No incluye
  nombres ni listas de otros jugadores. Es información derivada, no otra autoridad.
- Al retirar Acceso se elimina su proyección; al reconcederlo se vuelve a publicar.
- Se migran las concesiones antiguas de `aptus.access` únicamente en Localizaciones
  de campaña editables y sin propietario jugador. Tras copiar y verificar se
  elimina el nodo antiguo. Los datos ya vistos por clientes no pueden borrarse
  retroactivamente de su conocimiento.

## Circuito desde el DJ y dos clientes A/B

1. Seleccionar una localización privada y conservar otra como control.
2. Conceder Visibilidad a A sin Acceso. A puede consultar Principal, no Almacenaje.
3. Activar Almacenaje en Configuración → General. El DJ ve su pestaña; A no.
4. Conceder Acceso a A. Verificar ambas casillas y aparición de Almacenaje en A.
5. A abre Almacenaje. Retirar Acceso: conserva Visibilidad y vuelve a Principal.
6. Reconceder Acceso y abrir Almacenaje. Desactivar la funcionalidad: desaparece
   para todos, sin borrar Acceso. Reactivarla: reaparece para DJ y A.
7. Retirar Visibilidad a A con la casilla o `/aptusvis`: también pierde Acceso.
8. Repetir concesiones: no aparecen filas duplicadas ni se concede propiedad.
9. Con B conectado y un usuario conocido desconectado, pulsar «Dar acceso a todos».
   Sólo los conectados reciben concesiones. Repetir no debe crear duplicados.
10. Comprobar que B sólo recibe su propia proyección y no la lista privada.
11. Desconectar y reconectar A sin tocar permisos: conserva su concesión y obtiene
    el estado actual. Comprobar persistencia en una prueba posterior de campaña.
12. La otra localización debe mantener sus estados independientes. Vehículos,
    personajes, notas, skin y `/aptusvis` deben conservar su funcionamiento.

Almacenaje muestra únicamente un título y un mensaje provisional. No hay objetos,
transferencias ni datos sensibles. El filtrado de pestañas no constituye una
autorización de inventario. Las futuras operaciones deberán validarse en anfitrión.

Pendiente en FGU: orden de recepción de datos, retirada de proyecciones, vuelta
automática a Principal con la pestaña abierta, reconexión, persistencia y aislamiento
entre dos usuarios. Las comprobaciones estáticas no confirman estos resultados.
