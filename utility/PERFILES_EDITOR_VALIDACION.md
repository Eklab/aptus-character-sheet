# Editor compacto de perfiles de combate

La pestaña Combate mantiene su ancho exterior. Las cabeceras comunes ocupan 18 px;
las filas utilizan 411 px, dejando espacio para el scrollbar dentro de los 426 px
de la lista. La fila completa abre la configuración y conserva el icono existente.

| Columna | Ancho asignado |
|---|---:|
| Nombre | 72 px |
| Habilidad | 67 px |
| ALC | 26 px |
| DAÑO | 50 px |
| CRI | 27 px |
| MUN | 28 px |
| N.MUN | 38 px |
| Cualidades | 103 px |

Se reservan márgenes de 2 px dentro de cada columna. Cualidades comparte su zona
con el indicador de apertura de 25 × 24 px; el texto queda acotado a 72 px.
No se reduce la fuente de 12 px ni se amplía el editor principal.
La lista conserva el margen izquierdo de 204 px y alcanza los 630 px del panel;
cabeceras y celdas utilizan la misma geometría. Fondo y superficie pulsable parten
de un anclaje izquierdo explícito con offset=-10 y miden 421 px. El extremo
derecho permanece en x=411. Se evita `bounds` con x negativa, que puede interpretarse
respecto al extremo derecho. Los textos y el icono (x=384) mantienen su posición.
La actualización dinámica sólo cambia la altura y conserva estos anclajes.

Nombre y cualidades se envuelven según la anchura medida con widgets nativos;
cada cualidad comienza en una línea nueva. DAÑO destaca el dado a 14 px y muestra
debajo las abreviaturas del catálogo en orden, o un guion cuando no hay tipos.
La altura varía de 36 a 64 px (hasta cuatro líneas). Cada bloque se mide mediante
`widget.getSize()` y se centra con `(alturaFila - alturaBloque) / 2`. El dado y
las abreviaturas se consideran un único bloque. El contenido que excede
el máximo se recorta según sus métricas reales. Los tooltips conservan los valores completos,
los nombres de tipos de daño y las descripciones de cualidades.

La configuración mide 520 × 420 px tras añadir la fila condicional de munición.
La tabla incorpora un pie opcional de 16 px para consumo/capacidad; el cuerpo
conserva el máximo de 64 px. Véase `MUNICION_EQUIPO.md` para el contrato y las pruebas.
Se organiza en DATOS DEL PERFIL, CUALIDADES y
TIPOS DE DAÑO; conserva la cuadrícula 3 × 3. Las nuevas fuentes locales de 12/14 px
usan beige claro sobre fondo oscuro. Los valores dentro de campos claros conservan
su fuente oscura anterior, al igual que el texto sobre el botón gris de cualidades.
No se modifican fuentes compartidas ni imágenes.

## Borrador y ciclo de vida

- La configuración reutiliza `equipment_profile_aptus.lua` y todos sus controles,
  incluidos alcance, munición, cualidades y las nueve casillas de daño.
- Fila y formulario reciben la misma tabla de perfil del borrador principal.
- Cerrar la configuración captura sus controles en esa tabla, sin escribir DB.
- Guardar captura la configuración antes de usar el guardado existente del editor.
- Descartar reconstruye las filas desde los datos persistidos, cerrando las ventanas
  anteriores e invalidando los callbacks de cualidades y eliminación pendientes.
- Hay una configuración activa a la vez. Abrir otro perfil cierra la anterior,
  conservando sus cambios en su borrador. Cerrar el editor principal cierra la auxiliar.
- Bloquear cierra la configuración después de capturar los cambios del borrador.
- Añadir crea el perfil en el borrador, reconstruye la lista y abre su configuración.
- Eliminar solicita confirmación nativa y afecta sólo al borrador. El guardado y
  descarte principales mantienen sus responsabilidades anteriores.
- No se añaden campos, rutas DB, imágenes ni operaciones de inventario.

## Comprobaciones disponibles

Desde la raíz de Character Sheet:

```text
node utility/tests/profile_editor_static_test.js
node utility/tests/damage_types_static_test.js
node utility/tests/inventory_instance_static_test.js
node utility/tests/item_melee_consultation_static_test.js
```

Estas pruebas verifican estructura, referencias, balance léxico, coordinación de
ventanas y ausencia de escrituras propias; no ejecutan el motor de FGU.

## Validación manual en FGU

Realizar en una campaña de prueba, tanto con plantilla como con instancia:

1. Abrir un objeto con varios perfiles; desbloquear y entrar en Combate.
2. Pulsar distintas zonas de cada fila; comprobar nombre, habilidad, modificador,
   daño, crítico, tipos de daño y cualidades, incluidos textos largos y tooltips.
3. Editar todos los campos, alcance y munición; seleccionar varios tipos de daño
   y configurar cualidades. Cerrar y comprobar el resumen; reabrir y comprobar valores.
4. Abrir otro perfil y verificar que el anterior conserva sus cambios pendientes.
5. Guardar con la configuración abierta; reabrir el objeto y verificar persistencia.
6. Editar y Descartar con la configuración abierta; comprobar cierre y recuperación
   de los valores guardados, sin que callbacks pendientes cambien el nuevo borrador.
