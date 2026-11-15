# CUALIDADES y perfiles horizontales de EQUIPO

## Catálogo y modelo

- Registro: `aptus_quality`.
- Campaña: `aptus_qualities.<registro>`.
- Módulos: `reference.aptus_qualities.<registro>@<módulo>` cuando corresponda.
- Campos: `quality_id` (inmutable), `name`, `description`, `types`.
- `types` serializa identificadores separados por `|`. Representa una lista,
  no un único tipo. Registro extensible: `APTUSQualityManager.registerType`.
- Clasificaciones iniciales: Personaje, Equipo, Armas CC, Armas de proyectiles,
  Localizaciones y Vehículos. No restringen asociaciones.

El índice, grupos, apertura, exportación y duplicación utilizan CoreRPG genérico.
No se usa `item` ni ItemManager. El filtro nativo `Tipo` tiene un `fGetValue` que
devuelve una tabla con todas las clasificaciones del registro: permite encontrar
una cualidad por cualquiera de ellas. Selección vacía significa todas. Las
opciones disponibles proceden de los registros del catálogo, como en el índice
nativo. El campo `types` también participa en su actualización de filtros.

El ID combina un espacio de nombres persistente, fecha de generación, componente
aleatorio y secuencia privada en `aptus_quality_metadata`. No depende del nombre
ni de la ruta del módulo. Las altas y duplicaciones independientes reciben un ID
nuevo; cargar módulos no reescribe IDs. La unicidad entre autores desconectados
es probabilística, reforzada por detección de colisiones, no un servicio central.
Una campaña clonada puede producir conflictos; nunca se renumeran silenciosamente.

La ficha común usa controles nativos y fuentes APTUS. Nombre, descripción y tipos
se editan mediante borrador; Guardar valida permisos y token de edición. El ID
no tiene control editable. Sólo el DJ puede editar registros de campaña
desbloqueados; los módulos se consultan en lectura.

## Resolución y referencias

`APTUSQualityManager.resolve(quality_id)` busca en ambas rutas con
`DB.getChildrenGlobal`. Devuelve una definición sólo si hay exactamente una.
Dos definiciones con igual ID son ambiguas incluso si tienen el mismo contenido:
se informa al DJ y no se selecciona ninguna. Tener simultáneamente una definición
de autor y su módulo exportado puede producir ese conflicto; debe gestionarse
el conjunto de módulos cargados.

Las asociaciones nuevas guardan exclusivamente:

```text
properties.qualities.<clave>.quality_id
properties.profiles.<perfil>.qualities.<clave>.quality_id
```

No se copian nombres, descripciones, clasificaciones ni definiciones. La resolución
siempre lee la información actual disponible. Los eventos de DB y carga/descarga
de módulos refrescan las filas y resúmenes. Modificar una definición no cambia
el token ni la versión de EQUIPO.

Una referencia ausente o ambigua muestra exactamente `Cualidad inaccesible`. Su
tooltip informa: `No se encuentra la definición de esta cualidad. Comprueba que el módulo correspondiente esté activado`.
El ID se registra en consola para diagnóstico, permanece intacto y no impide
guardar otros cambios. Resolver de nuevo tras cargar el módulo recupera el nombre.
Los clientes necesitan recibir la definición compartida o cargar su módulo;
referenciar un ID no concede permisos de lectura automáticamente.

## Arrastre y borradores

Se aceptan enlaces del registro `aptus_quality`, comprobando clase, nodo e ID.
No se admiten IDs repetidos dentro de una lista. Los tipos no filtran qué puede
asociarse. Un arrastre a las generales no cambia perfiles; un arrastre a un perfil
no cambia generales ni otros perfiles.

El botón de añadir generales abre la configuración independiente. Cada perfil
tiene también Configurar para sus asociaciones. La ventana usa una copia local
de las asociaciones iniciales; se pueden arrastrar referencias, consultar nombre/
descripción por tooltip, abrir la definición original con Ver y quitar entradas.

- Guardar sólo aplica las asociaciones al borrador de EQUIPO.
- Descartar o cerrar no aplica nada.
- Guardar EQUIPO es el único paso que persiste sus asociaciones e incrementa
  versión. Guardar sin cambios mantiene versión.
- Si cambió la lista de origen durante la configuración, se rechaza sobrescribirla.
- Recargar, guardar, descartar o cerrar EQUIPO invalida ventanas secundarias del
  borrador anterior. Eliminar/recrear una fila de perfil también invalida su
  configuración anterior. Se debe reabrir, sin aplicar datos a otro perfil.
- Cambiar de pestaña sólo oculta controles: no destruye el borrador.

La ventana secundaria se gestiona con la cola nativa de DialogManager: una
configuración activa y solicitudes posteriores en cola, sin reutilizar una
ventana abierta para sobrescribir silenciosamente su contexto.

## Contrato único de asociaciones

Una entrada sólo contiene un quality_id de texto no vacío. No se admiten nombre,
descripción, parámetros ni otras propiedades dentro de las asociaciones. La
validación rechaza que un borrador introduzca datos fuera de este contrato.

La lectura ignora entradas fuera del contrato sin convertir sus identificadores
en asociaciones. Abrir, cerrar o Descartar no escribe DB. Guardar elimina esas
entradas sólo de las colecciones de la plantilla editada (generales y por perfil),
conservando referencias válidas y todas las demás propiedades. Si eso cambia
las colecciones persistidas, incrementa versión una sola vez. Duplicar normaliza
sólo la nueva copia; el original queda intacto. No hay barrido ni migración de
campaña, copias históricas o conversión por nombres.

