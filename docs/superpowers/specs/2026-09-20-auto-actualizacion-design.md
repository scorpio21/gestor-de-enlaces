# Diseño — #27 Auto-actualización o aviso de nueva versión

Fecha: 2026-09-20

## Objetivo

Comparar la versión de `project.godot` (`application/config/version`) con la última release de GitHub (`https://api.github.com/repos/scorpio21/gestor-de-enlaces/releases/latest`) y avisar al usuario si hay una versión nueva, con enlace a la release. Comprobación silenciosa al arrancar + opción manual en el menú Utilidades.

## Decisiones de diseño

1. **Comprobar al arrancar** (silencioso en segundo plano, tras ~1 s) **y manualmente** vía `Utilidades > Comprobar actualizaciones…`. Sin comprobación periódica (YAGNI).
2. **Aviso 1 vez por versión**: al cerrar el aviso (o pulsar "Ver release") se persiste `ultima_version_vista` en `config.json`; no se vuelve a avisar de esa versión.
3. **Silencio sin red** en modo automático (sin error visible); la comprobación manual **siempre informa** del resultado (nueva / al día / error).
4. **Aviso en diálogo modal** (`ConfirmationDialog`: "Ver release" / "Cerrar").
5. **Arquitectura A**: lógica pura (`versiones.gd`, RefCounted, testeable sin red) + transporte (`actualizador.gd`, Node con `HTTPClient`, patrón de `link_checker.gd`). Sin HTTPRequest (el repo ya usa HTTPClient).

## Alcance

- Nuevo `scripts/versiones.gd` — comparación semver y parse del JSON de `releases/latest` (puro, sin red).
- Nuevo `scripts/actualizador.gd` — Node con `HTTPClient` que hace el GET y emite señal `terminado(Dictionary)`.
- `scripts/config_store.gd` — campo `ultima_version_vista: String` persistido.
- `scripts/main.gd` — instancia `actualizador`, comprueba al arranque (solo si `not _es_headless()`) y por menú; gestiona el diálogo.
- `scenes/Main.tscn` — `%DialogoActualizacion` (`ConfirmationDialog`) + item Utilidades id 4.
- **Sin cambios** en el formato de catálogo ni en las demás ventanas `.tscn`.

## Arquitectura

### 1. `scripts/versiones.gd` (RefCounted, funciones estáticas puras)

```gdscript
class_name Versiones
extends RefCounted

static func comparar(nueva: String, actual: String) -> int
static func parsear_release(json_texto: String) -> Dictionary
static func manejar_tag(tag: String) -> String
```

- `manejar_tag`: elimina prefijo `v` y espacios, devuelve `String.strip_edges()` sin `v` inicial.
- `comparar`: divide por `.`, convierte cada componente a entero (no numérico → 0), rellena con 0 hasta la longitud máxima; `-1` si actual es mayor, `1` si nueva es mayor, `0` si iguales.
- `parsear_release`: dado el JSON crudo de `releases/latest`, devuelve `{version, url}` con `version = manejar_tag(tag_name)` y `url = html_url`; `{}` si no es objeto con `tag_name` no vacío y `html_url` string. (No `%JSON.parse` si el texto no empieza por `{`.)

### 2. `scripts/actualizador.gd` (Node, HTTPClient — patrón link_checker)

- `const URL_API := "https://api.github.com/repos/scorpio21/gestor-de-enlaces/releases/latest"`, `const TIMEOUT := 8.0`, `const USER_AGENT := "GestorAO/1.0 (auto-actualizacion)"`.
- Métodos privados reutilizando el estilo de `link_checker.gd`: `_connect_to_host` con `TLSOptions.client()`, `_request` GET con User-Agent, `_leer_respuesta` que acumula el body hasta el final y parsea con `versiones.parsear_release`.
- `comprobar()`: resetea, `_activo = true`, `set_process(true)`, conecta. Si se llama con una petición en vuelo, no hace nada (guard `if _activo: return`).
- Emite **una única** señal al terminar (con o sin error), luego `set_process(false)` y `queue_free()`:
  ```gdscript
  signal terminado(resultado: Dictionary)  # {nueva: bool, version: String, url: String, error: String}
  ```
- `resultado.error` no vacío (con mensaje) en: tiempo agotado, resolución fallida, conexión fallida, TLS, HTTP ≠ 200, JSON no parseable.
- `nueva` se calcula dentro de `actualizador` con `versiones.comparar(version, _version_actual()) == 1`. `_version_actual()` lee `ProjectSettings.get_setting("application/config/version", "0.0.1")`.

### 3. `scripts/config_store.gd`

- `ULTIMA_VERSION_DEFAULT := ""`.
- `cargar()` y `guardar()` añaden `"ultima_version_vista": _string_ok(v.get("ultima_version_vista", ULTIMA_VERSION_DEFAULT))`.
- `_string_ok(v) -> String`: devuelve `v` si es `String`, si no `""`.

### 4. `scripts/main.gd`

- Preload `ActualizadorScript` (`res://scripts/actualizador.gd`).
- En `_ready()`, tras el arranque, si `not _es_headless()`: `_lanzar_comprobacion_auto()` que dispara la con `await get_tree().create_timer(1.0).timeout`.
- `_on_utilidades_id(id)`: añadir `elif id == 4: _comprobar_actualizaciones(true)`.
- `_comprobar_actualizaciones(manual: bool)`:
  - Si `_es_headless()`: muestra (en manual) el diálogo "No se pudo comprobar…" y vuelve.
  - Si hay petición en vuelo, vuelve.
  - Crea el nodo `actualizador`, lo añade como hijo, conecta `terminado`, llama `comprobar()`.
  - Para testabilidad: la creación va por un método `_nuevo_actualizador() -> Node` (devuelve `ActualizadorScript.new()`); el test inyecta un fake sobreescribiendo `_nuevo_actualizador()`.
