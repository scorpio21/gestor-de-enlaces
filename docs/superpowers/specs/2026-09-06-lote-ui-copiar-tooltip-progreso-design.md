# Lote UI: copiar URL (#16), tooltip de detalle (#18) y barra de progreso (#15) — Diseño

> Issues: #16 [UI] Botón de copiar URL en cada fila · #18 [UI] Tooltip con detalle de estado (código HTTP, fecha, mensaje) · #15 [UI] Barra de progreso y aviso al terminar el escaneo.

**Goal:** Añadir a cada fila del catálogo un botón de copiar URL siempre visible, un tooltip de detalle (código HTTP, fecha de última comprobación, mensaje) y una barra de progreso del escaneo que se colorea al terminar como aviso — todo con nodos editables desde el editor de Godot.

**Restricción de edición:** Todo el layout vive en las escenas `.tscn` con nodos estándar y `unique_name_in_owner`, editable visualmente desde el editor; el código solo maneja estado dinámico (valor, texto, color transitorio), nunca construye UI procedural.

---

## Arquitectura

### Flujo de datos del código HTTP (base para el tooltip)

1. **`scripts/link_checker.gd`**: nuevo `var codigo := 0`. En `_leer_respuesta()`, al recibir respuesta, se fija `codigo = _cliente.get_response_code()` antes de evaluar redirección/estado. En los cierres sin respuesta HTTP (timeout, DNS, conexión, TLS) `codigo` queda `0`. La señal `terminado(valido: bool, mensaje: String)` **no cambia**.
2. **`scripts/list_item.gd`**: `_on_check_terminado(ok, texto)` lee `_checker.codigo` **antes** de `_checker = null` y lo pasa a `aplicar_estado`. Nuevos campos `var codigo := 0`, `var fecha := 0`. `aplicar_estado` amplía la firma con opcionales: `aplicar_estado(ok: Variant, texto: String, codigo := 0, fecha := 0) -> void` y los asigna; los llamadores actuales (2 argumentos) siguen funcionando.
3. **`scripts/estado_store.gd`**: `guardar_estado(url: String, valido: bool, mensaje: String, codigo := 0) -> bool` — parámetro opcional; el dict persistido pasa a `{"valido", "mensaje", "codigo", "fecha"}`. Compatible con lo ya guardado (entradas previas sin `codigo` → se leen como ausente → `0`). La `fecha` ya se persistía hoy.
4. **`scripts/main.gd`**: en `_on_item_terminado` y `_persistir_recompra` guarda `{valido, mensaje, codigo, fecha}` en `_estados` (memoria) y en disco con `codigo` del item y `fecha = int(Time.get_unix_time_from_system())`.

### Copiar URL (#16)

- **`scenes/ListItem.tscn`**: nuevo `%BtnCopiar` (Button, `text = "Copiar"`) siempre visible al final de `Fila`, entre `EstadoLabel` y el contenedor `Acciones`. Y nuevo `%TemporizadorCopiar` (Timer, `one_shot = true`, `wait_time = 1.5`) como hijo de la fila raíz.
- **`scripts/list_item.gd`**: `signal copiar_pedido(url: String)`. En `_ready`, `%BtnCopiar.pressed.connect(_on_copiar)` y `%TemporizadorCopiar.timeout.connect(_restaurar_boton_copiar)`. `_on_copiar()`: emite `copiar_pedido(url)`, cambia `%BtnCopiar.text = "¡Copiada!"`, `disabled = true` y arranca el temporizador. En timeout restaura `text = "Copiar"`, `disabled = false`.
- **`scripts/main.gd`**: en `_mostrar_lista`, `item.copiar_pedido.connect(_on_copiar_pedido.bind(item))`. `_on_copiar_pedido(item)` hace `DisplayServer.clipboard_set(item.url)` — sin efectos colaterales si falla.

### Barra de progreso (#15)

- **`scenes/Main.tscn`**: nuevo `%BarraProgreso` (ProgressBar) en `BarraAcciones`, después del `%Progreso`, con `size_flags_horizontal = 3`, `min_value = 0`, `max_value = 100`, `value = 0`, `show_percentage = false`. Oculta por defecto.
- **`scripts/main.gd`**: `@onready var barra_progreso: ProgressBar = %BarraProgreso`. Helpers extraídos (testeables, sin emitir estados del motor):
  - `_actualizar_barra(hechos: int, total: int) -> void`: `max_value = maxi(total, 1)`, `value = hechos`.
  - `_marcar_barra_final(caidos: int) -> void`: aplica `add_theme_stylebox_override("fill", StyleBoxFlat)` con `bg_color` verde `Color(0.35, 0.85, 0.45, 1)` si `caidos == 0`, rojo `Color(0.95, 0.35, 0.35, 1)` si no.
