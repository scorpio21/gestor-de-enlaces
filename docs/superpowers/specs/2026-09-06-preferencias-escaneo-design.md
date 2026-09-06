# Preferencias de escaneo: paralelismo y timeout configurables — Diseño

> Issue #7 — [Escaneo] Preferencias de escaneo: paralelismo y timeout configurables
> Fecha: 2026-09-06

## Objetivo

Exponer en un diálogo de preferencias el número de verificaciones en paralelo (hoy fijado a 3 en `main.gd`, constante `MAX_PARALELO`) y el timeout por enlace (hoy fijado a 10 s en `link_checker.gd`, constante `TIMEOUT_S`). Persistir en `user://config.json`.

## Decidido con el usuario

- **Alcance:** solo paralelismo y timeout. `MAX_REDIRECTS` (6) y demás constantes del checker permanecen fijas. YAGNI.
- **Aplicación:** los cambios se aplican desde la próxima tanda de comprobación. Las verificaciones en vuelo conservan su configuración original. No se interrumpe nada.
- **Menú de acceso:** «Preferencias…» en el menú Utilidades (junto a «Agregar»), reutilizando el patrón existente.
- **Rangos y valores por defecto:** paralelismo 1–8 (default 3), timeout 3–60 s (default 10.0 s).
- **Enfoque:** store de config + paso de parámetros. Sin autoloads, sin tocarse `project.godot` para config de runtime.

## Estado actual del código

- `scripts/main.gd:6` — `const MAX_PARALELO := 3`; el bucle `_lanzar_siguiente()` (main.gd:208) limita `_en_vuelo` con esta constante.
- `scripts/link_checker.gd:5` — `const TIMEOUT_S := 10.0`; `_process()` (link_checker.gd:41) compara `_transcurrido >= TIMEOUT_S`.
- `scripts/list_item.gd:71` — `verificar()` instancia el checker con `LinkCheckerScript.new()` y lo añade como hijo; llama `_checker.comprobar(url)`.
- Patrón de persistencia: `scripts/estado_store.gd` (RefCounted con `_init(base)` y lecturas JSON tipo-safe).
- Patrón de diálogo: `scenes/AgregarEnlace.tscn` (Window, `exclusive`, `initial_position = 2`, estructura Margen/Columna + botones Guardar/Cancelar) abierto desde el menú Utilidades.

## Arquitectura

### `scripts/config_store.gd` (nuevo, RefCounted)

Patrón de `estado_store.gd`. Persiste la configuración en `user://config.json`.

- `func _init(base := "user://") -> void` — mismo esquema de `estado_store` (`_ruta()`).
- `func cargar() -> Dictionary` — devuelve `{"paralelismo": int, "timeout": float}`. Si `config.json` no existe, el JSON está roto o los tipos no coinciden → defaults (`3`, `10.0`). Los valores fuera de rango se clampean a 1–8 / 3–60 en `cargar()`.
- `func guardar(paralelismo: int, timeout: float) -> bool` — escribe `{"paralelismo": int, "timeout": float}` en `config.json` con `JSON.stringify(..., "\t")`. `false` si no se puede abrir el archivo para escritura.
- Helpers privados `_leer_json` / `_escribir_json` / `_ruta` (mismo patrón que `estado_store`).

### `scenes/Preferencias.tscn` (nuevo, Window)

Mismo patrón visual que `AgregarEnlace.tscn`: Window `exclusive`, `initial_position = 2`, `unresizable`; nodo `Fondo` (ColorRect ~0.12), `Margen` → `Columna` (VBoxContainer, separation 10).

Contenido:
- `%Paralelismo` — `SpinBox` (min 1, max 8), etiqueta «Verificaciones en paralelo».
- `%Timeout` — `SpinBox` (min 3, max 60, step 1, suffix « s»), etiqueta «Timeout por enlace (segundos)».
- `%Error` — Label rojo de retroalimentación (reutiliza el estilo de `AgregarEnlace`).
- `%BotonCancelar` / `%BotonGuardar`.

Script `scripts/preferencias.gd extends Window`:
- `signal aplicado(paralelismo: int, timeout: float)`.
- `func abrir(paralelismo: int, timeout: float) -> void` — precarga los SpinBox y `popup_centered()`.
- Guardar: valida (SpinBox ya garantiza rango), emite `aplicado(paralelismo, timeout)` y `hide()`.
- Cancelar/`close_requested`: `hide()` sin emitir.

### `scripts/link_checker.gd` (modificar)

- `const TIMEOUT_S := 10.0` se convierte en `var timeout_s: float = 10.0` (propiedad, default de fábrica 10.0 → `list_item.gd` sin config sigue funcionando).
- `_process()` compara `_transcurrido >= timeout_s`.

### `scripts/list_item.gd` (modificar)

- Nueva `func configurar_timeout(segundos: float) -> void` que guarda el valor (default `10.0`).
- En `verificar()`, antes de `_checker.comprobar(url)`: `_checker.timeout_s = <valor guardado>`.

### `scripts/main.gd` (modificar)