## Borrar definiciones

El botón Borrar y la eliminación desde las filas del catálogo pasan por la misma
confirmación de APTUS. Se cuentan referencias persistidas conocidas en EQUIPO,
personajes y estructuras, incluidas rutas de módulos cargados. La API permite
registrar raíces adicionales para futuras funcionalidades.

Siempre se solicita confirmación y se muestra el recuento; si aparecen nuevas
referencias mientras está abierta, se solicita otra confirmación. No se elimina
ninguna asociación. Las de módulos no cargados y borradores no persistidos no
pueden contarse íntegramente: no se promete una búsqueda global fuera de los
datos disponibles. No se modifica la eliminación global de CoreRPG.

## Perfiles

La fila ocupa 408 × 97 dentro del panel de la ficha 650 × 433:

1. Nombre, Habilidad, ALC, Mod. Ata, Daño y Crítico.
2. Utiliza munición y Mun. MAX (entero no negativo, cero permitido).
3. Cualidades separadas por comas y Configurar.

El ID interno se conserva sin campo visible. No aparece Mun. ACT ni se guarda
munición actual en plantillas. Se conserva el indicador que diferencia Sin
munición de máximo cero. No hay tiradas ni automatizaciones nuevas. Separador
fino nativo entre perfiles y scroll vertical si hay varios.

Se usa una fuente condensada de 12 píxeles para los campos compactos. Los nombres
largos requieren desplazamiento del texto; validar legibilidad en la escala de
interfaz real de FGU antes de dar por aprobada la presentación.

## Pruebas realizadas y límites

Comprobaciones estáticas: balance XML y referencias, bloques Lua, nombres de
controles sin duplicados en las clases modificadas, perfil dentro de 408 × 97,
ficha fija, ausencia de ID/Mun. ACT visibles, editores secundarios sin escrituras
DB e independencia de ItemManager.

La suite `utility/tests/equipment_save_test.lua` se amplía con catálogo, IDs,
multiclase, referencias, definiciones actualizadas sin cambiar EQUIPO, duplicados,
inaccesibles y recuperación. Está preparada pero NO ejecutada: no hay Lua/luac
ni FGU disponibles en este entorno. No se ha reiniciado ni recargado FGU.

## Circuito manual pendiente en FGU

1. Cargar esta versión cuando el DJ decida probar. Abrir CUALIDADES, crear una
   definición y verificar ID automático, inmutable y persistente al reabrir.
2. Asignar Equipo y Armas CC simultáneamente, guardar y comprobar que aparece al
   filtrar por cualquiera de ambos. Quitar el filtro muestra todas. Crear un tipo
   distinto y revisar que los grupos y la búsqueda nativa siguen funcionando.
3. Editar nombre/descripcion y guardar; probar como jugador y desde módulo de
   sólo lectura que no puedan modificarse. Exportar/cargar módulo conserva IDs.
4. En EQUIPO arrastrar una cualidad a generales. Repetir: no duplicar asociación.
   Guardar EQUIPO y reabrir; consultar descripción por tooltip y original con Ver.
5. Crear dos perfiles. Verificar tres filas, campos editables, Habilidad por clic,
   ausencia de ID y Mun. ACT y diferencia entre Sin munición y Mun. MAX=0.
6. Arrastrar cualidades distintas a cada perfil: no aparecen en generales ni en
   el otro. Los resúmenes muestran nombres separados por comas y sus descripciones.
7. Configurar asociaciones, añadir/quitar y Descartar/cerrar: borrador previo
   intacto. Repetir y Guardar secundario: sólo cambia el borrador, sin versión.
8. Cambiar pestañas y volver; los campos y asociaciones siguen pendientes. Guardar
   principal incrementa una vez; otro Guardar sin cambios no incrementa.
9. Descartar principal o cerrar sin guardar después de Guardar secundario:
   asociaciones persistidas anteriores intactas.
10. Dejar secundaria abierta y descartar/guardar/eliminar su perfil en principal:
    no debe aplicar asociaciones a un contexto obsoleto.
11. Modificar la definición original en CUALIDADES: referencias actualizadas al
    refrescar, sin incremento de EQUIPO. Probar también carga/descarga de módulo.
12. Hacer inaccesible una definición: texto/tooltip exactos, ID en consola,
    asociación conservada y otros cambios guardables. Recuperarla: vuelve el nombre.
13. Probar dos módulos de prueba con el mismo ID: aviso y resolución bloqueada,
    nunca selección silenciosa. Quitar el duplicado recupera resolución única.
14. Borrar una definición usada desde su ficha y desde el índice: advertencia,
    Cancelar conserva todo; confirmar deja referencias inaccesibles, no las borra.
15. Abrir datos de prueba fuera del contrato: no se muestran ni entran al borrador.
    Descartar no modifica DB. Guardar retira sólo esas asociaciones; duplicar no
    las copia y no modifica el original. Las demás propiedades permanecen intactas.
16. Crear copia de EQUIPO con asociaciones: nuevo template_id, versión 1, mismos
    quality_id y ninguna definición CUALIDAD adicional. Confirmación del borrador
    de copia conserva su funcionamiento.
17. Comprobar Datos, Contenedor/Carga, requisitos, imagen y skin; personajes,
    Localizaciones, Vehículos y APTUS Dice mantienen sus funciones.
