# Spec — Grupo C: Empaquetado, CI, logs y diagnóstico

**Fecha:** 2026-09-18
**Issues:** #26 (presets + CI con tests headless) · #28 (logs persistentes + exportar diagnóstico) · #29 (icono, versión y metadatos)
**Estado:** aprobada por el usuario

---

## Resumen

Convertir GestorAO en un producto empaquetable: presets de exportación para los 3 sistemas operativos, un workflow de GitHub Actions que ejecute los tests headless y genere los ejecutables, logs persistentes rotativos en `user://logs/`, un botón "Exportar diagnóstico" que empaquete logs + datos, y un icono propio de la app con número de versión legible en la ventana.

Fuera de alcance: #27 (auto-actualización) — depende de un canal de distribución externo, se difiere.

---

## Requisitos

### #26 — Presets de exportación y CI

- `export_presets.cfg` con tres presets: **Windows**, **Linux**, **macOS**.
  - Windows: `.exe`, ejecutable único con PCK embebido, icono `Assets/icon/icon.ico`.
  - Linux: binario sin extensión, PCK embebido.
  - macOS: `.app`, PCK embebido, icono `Assets/icon/icon.icns`. No se firma ni se notariza (sin cuenta de desarrollador).
- Nuevo `.github/workflows/ci.yml`, disparador `push` + `pull_request` a `main`:
  - Un único job sobre `ubuntu-latest`.
  - Instalación de Godot 4.7.2 estable y sus export templates (descarga desde godotengine/godot, con cache de GitHub Actions).
  - Paso **tests headless**: ejecuta la batería completa (las 12 suites de `tests/`) con `--headless --script`, y falla si alguna no termina con exit 0 / `TESTS OK`. Script compartido para CI y uso local: `tests/run_battery.sh`.
  - Paso **exportación**: `--export-release` de los tres presets en un job (macOS exportable desde Linux).
  - Paso **artifacts**: sube los tres ejecutables como artifacts del run (`actions/upload-artifact`). El artefacto macOS es el bundle `.app` comprimido en zip (no se genera `.dmg`).
- Nuevo `AGENTS.md` en la raíz del repo que documente:
  - Cómo regenerar `export_presets.cfg` tras cambiar presets en el editor.
  - Cómo ejecutar la batería localmente (`tests/run_battery.sh`).

### #28 — Logs persistentes y exportar diagnóstico

- Logger propio en `scripts/logger.gd` (const/preload, sin `class_name`), iniciado explícitamente desde `main.gd`.
  - `iniciar(base := "user://", max_bytes := 512 * 1024)` crea `base/logs/` y abre `app.log` y `scan.log`. `max_bytes` es configurable para que los tests puedan forzar rotación con un umbral pequeño.
  - Rotación por tamaño: al superar `max_bytes` se renombra a `.log.1` y se abre uno nuevo (máx. 2 ficheros por tipo).
  - Métodos: `app(tipo: String, msg: String)` → `[APP][tipo] <ts> msg` en `app.log`; `scan(url, resultado, detalle)` → `[SCAN] <ts> url resultado detalle` en `scan.log`.
- Invocación desde el código:
  - `main.gd`: inicio, fallo de guardado, limpieza, historial abierto, diagnóstico exportado, escaneo terminado.
  - `link_checker.gd`: resultado de cada comprobación (`valido` / `caido` / `timeout`), con detalle (HTTP code o mensaje).
- Botón **"Exportar diagnóstico…"** en el menú Utilidades (`main.gd`):
  - `FileDialog` de guardado para la ruta final (`*.zip`).
  - `ZIPPacker` empaqueta: `app.log`, `scan.log`, `enlaces.json`, `estados.json`, `borrados.json`, `config.json` (los que existan) y `info.txt`.
  - `info.txt`: `App=GestorAO`, `Version=<config/version>`, `Godot=<Engine.get_version_info()>`, `OS=<OS.get_name()>`, `Fecha=<Time.get_datetime_string_from_system()>`, `Entradas=<count>`.
  - Mensaje en `%Progreso` al terminar. Los ficheros que no existan se omiten sin error.

