# Diseño — #19 Tema claro/oscuro configurable

Fecha: 2026-09-19

## Objetivo

Añadir un selector de tema Claro/Oscuro persistido en el diálogo de Preferencias. "Oscuro" reproduce exactamente el aspecto actual de la app; "Claro" re-mapea fondos, textos y colores de estado. El tema se aplica a toda la app (ventana principal y ventanas de diálogo) al arrancar (`_ready()`) y al guardar Preferencias.

## Decisiones de diseño

1. **Selector manual** Claro/Oscuro (OptionButton), persistido en `user://config.json`. Sin opción "Sistema" (YAGNI).
2. **Paleta completa**: fondos, textos y colores de estado se re-mapean por tema.
3. **Nuevo `scripts/tema_store.gd`** (RefCounted, estáticas) como única fuente de verdad del color. Patrón store del repo.
4. Sin migrar a `ThemeDB.theme_override` ni a recursos `.tres`: el repo hoy no usa Theme y tiene los colores como literales en `.tscn` y en código; un Theme real exigiría retirar ~40 overrides de 5 escenas (refactor invasivo y arriesgado).

## Alcance

- Nuevo `scripts/tema_store.gd` con paletas y aplicación por barrido de roles.
- `scripts/config_store.gd`: campo `tema` persistido.
- `scripts/preferencias.gd` + `scenes/Preferencias.tscn`: OptionButton "Tema".
- `scripts/main.gd`: aplicar en `_ready()` y en `_aplicar_preferencias`, re-pintar la lista.
- `scripts/list_item.gd`: colores desde la paleta (no literales).
- **Sin cambios** en el formato de catálogo, escaneo, empaquetado ni las demás ventanas `.tscn` (sus fondos/html se re-mapean por barrido).
- Default = `oscuro` (idéntico al aspecto actual).

## Arquitectura

### 1. `scripts/tema_store.gd` (RefCounted, estáticas)

**API:**

```gdscript
class_name TemaStore
extends RefCounted

static func paleta() -> Dictionary        # set activo (dict nombre_color -> Color)
static func color_estado(ok: Variant) -> Color  # true->verde, false->rojo, null->gris
static func aplicar(modo: String, root: Node) -> void
static func normalizar(v: Variant) -> String   # "claro"|"oscuro"; inválido->"oscuro"
```

Paleta activa: variable estática `_actual := "oscuro"`; `aplicar()` la fija y recorre la escena.

**Paletas:**

| Rol | Oscuro (actual) | Claro |
|---|---|---|
| `Fondo` (ColorRect panel) | `Color(0.10,0.10,0.10,1)` en Main; `Color(0.12,0.12,0.12,1)` en diálogos | `Color(0.95,0.95,0.95,1)` |
| Texto suave | `0.75` | `0.30` |
| Texto tenue | `0.70` | `0.35` |
| Texto error | `0.95,0.40,0.40` | `0.80,0.15,0.15` |
| Estado Válido | `0.35,0.85,0.45` | `0.10,0.55,0.25` |
| Estado Caído | `0.95,0.35,0.35` | `0.80,0.10,0.10` |
| Estado Sin comprobar / Indicador | `0.55` | `0.45` |

> Nota Main vs diálogos: en oscuro, Main usa `0.10` y los 3 diálogos (`Preferencias`, `AgregarEnlace`, `Historial`) usan `0.12`. En `aplicar`, el `ColorRect` "Fondo" se pinta siempre con el valor de la paleta del tema (claro: `0.95`), de modo que en oscuro se preserva el valor actual de cada escena leyéndolo antes de re-aplicar.

**Mecánica de `aplicar(modo, root)`:**

1. `_actual = normalizar(modo)`.
2. Recorrer `root` (subárbol completo, incluidas ventanas): para cada `ColorRect` con `name == "Fondo"`, tomar su `color` actual como base para oscuro (si el modo es oscuro, no cambiar) o asignar el claro.
3. Para cada `Label` con `theme_override_colors/font_color` que coincida (por valor) con un color del set oscuro re-mapeable, sustituir por su equivalente claro.
   - Mapa de conversión por valor exacto: `{0.75 -> 0.30, 0.70 -> 0.35, rojo 0.95,0.40,0.40 -> 0.80,0.15,0.15}`.
   - En modo oscuro se restaura el valor original del set oscuro para esas claves.
4. Los colores de estado no se tocan en el barrido: los pintan los items (`list_item`) al re-renderizarse consultando `color_estado()`.

### 2. `scripts/config_store.gd`

- `TEMA_DEFAULT := "oscuro"`, `TEMAS_VALIDOS := ["claro", "oscuro"]`.
- `cargar()` añade `"tema": _tema_ok(v.get("tema", TEMA_DEFAULT))`.
- `guardar(...)` añade `"tema": _tema_ok(tema)` (nuevo parámetro con default `TEMA_DEFAULT`).
- `_tema_ok(v) -> String`: `v` como String si está en `TEMAS_VALIDOS`, si no `TEMA_DEFAULT`.

