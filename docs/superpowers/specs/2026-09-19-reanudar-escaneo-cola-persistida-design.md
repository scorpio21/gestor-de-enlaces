# Diseño — #13 Reanudar escaneo interrumpido (cola persistida)

Fecha: 2026-09-19

## Objetivo

Persistir la cola de verificación pendiente del escaneo de enlaces en `user://colas.json` y ofrecer reanudarla cuando la app se abre tras una interrupción (cierre, corte), en vez de perder el progreso acumulado.

## Decisiones de diseño

1. **Reanudación con diálogo de confirmación** al abrir la app: "¿Reanudar escaneo de N enlaces?" con Sí/No. Sin sorpresas.
2. **Persistencia tras cada enlace completado**: la lista de pendientes se re-escribe en `user://colas.json` cada vez que se completa un enlace. Un corte brutal solo pierde el enlace "en vuelo" como máximo.
3. **Se guardan URLs (claves estables), no índices**: los índices se descuadran con cualquier cambio de orden/borrado. Al reanudar se filtran las URLs que ya no existen/renombradas en el catálogo actual y se descartan silenciosamente.

## Alcance

- Persistencia de la cola de escaneo manual (`_comprobar_visibles`) en `user://colas.json`.
- Diálogo de reanudación al abrir la app.
- **Sin cambios** en auto-escaneo, preferencias, paralelismo, timeout ni en el formato de estados.
- El progreso ya persistido (estados por URL) sigue intacto; la cola solo guarda el puntero de lo pendiente.

## Arquitectura

### 1. Nuevo `scripts/cola_store.gd` (RefCounted)

Mismo patrón de `scripts/estado_store.gd` (JSON en `user://`, atómico simple con `FileAccess`).

**API:**

```gdscript
class_name ColaStore
extends RefCounted

func _init(base := "user://") -> void

func cargar() -> Dictionary
	# -> { "urls": Array, "fecha": int } ; url implícita "user://colas.json"
	# Si no existe el fichero o es inválido -> { "urls": [], "fecha": 0 }

func guardar(urls: Array) -> bool
	# Escribe { "urls": urls, "fecha": int(Time.get_unix_time_from_system()) }

func limpiar() -> bool
	# Elimina el fichero; true si no queda fichero
```

- `_leer_json` / `_escribir_json` / `_ruta` idénticos a `estado_store.gd:92-115`.
- `guardar([])` se permite (representa una cola vaciada a mitad de camino); la limpieza verdadera es `limpiar()`.
- `cargar()` devuelve siempre un Dictionary con ambas claves (nunca `null` ni diccionario a medias) — normaliza si el contenido es inválido.

### 2. Integración en `scripts/main.gd`

Estado y wiring:

- `const ColaStoreScript := preload("res://scripts/cola_store.gd")`
- `var _cola_store: RefCounted` (creado en `_ready()`)
- `@onready var dialogo_reanudar: Window = %ConfirmarReanudar`

Flujos:

**Al iniciar escaneo** (`_comprobar_visibles()`, tras armar `_cola` en la línea ~605):
```gdscript
_persistir_cola()
```
`_persistir_cola()` recoge las URLs de `_cola`:
```gdscript
func _persistir_cola() -> void:
	if _cola_store == null:
		return
	var urls: Array = []
	for item in _cola:
		if is_instance_valid(item):
			urls.append(item.url)
	_cola_store.guardar(urls)
```
No bloquea el escaneo si falla la escritura (best-effort; `progreso.text` con aviso opcional).

**Tras cada enlace** (`_on_item_terminado()`, cuando se vuelve a `_lanzar_siguiente()` en la línea 647): llamar `_persistir_cola()` justo después de `_lanzar_siguiente()` en la rama que aún tiene pendientes.

**Al terminar** (`_on_item_terminado()`, rama final donde `%BotonComprobar.disabled = false`):
```gdscript
if _cola_store != null:
	_cola_store.limpiar()
```

**Al abrir** (`_ready()`, tras `_refrescar_vista()` y `_actualizar_status()`):
```gdscript
_revisar_cola_pendiente()
```

`_revisar_cola_pendiente()`:
1. `var pendientes: Array = _cola_store.cargar().get("urls", [])` ; si `pendientes.is_empty()` → return.
2. Filtrar a las presentes en el catálogo: construir set de `clave_unica(url)` de `_entradas`; quedarse con las URLs de `pendientes` cuya clave está en el set.
3. Si tras el filtro no queda ninguna → `limpiar()` y return.
4. `dialogo_reanudar.dialog_text = "¿Reanudar escaneo de %d enlaces?" % N` y `dialogo_reanudar.popup_centered()`.
5. La señal `%ConfirmarReanudar.confirmed` se conecta en `_ready()` a `_reanudar_escaneo()`:

