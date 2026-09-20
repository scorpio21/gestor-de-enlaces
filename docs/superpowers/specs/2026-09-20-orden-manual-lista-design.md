# Diseño — #6 Orden manual de la lista con orden persistido

Fecha: 2026-09-20

## Objetivo

Permitir reordenar la lista de enlaces manualmente con "Subir" / "Bajar" desde el menú contextual de cada fila, y persistir ese orden en disco para que sobreviva a reinicios. La fuente de verdad del orden es el array `_entradas` que ya se guarda con `_guardar_datos()`.

## Decisiones de diseño

1. **Mecanismo: menú contextual** con "Subir" y "Bajar" en cada fila (sin drag & drop; Godot no trae DnD para `Control` y el usuario lo desestimó).
2. **Operan sobre filas visibles**: con filtros de búsqueda/estado/categoría activos, "Subir"/"Bajar" intercambian la entrada con la fila visible inmediatamente anterior/siguiente. Las entradas ocultas mantienen su posición relativa en `_entradas`.
3. **Estados por posición**: en la primera fila visible, "Subir" va deshabilitada; en la última, "Bajar" va deshabilitada.
4. **Interacción con `OrdenFecha`**: si el selector está en "Más recientes"/"Más antiguos", ambas opciones van deshabilitadas (el orden manual solo se aplica en "Sin ordenar").
5. **Persistencia sin cambios de esquema**: reordenar `_entradas` y llamar `_guardar_datos()` persiste el orden en `user://enlaces.json` (y `res://data/data.json`, ya existente).

## Alcance

- `scripts/list_item.gd`: menú contextual con 7 opciones (2 nuevas), señales `subir_pedido`/`bajar_pedido`, y estados `disabled` por posición y por orden automático.
- `scripts/main.gd`: handlers `_on_subir_pedido`/`_on_bajar_pedido`, swap en `_entradas`, guardado y refresco; cálculo de estados del menú (posición entre visibles + `OrdenFecha`).
- `scenes/ListItem.tscn`: sin cambios de layout (el menú ya existe en `%MenuContexto`).
- `tests/test_list_item.gd` y `tests/test_main_barra.gd`: cobertura nueva.
- **Sin cambios** en `gestor_datos.gd` (schema v1), `gestor_catalogo.gd`, ni el formato de catálogo.

## Arquitectura

### 1. `scripts/list_item.gd`

- Señales nuevas: `subir_pedido` y `bajar_pedido`.
- En `_ready()`, el menú pasa a 7 opciones (ids: Editar=0, Volver a comprobar=1, Copiar URL=2, Historial=3, Eliminar=4, **Subir=5**, **Bajar=6**). Orden visual: Subir y Bajar en la parte alta (tras "Editar…"). Se usa `add_separator()` y `add_item("Subir", 5)` / `add_item("Bajar", 6)`.
- Estado: `var puede_subir := true` y `var puede_bajar := true` (flags que `main` fija antes de abrir el popup). En `_ready()` se registra `set_item_disabled(5, ...)` y `set_item_disabled(6, ...)` según esos flags, y NUNCA se vuelven a habilitar/deshabilitar en runtime salvo por `fijar_estado_reorden()`.
- Nuevo método `fijar_estado_reorden(arriba: bool, abajo: bool) -> void` que aplica los estados `disabled` a las entradas 5 y 6 (y guarda los flags). `main` lo llama justo antes de `popup()`.
- En `_on_menu(id)`, los casos 5 y 6 emiten `subir_pedido.emit()` y `bajar_pedido.emit()`.

### 2. `scripts/main.gd`

Dos aristas: **quién deshabilita** y **quién reordena**.

**Estados del menú (antes de abrir):** se conectan `item.subir_pedido`/`item.bajar_pedido` como el resto de señales en `_mostrar_lista()` (patrón existente, `main.gd:639-643`). Para fijar estados justo antes del popup:

- Nuevo callback `item.menu_solicitado` (señal emitida por `list_item` en `_on_gui_input` antes de `popup()`), conectado a `_on_menu_solicitado(item)`.
- `_on_menu_solicitado(item)`:
  1. Si `orden_fecha.get_selected_id() > 0` → `item.fijar_estado_reorden(false, false)` y fin.
  2. `var visibles := _filas_visibles()` (los hijos de `lista` cuyo `visible == true`).
  3. `var idx := visibles.find(item)`; `item.fijar_estado_reorden(idx > 0, idx >= 0 and idx < visibles.size() - 1)`.

**Reordenar (`_on_subir_pedido(item)` / `_on_bajar_pedido(item)`):**