Backward compatible: config existente sin `tema` → `oscuro`.

### 3. `scripts/preferencias.gd` + `scenes/Preferencias.tscn`

- Nueva señal: `aplicado(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int, tema: String)`.
- `abrir(paralelismo, timeout, auto_abrir, intervalo, tema)`: fija `%Tema` al id del tema recibido.
- `_on_guardar()` emite `tema` con `%Tema.get_selected_id() as String`.
- `Preferencias.tscn`: fila "Tema" con `[name="Tema" type="OptionButton"]`, items `claro` (Claro) y `oscuro` (Oscuro).

### 4. `scripts/main.gd`

- `_ready()`: tras `_config_store = ConfigStoreScript.new()` y `cargar()`, llamar `TemaStoreScript.aplicar(cfg.get("tema", "oscuro"), self)` **antes** de `_refrescar_vista()` (así la lista inicial ya nace con el tema).
- `preferencias.aplicado.connect(_aplicar_preferencias)` ya existe; la firma se amplía con `tema`:
  `func _aplicar_preferencias(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int, tema: String) -> void`
- Dentro: aplicar el tema (`TemaStoreScript.aplicar(tema, self)`), guardar con el `tema`, y re-pintar la lista (`_refrescar_vista()` o `_aplicar_filtro()`) para que los items se regeneren con la nueva paleta.

### 5. `scripts/list_item.gd`

- Sustituir los colores literales por las consultas a la paleta:
  - `setup()`: indicador "Sin comprobar" y labels de texto → `TemaStoreScript.color_estado(null)` y colores de texto/paleta.
  - `aplicar_estado(ok, ...)`: verde/rojo/gris → `TemaStoreScript.color_estado(ok)`.
  - `_pintar_estado(texto, color)`: el color se recibe ya resuelto desde la paleta (los llamadores usan `color_estado`).
- Así los items dinámicos (los de la lista, creados por `main.gd`) se pintan siempre con el tema activo.

## Flujo de datos

```text
[arranque] _ready()
  -> _config_store.cargar() -> cfg.claro|oscuro
  -> TemaStoreScript.aplicar(tema, self)  # fondos + textos de toda la UI
  -> _refrescar_vista()                    # items con paleta activa

[Preferencias] usuario elige Claro/Oscuro -> Guardar
  -> aplicado.emit(..., tema)
  -> _aplicar_preferencias(..., tema)
  -> TemaStoreScript.aplicar(tema, self)
  -> _config_store.guardar(..., tema)
  -> _refrescar_vista()
```

## Manejo de errores / mantenibilidad

- `tema_store.gd` no conoce UI ni main; solo recibe `modo` y `root` y muta colores de nodos por rol. Mantiene la separación store/UI.
- Toda la paleta vive en un único fichero (`tema_store.gd`); añadir un color futuro = tocar una tabla.
- `normalizar()` garantiza que un valor corrupto de `config.json` nunca rompa la app (cae a "oscuro").
- Aplicar el tema dos veces (idempotente) no cambia colores: en oscuro se restaura el set original; en claro se re-mapean los mismos literales.

## Testing

**Nuevo `tests/test_tema_store.gd`** (SceneTree):

1. `paleta()` por defecto es el set oscuro y contiene los colores clave de estado.
2. `color_estado(true) == verde`, `color_estado(false) == rojo`, `color_estado(null) == gris` de la paleta.
3. `aplicar("claro", root)` con un mini-árbol construido en el test: un `ColorRect` "Fondo" cambia al claro; un `Label` con `font_color` literal del set oscuro (`0.75`) cambia a `0.30`; un `Label` con el rojo de error re-mapea al rojo claro.
4. `aplicar("oscuro", root)` restaura los valores oscuros (y es idempotente: aplicar dos veces el mismo modo no modifica colores).
5. Un `Label` sin `font_color` overlay (default) no se toca en ningún modo.

**Integración en `tests/test_main_barra.gd`:**

6. `_config_store.cargar()` sin archivo → `tema == "oscuro"`.
7. `_aplicar_preferencias(3, 10.0, false, 30, "claro")` guarda y aplica: `_config_store.cargar().get("tema") == "claro"` y la paleta activa es la clara.
8. Tras aplicar "claro", `TemaStoreScript.color_estado(true)` devuelve el verde claro.
9. `_ready` aplica el tema del config al arrancar (un config con `tema = "claro"` deja la paleta activa en claro).

## Entregables

- `scripts/tema_store.gd` — nuevo store (paletas, `color_estado`, `aplicar`, `normalizar`).
- `tests/test_tema_store.gd` — suite nueva.
- `scripts/config_store.gd` — campo `tema` + `_tema_ok`.
- `scripts/preferencias.gd` — OptionButton `%Tema`, señal `aplicado` ampliada.
- `scenes/Preferencias.tscn` — fila "Tema".
- `scripts/main.gd` — aplicar en `_ready` y `_aplicar_preferencias`.
- `scripts/list_item.gd` — colores desde la paleta.
- `tests/test_main_barra.gd` — checks de integración.