- Flujo: `_comprobar_visibles()` (con `_total > 0`) → `barra_progreso.show()`, `remove_theme_stylebox_override("fill")` (resetea color del escaneo anterior), `_actualizar_barra(0, _total)`. Cada `_on_item_terminado` → `_actualizar_barra(_hechos, _total)`. Al terminar → `_marcar_barra_final(caidos)` y `%Progreso` = "Listo: N caídos de M". La barra queda visible coloreada (aviso persistente) hasta el siguiente escaneo.
- Casos borde: `_total == 0` → `barra_progreso.hide()` y "Nada que comprobar". La re-comprobación individual (`_persistir_recompra`) no toca la barra.

### Tooltip (#18)

- **`scripts/list_item.gd`**: nueva `_actualizar_tooltip() -> void`, llamada desde `setup()` y desde `aplicar_estado()`. Composición:
  - Base: la URL (`tooltip_text = url` — se mantiene como primera línea siempre).
  - Con estado (`valido != null`): URL + línea `Código: N` (o `Código: —` si `codigo == 0`) + línea `Comprobado: dd/mm/aaaa hh:mm` (solo si `fecha > 0`) + línea con `mensaje`.
  - Sin estado (`valido == null`): URL + `\nSin comprobar`.
- Nuevo `func formatear_fecha(unix: int) -> String` con `Time.get_datetime_dict_from_unix_time(unix)` → `"%02d/%02d/%04d %02d:%02d"` (día/mes/año hora:minuto local).

---

## UI (nodos de escena — editable en el editor)

- `ListItem.tscn`: `%BtnCopiar` y `%TemporizadorCopiar` con propiedades estándar (texto, one_shot, wait_time).
- `Main.tscn`: `%BarraProgreso` con propiedades estándar en `BarraAcciones`.
- Sin contenedores adicionales, sin layouts en código. El usuario puede reordenar/rediseñar estos nodos desde el editor; el código solo referencia los `%unique` nodos.

---

## Compatibilidad y errores

- `guardar_estado` con `codigo := 0` opcional: no rompe llamadas existentes ni `test_estado_store.gd` actual. Entradas previas sin `codigo` → `0` → tooltip `Código: —`.
- `DisplayServer.clipboard_set` no interrumpe el flujo bajo ninguna condición.
- Los cambios aplican a filas nuevas y estados ya cargados (los estados de disco incluyen `fecha`; `codigo` presente desde el primer guardado nuevo).
- Sin cambios en `gestor_contadores.gd`, `preferencias`, `config_store`, `AgregarEnlace`, ni `estado_store` más allá del parámetro nuevo.

---

## Testing (harness SceneTree, sin red)

- **`tests/test_list_item.gd`** (ampliar): `formatear_fecha` con unix fijo → "dd/mm/aaaa hh:mm"; `aplicar_estado(ok, texto, 404, fecha)` → tooltip contiene URL, "Código: 404", "Comprobado: …" y el mensaje; fila "Sin comprobar" → tooltip con URL + "Sin comprobar"; `%BtnCopiar.pressed` → emite `copiar_pedido` con la URL y el botón pasa a "¡Copiada!".
- **`tests/test_estado_store.gd`** (ampliar): `guardar_estado(url, true, "OK (200)", 200)` persiste `codigo == 200`; llamada sin `codigo` persiste `codigo == 0`.
- **`tests/test_main_barra.gd`** (ampliar): instanciada `Main.tscn`, llamadas directas a `_actualizar_barra(3, 5)` → `%BarraProgreso.value == 3` y `max_value == 5`; `_marcar_barra_final(0)` → `bg_color` verde, `_marcar_barra_final(2)` → rojo (comparando el `StyleBoxFlat` aplicado, no píxeles); `_comprobar_visibles` sin visibles → barra oculta y "Nada que comprobar" (el caso "0 visibles" no lanza red).
- `codigo` del checker: cobertura de default (`0`) y asignación en `_leer_respuesta` vía parse; el caso de red real queda a smoke (no hay respuesta HTTP sin red).