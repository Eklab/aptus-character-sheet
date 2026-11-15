# EQUIPO — fase 1

## Alcance y modelo

Registro `aptus_equipment`, campaña `aptus_equipment_templates`, módulos
`reference.aptus_equipment_templates`. Índice, grupos, enlaces, duplicación y
exportación genéricos de CoreRPG. No se utiliza ItemManager. ITEMS conserva su
registro y se oculta con `RecordDataManager.setHidden("item", true)`.

La ficha hereda `record_window`: cabecera de lectura y contenido desplazable.
Sus controles de edición no están vinculados a campos DB. Guardar confirma el
borrador completo; Descartar/Releer y cerrar abandonan cambios sin guardar.
Desbloquear con el candado nativo para editar. Sólo el anfitrión puede guardar
plantillas de campaña. Los módulos se consultan sin reescribir metadatos.

Datos de cada plantilla:

```text
template_id                  identidad estable
template_version             entero desde 1
schema_version               1, formato técnico
name                         nombre nativo para índice/enlaces
properties
    description              texto descriptivo inicial
    picture                  referencia token/asset opcional
    type_id
    stackable                0/1
    max_stack                entero >= 1
    load_every               entero >= 1
    load_value               CAR >= 0
    is_container             0/1; fuerza stackable=0 y max_stack=1
    capacity                 CAR >= 0
    defense
        pro, def, agi, per    modificadores con signo, sólo datos
    qualities                colección preparada, inicialmente vacía
    profiles                 colección preparada, inicialmente vacía
```

Contrato previsto para las colecciones (sin editores ni automatismos en fase 1):

```text
qualities.<asociación>
    quality_id               única propiedad; definición en CUALIDADES
profiles.<perfil>
    profile_id, name, attack_modifier
    damage, critical, range
    required_fue, required_agi
    uses_ammunition          distingue sin munición de un perfil agotado
    ammunition_max
    qualities.<asociación>   sólo quality_id, como las generales
```

No hay munición actual en las plantillas: pertenecerá a las instancias futuras.
Las colecciones se incluyen en la comparación de conflictos. Sus editores se
desarrollaron posteriormente: ver `EQUIPO_CUALIDADES_PERFILES.md` para el modelo
actual, la organización visual y las pruebas de borrador/guardado.

Siete Tipos iniciales: `melee_weapon`, `ranged_weapon`, `utility`, `electronic`,
`storage`, `protection`, `electromechanical_system`. Extensibles mediante
`APTUSEquipmentManager.registerType(id, nombre)`. No limitan propiedades.

## Identidad y versión

El anfitrión persiste un espacio de nombres aleatorio con marca temporal y contador
en `aptus_equipment_metadata`. Los ID no dependen del nombre ni del grupo.
El contador evita reutilización en la campaña y se contrastan ID ya cargados.
Es identidad con unicidad probabilística entre campañas, no un servicio central de
IDs. Una campaña clonada conserva su espacio de nombres: los conflictos se detectan,
no se resuelven mediante renumeración silenciosa.

El callback de creación/duplicación genérica asigna ID nuevo y versión 1. Cargar
referencias de módulos no llama a ese callback. Duplicar una referencia para obtener
una plantilla editable independiente sí crea identidad nueva.

Guardar compara campos copiables y no considera grupos, bloqueo ni metadatos de
compartición. Sin diferencias no escribe ni incrementa. Con diferencias incrementa
una vez y verifica escrituras. Un token de edición rechaza borradores desactualizados.
Ante errores de escritura se intenta restaurar los valores anteriores; no es una
transacción resistente a cierres del motor durante la escritura.

Se comparan registros de campaña y módulos con el mismo ID/versión. Si difieren sus
propiedades completas, se avisa en chat privado y ficha, y se bloquea el guardado.
También se comprueba una colisión con la siguiente versión antes de guardar.
La auditoría se ejecuta al inicio, al cargar módulos y después de guardar; abrir o
releer una ficha vuelve a comprobar su conflicto. No se conserva historial.

## Prueba manual en FGU

No se ha iniciado, recargado ni reiniciado FGU durante el desarrollo. Cargar esta
versión cuando el DJ decida comenzar las pruebas; los archivos no cambian el código
que ya está cargado en una sesión.

1. Como DJ, comprobar EQUIPO en la barra lateral y ausencia de ITEMS y Armas.
   Abrir otros catálogos y comprobar que funcionan.
2. Abrir EQUIPO, crear un grupo y una plantilla. Anotar ID, versión 1 y esquema 1.
   Verificar apertura desde el enlace del índice y desde un enlace arrastrado al chat.
3. Desbloquear. Recorrer los siete Tipos con Cambiar. Introducir nombre, descripción,
   CAR, máximo de pila, capacidad y modificadores defensivos positivos/negativos.
   Arrastrar una imagen desde Assets al campo Imagen y comprobar vista previa.
4. Antes de guardar, Descartar/Releer: no deben persistir los cambios. Volver a
   introducir varios valores y Guardar: incremento exactamente de 1 a 2.
5. Guardar otra vez sin cambios: conserva 2. Renombrar/mover el grupo: conserva 2.
   Cerrar y reabrir: mismos datos e identidad. Cerrar con borrador sin guardar lo descarta.
6. Probar nombre vacío, X=0, máximo de pila fraccionario y CAR/capacidad negativos:
   guardado rechazado sin incremento. Activar Contenedor y guardar: No apilable,
   máximo 1. No se calcula carga ni se crean instancias.
7. Duplicar desde el menú nativo: nuevo ID, versión 1 y propiedades conservadas.
   Cambiar la copia no modifica la original.
8. Como jugador, abrir una plantilla compartida: no puede guardar ni modificarla.
   No debe haber incorporación de equipo a personajes.
9. Exportar EQUIPO mediante /export. Cargar el módulo en una campaña de prueba con
   la extensión. Comprobar grupos, enlaces, ID/versión, imagen y todos los campos.
   La referencia del módulo no permite guardar; duplicarla crea otra identidad.
10. Descargar y recargar el módulo: su ID/versión no cambia. Verificar el mismo
    recorrido con el módulo disponible en un cliente independiente.
11. Para verificar conflictos, usar dos módulos de prueba con mismo ID/versión y
    propiedades diferentes: aviso explícito y guardado bloqueado, sin renumeración.
    La desaparición del conflicto se comprueba con Descartar/Releer.
12. Cerrar FGU y reabrir cuando corresponda: campaña conserva datos, contador e ID.
13. Abrir personajes: desaparecen filas de armas del prototipo. Atributos,
    habilidades, efectos, tiradas APTUS e iniciativa mantienen su comportamiento.
    Abrir Localizaciones, su configuración y Vehículos para comprobar regresiones.

## Retirada del prototipo

Retirados registro `aptus_weapon`, inicializador `aptus_weapons`, fichas y filas,
lista `.weapons`, función de incorporación y cadenas de catálogo. No se borran
nodos existentes de campañas ni se ejecutan migraciones. Dice, habilidades,
efectos y recursos gráficos compartidos se conservan.

## Validación y límites

Las pruebas estáticas pueden comprobar XML, referencias, controles del borrador,
retirada del prototipo y separación de ItemManager. No sustituyen compilación Lua
ni ejecución FGU. Este entorno no dispone de FGU, Lua/luac ni parser XML completo.

Pendientes de ejecución real: carga, geometría y scroll, eventos de duplicación,
persistencia, imágenes, exportación/importación y permisos del cliente. Las pruebas
de fallos del motor y las instancias independientes pertenecen a fases posteriores.