1. Guardar en `_on_menu` en vez de en el callback: se conectan las señales `subir_pedido.connect(_on_mover_pedido.bind(item, -1))` y `bajar_pedido.connect(_on_mover_pedido.bind(item, 1))`. Si `orden_fecha.get_selected_id() > 0`, `_on_mover_pedido` retorna sin hacer nada (doble red a los estados del menú).
2. `_on_mover_pedido(item, delta: int)`:
   - `var visibles := _filas_visibles()`; `var idx := visibles.find(item)`; si `idx < 0` o el vecino `idx + delta` se sale de rango, retorna.
   - `var vecino := visibles[idx + delta]`.
   - Localizar índices en `_entradas` de las entradas de `item` y `vecino` **por `clave_unica(url)`** (no por posición, porque entre fila visible y su vecino puede haber entradas ocultas por filtro):
     `var i := _indice_entrada(item.url)` / `var j := _indice_entrada(vecino.url)`.
   - Intercambiar: `var tmp := _entradas[i]; _entradas[i] = _entradas[j]; _entradas[j] = tmp`.
   - `_guardar_datos()`; si falla, revertir el swap y mostrar el error ya existente en `progreso`.
   - `_refrescar_vista()` (reconstruye respetando búsqueda y filtros; `_aplicar_filtro()` se encarga de visibilidad, y con `OrdenFecha` en "Sin ordenar" no hay re-sort).

Helpers nuevos:

```gdscript
func _filas_visibles() -> Array            # hijos de lista con visible == true
func _indice_entrada(url: String) -> int   # posición en _entradas por clave_unica; -1 si no está
```

**Nota**: `_refrescar_vista()` primero hace `queue_free()` de todos los hijos de `lista`, así el refresco recoge el nuevo orden de `_entradas`. El contador de `progreso` ("%d enlaces") no cambia porque el total visible es el mismo.

## Flujo de datos

```text
[clic derecho en fila]
  -> list_item._on_gui_input -> menu_solicitado.emit()
  -> main._on_menu_solicitado(item)  # fija disabled por posición / OrdenFecha
  -> PopupMenu muestra Subir|Bajar según estado

[usuario pulsa Subir/Bajar]
  -> list_item._on_menu(5|6) -> subir_pedido.emit() | bajar_pedido.emit()
  -> main._on_mover_pedido(item, -1|1)
  -> swap en _entradas (por url via clave_unica)
  -> _guardar_datos()  # user://enlaces.json + res://data/data.json
  -> _refrescar_vista() # re-render con el nuevo orden

[reinicio]
  -> _cargar_datos() -> _entradas con el orden guardado -> lista en ese orden
```

## Manejo de errores / mantenibilidad

- `_indice_entrada` devuelve `-1` si la URL no aparece en `_entradas`; `_on_mover_pedido` aborta sin tocar nada (defensa contra estados inconsistentes item/array).
- `_guardar_datos()` fallido → se revierte el swap antes de informar, así la vista y el disco quedan coherentes.
- `_filas_visibles` y el cálculo de estados viven en `main` (único conocedor de `_entradas`, filtros y `orden_fecha`); `list_item` solo expone flags y el menú. Se mantiene la separación lista/UI del repo.
- En `_on_menu_solicitado`, si `_filas_visibles()` no contiene al item (fila oculta), `find` da `-1` → ambas opciones deshabilitadas (no se puede mover una fila invisible).
- Reordenar y volver a cargar es idempotente: el array persistido define el orden exacto guardado.

## Testing

**`tests/test_list_item.gd`** (suite existente):

1. `_menu_completo` pasa de 5 a **7** opciones; `menu.get_item_count() == 7`.
2. `fijar_estado_reorden(true, true)` deja 5 y 6 habilitadas; `fijar_estado_reorden(false, false)` las deshabilita (comprobado con `is_item_disabled`).
3. `id_pressed.emit(5)` emite `subir_pedido`; `id_pressed.emit(6)` emite `bajar_pedido` (patrón de los checks 105-114 del test actual).

**`tests/test_main_barra.gd`** (suite existente, patrón de `main_script._entradas`):

4. Con `_entradas` de 3 enlaces, `main_script._filas_visibles().size() == 3`.
5. `_indice_entrada(url_c)` localiza la posición correcta en `_entradas`; `_indice_entrada("https://no-existe.test") == -1`.
6. Tras `_on_mover_pedido(item_b, -1)`, `_entradas` intercambió B y A; el orden persistido por `_guardar_datos()` refleja el swap (leer `user://__test_main_barra__/enlaces.json` con `GestorDatosScript.cargar` y comparar).
7. Con un filtro de estado que oculta la fila A, `_on_mover_pedido(C, -1)` intercambia las entradas de C y B en `_entradas` (A permanece en su sitio).
8. En la primera fila visible, `_on_menu_solicitado(item)` deja Bajar habilitada y Subir deshabilitada; en la última, al revés.
9. Con `orden_fecha.select(1)` y `_aplicar_filtro()`, `_on_menu_solicitado(item)` deshabilita ambas; `_on_mover_pedido(item, -1)` no modifica `_entradas`.
10. `_guardar_datos()` y `_cargar_datos()` en bucle: reordenar → guardar → `_cargar_datos()` (con la base de datos de usuario) recupera el orden nuevo (volver atrás con el contenido previo de los ficheros si aplica).

## Entregables

- `scripts/list_item.gd` — menú de 7 opciones + señales `subir_pedido`/`bajar_pedido` + `fijar_estado_reorden()` + señal `menu_solicitado`.
- `scripts/main.gd` — `_on_mover_pedido`, `_on_menu_solicitado`, `_filas_visibles`, `_indice_entrada`; conexiones en `_mostrar_lista`.
- `tests/test_list_item.gd` — checks 7 opciones, estados y emisiones.
- `tests/test_main_barra.gd` — checks de reorden, filtros, posición y persistencia.