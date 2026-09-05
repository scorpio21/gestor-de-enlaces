# Diseño: Estado de escaneo persistente + eliminar/re-comprobar enlaces inválidos

Fecha: 2026-09-05
Proyecto: GestorAO (`K:\gestor-de-enlaces`)

## Problema

1. El resultado del escaneo de enlaces (`valido`, `mensaje`) solo vive en memoria: al abrir el proyecto todo vuelve a "Sin comprobar" y hay que re-escanear.
2. No hay forma de eliminar un enlace inválido desde la interfaz.

## Decisiones acordadas

- El estado del escaneo se guarda en `user://estados.json` (por URL), no en `data.json`.
- Eliminar es permanente y con confirmación; las URLs eliminadas se guardan en `user://borrados.json`; `data.json` queda intacto.
- Los enlaces inválidos muestran botones de **Eliminar** y **Re-comprobar** individual.
- El guardado es incremental: cada enlace verificado persiste su resultado al momento, para que un cierre a mitad de escaneo no pierda el progreso ya completado.

## Arquitectura

### 1. Nuevo módulo `scripts/estado_store.gd` (clase `RefCounted`)

Encapsula toda la persistencia de `user://`. Se instancia en `main.gd`.

API propuesta:

- `cargar() -> Dictionary` — lee `user://estados.json` (objeto `{ "<url>": { "valido": bool, "mensaje": String, "fecha": int } }`) y `user://borrados.json` (array de URLs). Devuelve `{ "estados": {...}, "borrados": [...] }`. Si un archivo no existe o no parsea, devuelve estructura vacía.
- `guardar_estado(url: String, valido: bool, mensaje: String) -> bool` — escribe/actualiza la entrada para `url`, añadiendo `fecha` (Unix timestamp). Re-parsea, muta y escribe el archivo.
- `marcar_borrado(url: String) -> bool` — añade la URL al array de borrados (sin duplicados) y escribe `user://borrados.json`.
- `borrar_estado(url: String) -> void` — elimina la entrada de `url` en estados (si existe) y escribe.

Formato de `user://estados.json`:

```json
{
  "http://www.4shared.com/file/...": { "valido": false, "mensaje": "No existe (404)", "fecha": 1757059200 }
}
```

Formato de `user://borrados.json`:

```json
["http://www.4shared.com/file/...", "http://rapidshare.com/..."]
```

### 2. `scenes/ListItem.tscn` + `scripts/list_item.gd`

- Añadir dentro de `Margen/Fila` un `HBoxContainer` con dos `Button`:
  - `BtnRecomprobar` — texto "Volver a comprobar".
  - `BtnEliminar` — texto "Eliminar".
- Ambos con `mouse_filter = STOP` para que al pulsarlos no se dispare `_pressed()` del `Button` raíz (no abren la URL).
- Nuevas señales: `eliminar_pedido`, `recomprobar_pedido`, emitidas al pulsar cada botón.
- Nuevo método `aplicar_estado(valido: Variant, mensaje: String) -> void`: pinta el estado y guarda `valido` y `estado` (usado al cargar del JSON, sin red).
- `_on_check_terminado`: guardar también el `mensaje` en una variable de instancia para que `main.gd` pueda persistirlo.
- Método `mostrar_acciones(visible: bool)`: muestra/oculta los botones de acción; llamar con `true` solo cuando `valido == false`.
- `verificar()` y `_pressed()` se mantienen: re-comprobar individual reutiliza `verificar()`.

### 3. `scenes/Main.tscn` + `scripts/main.gd`

- Añadir a `Main.tscn` un `ConfirmationDialog` (nodo `ConfirmarBorrado`).
- `_cargar_datos()`: después de construir `_entradas`, crear el `EstadoStore`, filtrar las URLs que estén en `borrados` y cargar el mapa de estados.
- En `_mostrar_lista()`, tras `item.setup(...)`: aplicar `item.aplicar_estado(...)` y `item.mostrar_acciones(...)` según el estado guardado; conectar `eliminar_pedido` y `recomprobar_pedido` de cada item.
- **Al terminar cada verificación** (`_on_item_terminado`): obtener `url` + `valido` + `mensaje` del item y llamar `estado_store.guardar_estado(...)`. Este flujo cubre tanto el escaneo global como el re-comprobar individual.
- **Re-comprobar individual**: al recibir `recomprobar_pedido`, llamar `item.verificar()` (red) y conectar `verificacion_terminada` one-shot; al acabar se persiste vía `_on_item_terminado`. Durante la comprobación, ocultar los botones de acción de esa fila.
- **Eliminar**:
  - Al recibir `eliminar_pedido`, guardar el item/referencia pendiente y mostrar `ConfirmarBorrado` con el nombre del enlace.
  - Al aceptar: `estado_store.marcar_borrado(url)`, `estado_store.borrar_estado(url)` (opcional), eliminar la entrada de `_entradas`, `queue_free()` de la fila y refrescar contador.
  - `data.json` y `user://enlaces.json` no se modifican en el borrado.
- `_guardar_datos()` queda igual (solo se usa al agregar enlaces).

### 4. Filtros

- Sin cambios de lógica. Al abrir, los enlaces con estado guardado ya no cuentan como "Sin comprobar" (`valido != null`).
- El filtro "Válidos" / "Caídos" se basa en el valor de `valido` cargado desde el JSON.

## Manejo de errores

- Archivos JSON rotos o inexistentes: `cargar()` devuelve estructura vacía; la app funciona con todo "Sin comprobar".
- Fallo de escritura (`guardar_estado`/`marcar_borrado`): devolver `false`; `main.gd` muestra mensaje en la label `Progreso` y no descarta el resultado (el item sigue mostrando su color en sesión).
- Confirmación de borrado cancelada: no se borra nada.

## Pruebas / Verificación

- Ejecutar el proyecto desde el MCP (`godot_run_project`).
- Al escanear, confirmar que aparece `user://estados.json` con entradas por URL, `valido`, `mensaje`, `fecha`.
- Reiniciar el proyecto: los colores/mensajes del último escaneo se restauran sin hacer red.
- Escanear una URL inválida: aparecen los botones; "Volver a comprobar" actualiza el estado; "Eliminar" pide confirmación, borra la fila y la URL queda en `borrados.json` (no reaparece al reiniciar).
- Verificar que `data.json` no cambia al eliminar.

## Fuera de alcance (YAGNI)

- No hay autenticación/accounts ni migración de datos.
- No se re-escribe `data.json` al eliminar.
- No hay expiración automática del estado guardado (se sobrescribe en cada escaneo/re-comprobación).