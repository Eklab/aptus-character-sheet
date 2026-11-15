# Catálogo inicial de municiones APTUS

Entrega instalable: `APTUS_Initial_Ammunition.mod`.
Fuentes: `aptus_initial_ammunition/catalogue.json`, `definition.xml` y las seis
imágenes originales de `graphics/`. El constructor genera `client.xml` y el `.mod`.

Es un módulo nativo de datos para CoreRPG, que requiere APTUS Character Sheet
con el tipo `ammunition` habilitado. No es una extensión adicional ni se incluye
en `extension.xml`. No instala scripts, no crea inventarios y no escribe datos
automáticamente en campañas. Se utiliza `client.xml` para el catálogo consultable
por jugadores, sujeto a los permisos nativos que configure el anfitrión.

## Instalación y uso

1. Abrir la carpeta de datos de Fantasy Grounds desde su lanzador.
2. Copiar únicamente `APTUS_Initial_Ammunition.mod` en la carpeta `modules` de FGU.
   No instalar simultáneamente una segunda copia del módulo como carpeta.
3. Iniciar la campaña CoreRPG con APTUS Character Sheet habilitado.
4. Abrir la activación de módulos y cargar **APTUS — Municiones iniciales**.
   Autorizar el módulo para jugadores si deben consultar/seleccionar sus plantillas.
5. Abrir EQUIPO y elegir Tipo de equipo → Munición. Las mismas 17 plantillas
   estarán disponibles en Añadir equipo y en Tipo de munición de los perfiles.

Activar el módulo es la única carga necesaria: no hay que crear las plantillas
una a una, ejecutar comandos ni importar datos en el personaje. Debe permanecer
cargado para resolver referencias a sus plantillas. Cerrar y reabrir una campaña
no debe añadir nuevas plantillas; FGU gestiona su estado de activación.

## Ubicación e identidad

Nombre interno estable: `APTUS Initial Ammunition`.
Ruta de cada plantilla:

```text
reference.aptus_equipment_templates.ammo-<clave>@APTUS Initial Ammunition
```

Por ejemplo:

```text
reference.aptus_equipment_templates.ammo-9x19mm@APTUS Initial Ammunition
```

Los 17 `template_id` son nombres estables `aptus.initial.ammunition.<clave>`, con
`template_version=2` y `schema_version=1`. Se incrementa la versión por el cambio
de propiedades, conservando las identidades. No cambiar el nombre interno del módulo
ni las claves de nodo en actualizaciones: forman parte de las referencias nativas.

La rama `reference` es de consulta. Para personalizar una plantilla, usar el
mecanismo existente de crear copia y editarla en campaña; no sobrescribir el
módulo ni modificar una instancia pensando que se está editando el catálogo.
Las instancias existentes conservan la copia independiente de sus propiedades.
No se deduplican ni eliminan plantillas del director, ni siquiera si tienen nombres
iguales a los del módulo.

## Propiedades y límites

- Exactamente 17 plantillas, todas `ammunition`, con los textos solicitados.
- `stackable=1`, con los máximos y tramos definidos en `catalogue.json`:

| Municiones | Máximo de pila | Unidades por tramo | CAR por tramo |
|---|---:|---:|---:|
| 9×19 mm, .45 ACP, .40 S&W, .38 Special, .357 Magnum | 50 | 50 | 1 |
| .44 Magnum, 5,56×45 mm, 7,62×39 mm, 7,62×51 mm, .308 Winchester, .30-06 Springfield | 20 | 20 | 1 |
| Calibre 12, Calibre 20, .410 | 25 | 25 | 1 |
| Granada 40 mm | 6 | 3 | 1 |
| Flecha, Virote | 12 | 12 | 1 |

Se utilizan los campos existentes `properties.load_every` (unidades por tramo)
y `properties.load_value` (CAR por tramo). Las cajas no son contenedores:
`is_container=0`. El resto de campos conserva los predeterminados del modelo.
- No se incluyen perfiles, daño, crítico, alcance, cualidades, precio ni rareza.
- No se han implementado nuevas reglas de cantidades/apilamiento, consumo, carga,
  recargas, cargadores ni munición especial.