```gdscript
func _reanudar_escaneo() -> void:
	var pendientes: Array = _cola_store.cargar().get("urls", [])
	if pendientes.is_empty():
		return
	var set := {}
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			set[GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))] = true
	_cola.clear()
	_en_vuelo = 0
	for hijo in lista.get_children():
		if is_instance_valid(hijo) and pendientes.has(hijo.url):
			_cola.append(hijo)
	_total = _cola.size()
	if _total == 0:
		_cola_store.limpiar()
		%BotonComprobar.disabled = false
		return
	_hechos = 0
	%BotonComprobar.disabled = true
	%BarraProgreso.visible = true
	%BarraProgreso.remove_theme_stylebox_override("fill")
	_actualizar_barra(0, _total)
	progreso.text = "Comprobando 0/%d…" % _total
	_lanzar_siguiente()

func _on_reanudar_confirmado() -> void:
	_reanudar_escaneo()
```

El diálogo `%ConfirmarReanudar` se declara en `Main.tscn`: un `AcceptDialog` con `ok_button_text = "Sí"` y `cancel_button_text = "No"`. Al pulsar "No" (cancelado) se hace `limpiar()`:
```gdscript
dialogo_reanudar.canceled.connect(_descartar_cola_pendiente)
func _descartar_cola_pendiente() -> void:
	if _cola_store != null:
		_cola_store.limpiar()
```

> Detalle de robustez: `_reanudar_escaneo` re-lee `cargar()` en vez de confiar en el estado capturado al mostrar el diálogo — evita desincronía si algo cambió entre popup y confirmación.

## Flujo de datos

```text
Abrir app
  → _revisar_cola_pendiente(): colas.json → urls → filtrar → popup Sí/No
      Sí → _reanudar_escaneo(): reconstruir _cola desde hijos de lista → _lanzar_siguiente()
      No → _descartar_cola_pendiente(): limpiar()

Comprobar (manual/atajo)
  → _comprobar_visibles(): armar _cola → _persistir_cola() (urls) → _lanzar_siguiente()

Cada terminado
  → guardar estado de ese enlace (ya existente)
  → _lanzar_siguiente() + _persistir_cola() (si quedan)
  → si terminado: _cola_store.limpiar()
```

## Manejo de errores / mantenibilidad

- Escritura best-effort: un fallo de `guardar()` no interrumpe el escaneo.
- `cargar()` tolera fichero inexistente, JSON inválido, o falta de claves → siempre `{ "urls": [], "fecha": 0 }`.
- Reanudación sin fábrica de catálogo (todas las URLs eliminadas) → limpiar, sin ofrecer diálogo.
- `cola_store.gd` no conoce UI ni main; solo paths y JSON. Mantiene la separación store/UI del resto del proyecto.
- `guardar([])` ≠ `limpiar()`: el primer caso persiste una cola vacía (semántica de progreso); el segundo borra el intento de reanudación.

## Testing

**Nuevo `tests/test_cola_store.gd`** (SceneTree, base `user://__test_cola__`):

1. `cargar()` sin fichero → `urls` vacío y `fecha 0`.
2. `guardar(["a", "b"])` → `cargar()` devuelve `["a", "b"]` y `fecha > 0`.
3. `guardar([])` → `cargar()` devuelve `urls` vacío (conserva el intento).
4. `limpiar()` → `cargar()` devuelve `urls` vacío.
5. Multi-instancia: store A guarda, nuevo `store_b.new()` carga → recupera (`urls` correcto).
6. Al terminar test se limpia la base (`user://__test_cola__`).

**Integración en `tests/test_main_barra.gd`** (u otro test de main ya existente), patrón a confirmar al implementar:

- `_comprobar_visibles()` con 2-3 items → `cola_store.cargar().urls` contiene las URLs de los items (en `user://__test_main__`).
- Simular un terminado (emitir `verificacion_terminada` en un item) → tras procesarse, `cola_store.cargar().urls` ya no contiene la URL completada.
- Cuando la cola se vacía → `cola_store.cargar().urls` está vacío (o fichero limpio).
- Reanudación: guardar manualmente `{urls:[...2 de 3...]}` → reconstruir `_cola` con los 2 items correctos y lanzar sin duplicar el completado.

> Los tests de main headless no abren ventanas; el diálogo se dispara solo en build con UI, así que la reanudación en test se prueba invocando `_reanudar_escaneo()` directamente (no la señal).

## Entregables

- `scripts/cola_store.gd` — nuevo store (cargar/guardar/limpiar).
- `scripts/main.gd` — integración: `_persistir_cola`, `_revisar_cola_pendiente`, `_reanudar_escaneo`, `_descartar_cola_pendiente`, wiring en `_ready` y `_comprobar_visibles`/`_on_item_terminado`.
- `scenes/Main.tscn` — diálogo `%ConfirmarReanudar` (AcceptDialog Sí/No).
- `tests/test_cola_store.gd` — nuevo suite.
- `tests/test_main_barra.gd` — checks de integración.