7. Añadir un perfil; comprobar apertura automática. Descartar y comprobar que desaparece.
8. Eliminar un perfil: cancelar conserva el perfil; confirmar lo quita del borrador.
   Descartar lo recupera; repetir y Guardar hace persistir la eliminación.
9. Bloquear con cambios pendientes; comprobar cierre de la configuración y conservación
   del borrador según el comportamiento existente del editor.
10. Cerrar el editor principal con una configuración abierta; comprobar que no quedan
    ventanas auxiliares ni diálogos capaces de aplicar cambios al borrador descartado.
11. Con el candado cerrado, verificar que la consulta especializada de Arma C.C.
    conserva sus tarjetas y segunda línea de tipos de daño y cualidades.
12. Confirmar que cerrar sólo la configuración no cambia los datos persistidos.
13. Verificar cabeceras únicas y alineación de las ocho columnas, con varios perfiles
    consecutivos y scrollbar. Comprobar que no quedan cabeceras visibles en otras pestañas.
14. Probar nombres cortos, de dos líneas y excepcionalmente largos; habilidades con
    modificadores positivos, negativos y cero; valores largos de alcance y cargador.
15. Probar cero, uno, dos y los nueve tipos: comprobar orden y abreviaturas, recorte
    en tres líneas como máximo y acceso a todos los nombres mediante tooltip.
16. Probar cualidades ausentes, varias y numerosas; comprobar altura variable sin
    solapamientos y tooltip con descripciones. Pulsar todos los extremos de la fila.
17. Comprobar el contraste de etiquetas, valores, casillas marcadas y desmarcadas,
    y el texto del CTA «Configurar cualidades» en la configuración ampliada.
18. Verificar el fondo y su superficie pulsable entre x=-10 y x=411,
    sin desplazamiento de columnas, icono ni scrollbar.
19. Comprobar que los mensajes existentes de instancia aparecen dentro del recuadro
    inferior izquierdo: x=22, ancho=148, centrado vertical entre y=367 e y=411.
    La presentación admite hasta dos líneas visibles y conserva el tooltip original.
20. En consulta Arma C.C., comprobar los cuatro valores de primera línea en y=6
    (antes y=2). Los tres títulos tienen margen izquierdo de 10 px, anclado a su
    fondo; nombre de perfil, otras columnas y segunda línea conservan sus posiciones.
21. En consulta no debe existir `profile_fill` ni ningún relleno blanco/gris añadido.
    Se conserva el PNG original del perfil con su interior, bordes y separadores.
    Se han revertido `profile_horizontal`, `aptus_melee_section_frame` y sus anclajes:
    esa composición precedió a la regresión observada en FGU. Se recuperan iconos
    directos y bounds explícitos de la versión anterior: barras de 392 px y
    cabecera/perfiles de 393 px, todos con inicio global x=239. Se acepta la
    diferencia nativa de 1 px para priorizar estabilidad, sin escalar imágenes.
    Alturas: barra 25 px, cabecera 24 px, perfil 52 px; separación de perfiles 6 px.
    Verificar con uno y varios perfiles, incluyendo la barra final de cualidades.
    El título Propiedades de combate conserva x=219 sólo en Combate (original x=224).

## Regresión de anclajes de la consulta

El fallo comunicado por FGU afecta a las barras sustituidas por marcos y a la lista
que pasó de bounds explícitos a una referencia invisible común. Las fotos y la
descripción, que mantuvieron sus bounds, siguieron visibles. No se dispone del log
de FGU ni de una ejecución local para distinguir qué parte del cambio fue el
desencadenante exacto. No se han encontrado referencias Lua restantes a controles
eliminados; no se modifica la creación de perfiles ni sus datos.

La prueba estática de consulta ya no acepta la nueva estructura por el mero hecho
de contener sus cadenas. Ahora exige los rectángulos positivos conocidos, recursos
directos y lista con clase y altura explícitas. Sus pruebas negativas rechazan la
referencia común, dimensiones nulas y sustitución por el marco local. Comprueba
también hashes de los PNG, márgenes de 10 px y ausencia de relleno adicional.
Esto detecta la reintroducción de estos cambios, no garantiza el renderizado nativo.

Validaciones funcionales ejecutadas en este entorno: ninguna (sin Lua ni FGU;
se mantiene la indicación del usuario de no instalar herramientas). La suite Lua
existente `inventory_instance_view_test.lua` conserva comprobaciones de configuración
de perfiles y cualidades, pendientes de ejecución en el entorno del usuario.

En FGU, después de /reload, abrir la misma instancia con Gran corte e Improvisada:
comprobar ambas barras, cabecera oscura, dos tarjetas con datos, barra final y
cualidades generales. Repetir con un solo perfil y suficientes perfiles para usar
el scrollbar. Confirmar imagen/descripción intactas, segunda línea visible, margen
de nombres de 6 px y ausencia de rectángulos blancos añadidos. Si persiste un fallo,
recoger el error de consola y los nombres de las extensiones/temas activos.

Pendiente: ejecución visual e interactiva en Fantasy Grounds Unity. No hay motor
FGU ni intérprete Lua disponibles en el entorno de comprobación.