Las seis imágenes ya miden 192 × 192 px: se empaquetan byte a byte, sin escalado,
recorte, retoque ni cambio de transparencia. Las referencias son token nativas
`graphics/<archivo>.png@APTUS Initial Ammunition`, nunca rutas absolutas.
Para Calibre 12, Calibre 20 y .410 se utiliza `municion_cartuchosl.png`, conservando
el nombre original confirmado (incluida la «l» final).

### Límites reales del gestor actual

El gestor ya admite altas con cantidad, reparto/fusión genéricos, modificación y
eliminación de unidades, transferencias de pilas y CAR real por fila. Véase
`utility/INVENTARIO_UNIDADES.md` para sus garantías, interfaz y límites. El traslado
de contenedores ocupados entre personajes sigue pendiente. El total efectivo y la
capacidad reductora se describen en `utility/INVENTARIO_CARGA_CONTENEDORES.md`.

La fórmula aritmética usada para comprobar los datos solicitados es
`ceil(cantidadDeLaPila / load_every) * load_value`, aplicada a cada pila por
separado. No se suma primero toda la munición de un mismo tipo. Estas comprobaciones
validan la configuración, no ejecutan ni modifican el inventario de FGU.

## Reconstrucción y pruebas

Desde la raíz de Character Sheet, usando Node ya disponible:

```text
node utility/build_initial_ammunition_module.js
node utility/tests/initial_ammunition_module_test.js
```

El empaquetado es reproducible: ZIP sin compresión, nombres ASCII y fecha fija.
No necesita herramientas externas ni escribe fuera del proyecto. Genera las 17
plantillas desde el JSON y empaqueta los dos XML y los seis PNG. La prueba valida
nombres/descripciones exactos, identidades, límites/tramos, dimensiones, referencias,
ZIP/CRC y coincidencia binaria con las fuentes. También comprueba los ejemplos
aritméticos de reparto y CAR; no son pruebas de operaciones de inventario.

Formato de módulos contrastado con la documentación oficial de Fantasy Grounds:
[Module — Data Files](https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/996644362/).

## Validación pendiente en Fantasy Grounds Unity

En una campaña de prueba:

1. Cargar el módulo y comprobar 17 registros en su grupo, con todos los textos.
   Otras plantillas de campaña pueden aumentar el total global; no se eliminan.
2. Filtrar Munición en EQUIPO y en Añadir equipo. Seleccionar las 17 opciones
   desde perfiles, incluidas las referencias con `@APTUS Initial Ammunition`.
3. Arrastrar o añadir una plantilla al personaje; comprobar instancia independiente
   y las propiedades copiadas de cantidad, apilamiento, imagen y carga. Desde + se
   solicita la cantidad; arrastrar una plantilla añade una unidad, con fusión si procede.
4. Guardar una referencia desde un perfil; cerrar y reabrir la campaña. Confirmar
   que se resuelve la misma ruta y que no cambian consumo ni capacidad del perfil.
5. Ejecutar `/reload` y reiniciar FGU: deben seguir existiendo 17 nodos en este
   módulo, sin nuevos registros creados en `aptus_equipment_templates` de campaña.
6. Comparar plantillas e instancias preexistentes antes/después: no deben cambiar.
   Probar también una plantilla del director con el mismo nombre que una del módulo.
7. Cerrar el módulo: las instancias copiadas deben permanecer; las referencias a
   plantillas deben mostrarse inaccesibles, recuperándose al volver a cargarlo.
8. Comprobar acceso desde un cliente jugador autorizado.
9. Comprobar las 17 imágenes en plantilla e instancia, también tras reabrir el módulo.
10. No actualizar instancias antiguas automáticamente: conservan sus propiedades
    anteriores. Crear nuevas instancias para probar la versión 2 del catálogo.

El entorno de desarrollo no ejecuta FGU; la activación, permisos, arrastre y
persistencia de enlaces deben verificarse allí.