- Eliminar `const MAX_PARALELO := 3`.
- Nuevas vars `_paralelismo := 3` y `_timeout := 10.0`.
- `const ConfigStoreScript := preload("res://scripts/config_store.gd")`.
- `scenes/Main.tscn`: añadir `[node name="VentanaPreferencias" parent="." instance=ExtResource("3_preferencias")]` con `unique_name_in_owner = true` (mismo patrón que `VentanaAgregar`).
- En `_ready()`, `@onready var preferencias: Window = %VentanaPreferencias`; tras `_cargar_datos()`: crear `config_store`, cargar config, asignar `_paralelismo` / `_timeout`, conectar `preferencias.aplicado`.
- Menú Utilidades: añadir «Preferencias…» (id 1) en `_configurar_menus()`; `_on_utilidades_id(1)` abre el diálogo con `abrir(_paralelismo, _timeout)`.
- `_lanzar_siguiente()`: usar `_paralelismo` en vez de `MAX_PARALELO`.
- `_mostrar_lista()`: al hacer `item.setup(...)`, llamar `item.configurar_timeout(_timeout)`.
- Al recibir `aplicado(paralelismo, timeout)`: asignar `_paralelismo` / `_timeout`, llamar `config_store.guardar(...)`; si falla la escritura, mostrar «No se pudo guardar la configuración.» en `%Progreso`. (La config en memoria se aplica de todos modos para la próxima tanda.)

## Flujo de datos

```
Main._ready ──► config_store.cargar() ──► _paralelismo, _timeout
                                              │
                                  Utilidades ▾ «Preferencias…»
                                              │
                                      Preferencias.abrir(p, t)
                                      SpinBox ├─ guardar → aplicado(p, t)
                                              └─ cancelar → hide
                                              ▼
Main _on_aplicado(p, t) ──► _paralelismo = p, _timeout = t
                              config_store.guardar(p, t) ──► user://config.json
                              (fallo → %Progreso)
Próxima tanda:
  _mostrar_lista() → item.configurar_timeout(_timeout)
  _lanzar_siguiente() → límite _en_vuelo < _paralelismo
  item.verificar() → _checker.timeout_s = timeout → comprobar(url)
```

## Manejo de errores

- `config.json` ausente, JSON roto o tipos incorrectos en disco → `cargar()` devuelve defaults (3 / 10.0). El arranque nunca falla por esto.
- Valores de disco fuera de rango → clamp silencioso a 1–8 / 3–60 en `cargar()`.
- Escritura fallida en `guardar()` → `false`; `main.gd` aplica la config en memoria igualmente (para la próxima tanda) y avisa en `%Progreso`.

## Testing

Harness headless (`extends SceneTree`), sin autoloads, sin red. Patrón de `test_estado_store.gd` para el store.

- **`tests/test_config_store.gd`** (crear): `ConfigStore.new()` con base temporal `user://__test_config__` (mismo patrón que `test_estado_store.gd` usa `user://__test_gestor__`) para no tocar la config real del usuario. Checks:
  1. Sin fichero → `cargar()` devuelve defaults (3 / 10.0).
  2. `guardar(5, 20.0)` + `cargar()` → recupera `5` / `20.0`.
  3. JSON roto en disco → defaults.
  4. Valores fuera de rango en disco (paralelismo 99, timeout 0.5) → clamp 8 / 3.
  5. Tipos incorrectos en disco (paralelismo string) → default.
- **`tests/test_preferencias.gd`** (crear): instanciar `Preferencias.tscn`, `abrir(5, 20.0)` → los SpinBox muestran 5 / 20.0; setear SpinBox y pulsar Guardar → recibe `aplicado(7, 15.0)`; Cancelar → no emite.
- **`tests/test_link_checker_timeout.gd`** (crear): verificar que `timeout_s` es una propiedad asignable con default `10.0`, y que asignar `timeout_s` se refleja en la instancia del checker (sin realizar peticiones de red).
- **Regresión existente:** `test_main_barra.gd`, `test_gestor_contadores.gd`, `test_list_item.gd`, `test_gestor_imagenes.gd`, `test_estado_store.gd` siguen en verde. Smoke de `Main.tscn` sin `Parse Error|SCRIPT ERROR|ERROR`.

## Criterios de aceptación (AC)

1. `user://config.json` se crea al guardar en preferencias con `{"paralelismo": N, "timeout": N.N}`.
2. Al arrancar sin config, paralelismo = 3 y timeout = 10.0 (las constantes actuales).
3. Cambiar paralelismo a N → la siguiente «Comprobar enlaces» lanza como máximo N verificaciones concurrentes.
4. Cambiar timeout a T → los checkers de la siguiente tanda expiran a los T segundos.
5. Los cambios no afectan a verificaciones en vuelo.
6. `config.json` corrupto o con valores fuera de rango no rompe el arranque (defaults / clamp).
7. El diálogo se abre desde Utilidades → «Preferencias…», precargado con los valores actuales.
8. Cancelar / cerrar no modifica la configuración.
9. Sin regresiones: todos los tests existentes en verde y smoke limpio.

## No scope (fuera de esta iteración)

- `MAX_REDIRECTS` y el resto de constantes del checker.
- Aplicación inmediata a verificaciones en vuelo.
- Más ajustes en el diálogo de preferencias.
- Documentación del proyecto (README) — se actualizará solo si el usuario lo pide.