- `_on_actualizacion_terminado(resultado, manual)`:
  - `nueva` y `version != config.ultima_version_vista` → abrir `%DialogoActualizacion` en modo nueva.
  - `manual` y no-nueva → diálogo "Estás al día (vX.X.X)".
  - `manual` y `error` → diálogo "No se pudo comprobar actualizaciones."
  - El diálogo guarda el flag del modo (nueva/manual/error) para el callback del botón.
- `%DialogoActualizacion.confirmed → _on_actualizacion_ver()`: `OS.shell_open(url)`, persiste `ultima_version_vista = version`, `_config_store.guardar(...)` con los valores actuales, cierra.
- `%DialogoActualizacion.canceled → _on_actualizacion_cerrar()`: persiste `ultima_version_vista = version`, cierra.
- "Ver release" no disponible cuando `url` vacía → botón OK deshabilitado o escondido.

### 5. `scenes/Main.tscn`

- Item en Utilidades: `"Comprobar actualizaciones…"` id 4.
- Nodo `%DialogoActualizacion` (`ConfirmationDialog`, `unique_name_in_owner = true`):
  - `title = "Nueva versión disponible"`
  - `ok_button_text = "Ver release"`, `cancel_button_text = "Cerrar"`
  - `dialog_text` set desde código según modo.

## Flujo de datos

```text
[_ready] → (not headless) tras 1 s → actualizador.comprobar()
  → terminado({nueva, version, url, error})
  → nueva && version != ultima_version_vista → diálogo
  → error / no-nueva → silencio (auto)

[Utilidades > Comprobar actualizaciones…] → actualizador.comprobar()
  → nueva && no vista      → diálogo "Nueva versión X disponible"
  → actual                 → diálogo "Estás al día (vX)"
  → error                  → diálogo "No se pudo comprobar actualizaciones."
  → headless               → diálogo "No se pudo comprobar actualizaciones."

[Cerrar / Ver release] → persistir ultima_version_vista = version
```

## Manejo de errores / mantenibilidad

- `versiones.gd` no conoce UI ni HTTP: strings → Dictionary/int, sin efectos.
- `actualizador.gd` nunca lanza: todo fallo termina en señal con `error` no vacío; timeout ~8 s.
- `main.gd` es el único que muestra UI.
- `ultima_version_vista` corrupta → `""` (vuelve a avisar): no rompe nada.
- Headless/CI nunca hace peticiones de red.

## Testing

**Nuevo `tests/test_versiones.gd`** (sin red):

1. `comparar("1.2.0","0.1.0") == 1`, `comparar("0.1.0","1.2.0") == -1`, `comparar("0.1.0","0.1.0")==0`.
2. `comparar("1.2.10","1.2.9") == 1`.
3. `comparar("2.0","1.5.1") == 1` y `comparar("v2.0","2.0") == 0`.
4. `comparar("1.a","1.0") == 0` (no numérico → 0).
5. `parsear_release('{"tag_name":"v2.0","html_url":"https://github.com/scorpio21/gestor-de-enlaces/releases/tag/v2.0"}')` → `{version:"2.0", url:"..."}` y `manejar_tag("v2.0") == "2.0"`.
6. `parsear_release("{no json")` → `{}`; `parsear_release('{"tag_name":""}')` → `{}`; `parsear_release('[1,2]')` → `{}`.

**Integración en `tests/test_main_barra.gd`** (sin red):

7. El menú Utilidades tiene el item id 4 `"Comprobar actualizaciones…"`.
8. `main.get_node("%DialogoActualizacion")` existe, con `ok_button_text == "Ver release"` y `cancel_button_text == "Cerrar"`.
9. Con un fake del `actualizador` (patrón `_FakeHistorial` de `test_main_barra:486`) reemplazando `_nuevo_actualizador()` de `main_script`: el fake emite `terminado({nueva:true, version:"2.0", url:"...", error:""})` → `%DialogoActualizacion` visible y texto indica "2.0".
10. Emitir en modo manual `terminado({nueva:false, version:"0.1.0", url:"", error:""})` → diálogo visible "0.1.0" (modo al día). Y con `error` → texto de error.
11. Cerrar (cancel) con versión "2.0" → `config.ultima_version_vista == "2.0"`.

**Ampliación `tests/test_config_store.gd`:**

12. `ultima_version_vista` default `""`, se persiste/recupera, y no-String → `""`.

Batería: de 20 → **21 suites** (`test_versiones.gd`).

## Entregables

- `scripts/versiones.gd` — comparación + parse (puro).
- `tests/test_versiones.gd` — suite nueva.
- `scripts/actualizador.gd` — Node HTTP.
- `scripts/config_store.gd` — campo `ultima_version_vista`.
- `scripts/main.gd` — comprobación auto + manual + diálogo.
- `scenes/Main.tscn` — `%DialogoActualizacion` + item Utilidades id 4.
- `tests/test_main_barra.gd` — checks de integración.
- `tests/test_config_store.gd` — checks de `ultima_version_vista`.