### #29 — Icono, versión y metadatos

- Nuevo `Assets/icon/`:
  - `icon.svg` — origen, concepto "Enlace + check" con paleta ámbar (#e8862a→#ffc46b) sobre fondo oscuro (#10141c).
  - `icon_256.png`, `icon.ico` (16/32/48/256), `icon.icns` (16/32/128/256/512).
  - Generación vía `scripts/generar_iconos.gd` (Godot puro, sin binarios externos; renderiza el SVG a PNG y escribe `.ico`/`.icns` con blobs PNG estándar).
- `project.godot`:
  - `config/name="GestorAO"` (ya existe).
  - `config/version="0.1.0"` (bump).
  - `config/icon="res://Assets/icon/icon.svg"`.
  - `display/window/title="GestorAO v0.1.0"` para que el título de la ventana muestre la versión.
- `main.gd:89`: `%Version` muestra `v` + `ProjectSettings.get_setting("application/config/version")` (ya funciona; se actualiza por el bump).

---

## Decisiones de diseño (confirmadas en brainstorm)

- **CI exporta los 3 OS** en un solo job Linux (Godot exporta multiplataforma con las templates).
- **Logger propio + llamadas explícitas** (Godot 4 no expone hook GDScript para `push_error`).
- **Diagnóstico**: datos de `user://` + logs + manifiesto `info.txt`; sin capturas (`Assets/png/` se excluye por peso).
- **Icono**: "Enlace + check en esquina", paleta ámbar/fantasy (elegido por el usuario).
- **Versión**: `0.1.0` en `project.godot`, título de ventana y `%Version`.

---

## Archivos afectados

| Archivo | Cambio |
|---|---|
| `export_presets.cfg` | Nuevo — 3 presets |
| `.github/workflows/ci.yml` | Nuevo — CI tests + export |
| `tests/run_battery.sh` | Nuevo — batería compartida |
| `AGENTS.md` | Nuevo — regeneración presets + battery |
| `scripts/logger.gd` | Nuevo — logger rotativo |
| `scripts/generar_iconos.gd` | Nuevo — generador de iconos |
| `Assets/icon/*` | Nuevo — svg/png/ico/icns |
| `scripts/main.gd` | Menú + logger + exportar diagnóstico |
| `scripts/link_checker.gd` | Log de cada comprobación |
| `project.godot` | Version/icon/title |
| `docs/` | Spec y plan |

---

## Testing

- **Suites nuevas** (en `tests/`):
  - `test_logger.gd`: iniciar crea directorio y ficheros; `app`/`scan` escriben líneas `[APP]`/`[SCAN]`; rotación al superar 512 KB genera `.log.1` (test con tamaño reducido o relleno); sobre base temporal `user://__test_logger__`.
  - `test_exportar_diagnostico.gd`: genera el zip a `user://__test_diag__`, verifica que contiene los ficheros presentes, que `info.txt` incluye las claves `App`/`Version`/`OS`, y que un fichero inexistente (p. ej. `borrados.json` ausente) se omite sin error.
  - `test_iconos.gd`: tras `generar_iconos.gd`, existen `icon.svg`, `icon_256.png`, `icon.ico`, `icon.icns` con tamaños >0 y las cabeceras correctas (`\x00\x00\x01\x00` para ICO, `icns` para ICNS).
  - `test_proyecto.gd`: `project.godot` contiene `config/version="0.1.0"`, `config/icon` apunta a `Assets/icon/icon.svg`, y `%Version` (o `ProjectSettings`) lee la clave.
- **CI**: batería completa verde en el workflow (es la misma que local).

---

## Criterios de salida

- `tests/run_battery.sh` completa las 12 suites con exit 0 en local y en CI.
- `--headless --export-release` funciona para los 3 presets sin errores.
- La app escriba logs en `user://logs/` y genere el zip de diagnóstico solicitado.
- `project.godot` con `0.1.0`, título de ventana con versión, y `Assets/icon/icon.ico`/`.icns` válidos.
- Issues #26, #28, #29 cerrados tras push a `origin/main`.