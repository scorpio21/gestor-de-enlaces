# Plan de implementación: Internacionalización ES/EN (issue #30)

- **Repo:** `K:\gestor-de-enlaces` | Rama: `main` | Motor: Godot 4.7.2
- **Especificación aprobada:** `docs/superpowers/specs/2026-09-23-internacionalizacion-design.md` (commit `d8ad091`)
- **GitHub:** [scorpio21/gestor-de-enlaces#30](https://github.com/scorpio21/gestor-de-enlaces/issues/30)

## Objetivo

Añadir soporte de idioma español/inglés a toda la UI visible usando el CSV nativo de Godot (`res://locale/gestor_es_en.csv`), selector "Idioma" con banderas en Preferencias, autodetección del idioma del SO en el primer arranque, y cierre del issue al terminar.

## Decisiones de diseño (resumen de la spec)

- CSV `keys,es,en`; clave = cadena ES actual (incluidos formatos `%d`/`%s`).
- Registro en `project.godot` → `[internationalization] locale/translations=PackedStringArray("res://locale/gestor_es_en.csv")` (**staging selectivo**, `project.godot` tiene cambios ajenos sin commitear).
- Auto-traducción de escenas vía `auto_translate_mode` (default). Los `text=`/`title=` de escena y las asignaciones runtime a propiedades de texto (incluidos `add_item`/`add_icon_item` de PopupMenu y `dialog_text`/`ok_button_text` de ConfirmationDialog) se traducen en renderizado. Solo los literales runtime **con formato `%`** se envuelven en `tr(...)` (el template es la clave; los argumentos quedan fuera).
- **Los datos en disco NO cambian de idioma** (estados del catálogo, categorías, mensajes de historial en ficheros). El ES se conserva en `data/`; la traducción se aplica solo en pintado vía `tr()`.
- Alcance: toda la UI visible. Excluidos: logs, informes exportados (JSON/TXT), identificadores, `FileDialog` del SO ("Open a File"), etiqueta de versión (`v0.0.1`), placeholders de URL.

## Convenciones (AGENTS.md)

- Sin comentarios en scripts; tabs; `.gd` nuevo sin `class_name` (preload-const).
- Tests SceneTree con base `user://__test_*__` que se limpian; imprimen `TESTS OK` y `quit(0)`.
- Runner Windows:
  ```powershell
  Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
  & "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_<area>.gd --quit-after 700
  ```
- No tocar los ficheros con trabajo ajeno sin commitear: `data/data.json`, `data/servidores.json`, `scenes/ListItem.tscn`, `scenes/Main.tscn`, `scripts/tema_store.gd`, `tests/test_tema_store.gd` (+ untracked de `addons/`, `data/data2.json`, iconos, planes antiguos).
- Al terminar: cerrar el issue #30 en GitHub.

## Comandos de ayuda

- Dump de claves para autoría CSV: `godot --headless --path . --script res://scripts/extraer_cadenas.gd --quit-after 500` imprime las claves ordenadas que deben estar en el CSV (el fichero CSV se autoría a mano con estas claves).
- Batería completa (se ejecuta en la Tarea 6):
  ```powershell
  Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force
  $suites = Get-ChildItem "K:\gestor-de-enlaces\tests\test_*.gd" | ForEach-Object { $_.BaseName }
  foreach ($s in $suites) {
    & "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script "res://tests/$s.gd" --quit-after 700
    if ($LASTEXITCODE -ne 0) { "FALLOS: $s" }
  }
  ```
- Boot headless: mismo binario, sin `--script`, con `--quit-after 500`; esperar `exit=0` y ausencia de `SCRIPT ERROR`.

---

# Tarea 1 — `config_store` guarda el idioma (TDD)

**Archivos:** `scripts/config_store.gd`, `tests/test_config_store.gd`. Sin tocar `project.godot` ni escenas.

## RED

En `tests/test_config_store.gd` añadir casos: guardar `idioma`, cargar por defecto `""`, y que un valor inválido se normalice a `""`.

La validación usa el patrón `_orden_columna_ok` ya existente en el fichero (constante + normalización en lectura y en `guardar`). Contrato:

- Constantes nuevas en `scripts/config_store.gd`:
  ```gdscript
  const IDIOMAS_VALIDOS := ["", "es", "en"]
  const IDIOMA_DEFAULT := ""
  ```
- `cargar()` devuelve `{"idioma": ...}` normalizado: `idioma` tal cual si está en `IDIOMAS_VALIDOS`, si no `IDIOMA_DEFAULT`.
- `guardar(...)` incluye el campo `idioma` normalizado igual que el resto de campos y rechaza (devuelve `false`) si no es válido, sin persistir.

Casos de test (siguiendo el estilo de los tests de ordenación existentes):

1. `cargar()` por defecto devuelve `idioma == ""`.
2. `guardar(idioma = "en")` → `cargar().idioma == "en"`.
3. `guardar(idioma = "fr")` → devuelve `false` y no se persiste (base limpia en `user://__test_config_store__`, mim no válida).
4. Escribir manualmente `idioma="xx"` en el fichero de config y `cargar()` normaliza a `""`.

## GREEN

Editar `scripts/config_store.gd`:

- Añadir las dos constantes.
- En `cargar()`: devolver `idioma` normalizado.
- En `guardar()`: firmar con `idioma: String` como último parámetro; si `not idioma in IDIOMAS_VALIDOS` → `return false`; incluir `"idioma": idioma` en el diccionario persistido.
- Actualizar la llamada interna/callers de `guardar` que lo invoquen con los argumentos posicionales nuevos (el resto de callers se actualizan en Tareas 4 y 5; mantener la firma compatible añadiendo `idioma` con valor por defecto `IDIOMA_DEFAULT` para no romper `test_main_barra` aún, que se actualizará en la Tarea 5): `func guardar(paralelismo: int, timeout: int, auto: bool, intervalo: int, tema: String, idioma: String = IDIOMA_DEFAULT) -> bool`.

Tests: crear el caso 1 como RED a la vez que se añaden los 4 casos (el 1 pasa, el resto falla hasta implementar; correr con el runner de `test_config_store.gd`).

## GREEN verificado

Correr `test_config_store.gd` → `TESTS OK`, `quit(0)`.

## Commit

```
feat(config): #30 config_store guarda y valida el idioma
```

(Agregar con `git add scripts/config_store.gd tests/test_config_store.gd` y commit; no hay ajeno en estos ficheros.)

---

# Tarea 2 — Infraestructura de traducción: scanner + CSV + registro + `test_locale.gd` (TDD)

**Nuevos ficheros:** `scripts/extraer_cadenas.gd`, `res://locale/gestor_es_en.csv`, `tests/test_locale.gd`.
**Editado:** `project.godot` (staging selectivo).

## RED

Crear `tests/test_locale.gd` (SceneTree) con grupos:

**Grupo A — integridad del CSV** (usa `static func _leer_csv(path)` propio del test):
1. El fichero `res://locale/gestor_es_en.csv` existe y la cabecera es exactamente `keys,es,en`.
2. No hay claves duplicadas.
3. Todas las filas (excepto cabecera) tienen las 3 celdas no vacías.

**Grupo B — cobertura de escenas y scripts**: para cada cadena de `Extraer.ui_strings()`, existe como clave en el CSV.

**Grupo C** (funciones puras de idioma) y **Grupo D** (templates `%` con `tr()`) se añaden en la Tarea 5 junto a `scripts/idioma.gd` y los wraps; en esta tarea solo se implementan los Grupos A y B.

Para el RED inicial basta el Grupo A (falla: CSV no existe) y un esqueleto del Grupo B que fallará al no existir el CSV. Runner: `tests/test_locale.gd`.

## GREEN

### 1) `scripts/idioma.gd` (no en esta tarea)

(Solo se crea en la Tarea 5. El scanner no depende de él.)

### 2) `scripts/extraer_cadenas.gd` — scanner (literal, sin comentarios)

`extends SceneTree` (convención del repo para scripts ejecutables vía `--script`, como `generar_iconos.gd`) y `_initialize()` para el volcado CLI:

```gdscript
extends SceneTree

const PATRON_ESCENA := r'(?:^|\s)(?:text|title|placeholder_text|tooltip_text|dialog_text|ok_button_text|cancel_button_text)\s*=\s*"([^"]+)"'
const PATRON_SCRIPT_UI := r'\.(?:text|title|dialog_text|ok_button_text|cancel_button_text)\s*=\s*"([^"]+)"'
const PATRON_MENU := r'(?:add_item|add_icon_item)\([^"]*"([^"]+)"'
const ESCENAS := ["res://scenes/Main.tscn", "res://scenes/Preferencias.tscn", "res://scenes/AgregarEnlace.tscn", "res://scenes/ListItem.tscn", "res://scenes/Historial.tscn"]
const SCRIPTS_UI := ["res://scripts/main.gd", "res://scripts/preferencias.gd", "res://scripts/agregar_enlace.gd", "res://scripts/list_item.gd", "res://scripts/historial.gd"]
const EXTRA_VISIBLES := ["Válido", "Caído", "Sin comprobar", "Otro", "Cliente", "Servidor", "Códigos fuente", "Parche"]

static func ui_strings() -> Array[String]:
	var por_analizar := {}
	for ruta in ESCENAS:
		_volcar(FileAccess.get_file_as_string(ruta), RegEx.create_from_string(PATRON_ESCENA), por_analizar)
	for ruta in SCRIPTS_UI:
		_volcar(FileAccess.get_file_as_string(ruta), RegEx.create_from_string(PATRON_SCRIPT_UI), por_analizar)
		_volcar(FileAccess.get_file_as_string(ruta), RegEx.create_from_string(PATRON_MENU), por_analizar)
	for cadena in EXTRA_VISIBLES:
		por_analizar[cadena] = true
	return por_analizar.keys()

static func _volcar(src: String, regex: RegEx, destino: Dictionary) -> void:
	for m in regex.search_all(src):
		var txt := m.get_string(1).strip_edges()
		if txt.is_empty():
			continue
		if txt.begins_with("https"):
			continue
		if txt.begins_with("v0"):
			continue
		if txt.length() > 200:
			continue
		destino[txt] = true

func _initialize() -> void:
	var claves := ui_strings()
	claves.sort()
	for clave in claves:
		print(clave)
	quit(0)
```

> Nota: `Patron_escena` captura también `popup/item_N/text = "..."` y los `title` de ventanas; `Patron_script_ui` captura las asignaciones runtime (incluidos `dialog_text=...`, `ok_button_text=...`). `Patron_menu` captura `add_item("...", id)` **y** `add_icon_item(icono, "etiqueta")`. Los nombres de estados y categorías que se pintan desde variables (`categoria_display`, ternarios de estado) entran por `EXTRA_VISIBLES`; el template de historial `"%s - %s - %s"` cae por `PATRON_SCRIPT_UI`.

### 3) `res://locale/gestor_es_en.csv`

Regenerar y autorar:

1. Añadir la lista de claves definitiva usando el volcado CLI (`--script res://scripts/extraer_cadenas.gd`). El fichero inicial se crea a mano con cabecera `keys,es,en` y una fila por clave donde `es` = clave y `en` = traducción final (el test de integridad del Grupo A exige celdas `en` no vacías; el de cobertura del Grupo B exige que toda clave del scanner esté).

2. Reglas de autoría `en` (voz corta y directa, misma tono que ES, conservando los placeholders exactos `%d`/`%s`): las claves con formato se traducen manteniendo los especificadores; las claves de menú conservan la elipsis «…»; `"Otro"`→`"Other"`, `"Cerrar"`→`"Close"`, `"Guardar"`→`"Save"`, `"Cancelar"`→`"Cancel"`, `"Tema"`→`"Theme"`, `"Idioma"`→`"Language"`, `"Agregar"`→`"Add"`, `"Eliminar"`→`"Delete"`, `"Nombre"`→`"Name"`, `"Estado"`→`"Status"`, `"Fecha"`→`"Date"`, `"Imagen"`→`"Image"`.

   Traducciones de referencia (suministradas en el plan; el resto se autoran con el glosario y voz indicados):

   | es | en |
   |---|---|
   | Gestor de enlaces AO | Link manager AO |
   | Comprobar enlaces | Check links |
   | Buscar por nombre o descripción… | Search by name or description… |
   | Todos | All |
   | Válidos | Valid |
   | Caídos / no existen | Down / missing |
   | Sin comprobar | Not checked |
   | Rotos: %d | Broken: %d |
   | Activos: %d | Working: %d |
   | Total: %d | Total: %d |
   | Eliminar enlace | Delete link |
   | Limpiar capturas huérfanas | Clean orphan captures |
   | Limpiar | Clean |
   | Restaurar copia | Restore backup |
   | Restaurar | Restore |
   | ¿Restaurar el catálogo desde la copia de seguridad? | Restore the catalogue from the backup? |
   | Reanudar escaneo | Resume scan |
   | Reanudar | Resume |
   | Descartar | Discard |
   | Hay una comprobación pendiente. ¿Reanudar el escaneo? | A check is pending. Resume scanning? |
   | Comprobar actualizaciones | Check for updates |
   | Exportar catálogo JSON | Export JSON catalogue |
   | Guardar informe de disponibilidad | Save availability report |
   | Exportar diagnóstico | Export diagnostics |
   | Informe de disponibilidad | Availability report |
   | Importar. | Import… |
   | Exportar. | Export… |
   | Restaurar copia. | Restore backup… |
   | Salir | Quit |
   | Utilidades | Tools |
   | Agregar | Add |
   | Preferencias. | Preferences… |
   | Limpiar capturas huérfanas. | Clean orphan captures… |
   | Exportar diagnóstico. | Export diagnostics… |
   | Comprobar actualizaciones. | Check for updates… |
   | Agregar enlace | Add link |
   | Guardar cambios | Save changes |
   | Individual | Single |
   | Varias | Multiple |
   | Descripción | Description |
   | URL | URL |
   | Categoría | Category |
   | Elegir imagen… | Choose image… |
   | Quitar imagen | Remove image |
   | Una URL por línea | One URL per line |
   | No se pudo cargar la imagen. | Failed to load the image. |
   | El nombre no puede estar vacío. | The name cannot be empty. |
   | La URL no puede estar vacía. | The URL cannot be empty. |
   | La URL debe empezar por http:// o https://. | The URL must start with http:// or https://. |
   | Pega al menos una URL. | Paste at least one URL. |
   | Editar… | Edit… |
   | Subir | Move up |
   | Bajar | Move down |
   | Volver a comprobar | Re-check |
   | Copiar URL | Copy URL |
   | Historial… | History… |
   | Verificaciones en paralelo | Parallel checks |
   | Timeout por enlace (segundos) | Per-link timeout (seconds) |
   | Auto-escaneo | Auto-scan |
   | Comprobar enlaces al abrir | Check links on open |
   | Comprobar cada | Check every |
   | Desactivado | Disabled |
   | Cada 15 minutos | Every 15 minutes |
   | Cada 30 minutos | Every 30 minutes |
   | Cada 1 hora | Every 1 hour |
   | Oscuro | Dark |
   | Claro | Light |
   | Historial de disponibilidad | Availability history |
   | Sin historial | No history |
   | Válido | Working |
   | Caído | Down |
   | Otro | Other |
   | Cliente | Client |
   | Servidor | Server |
   | Códigos fuente | Source code |
   | Parche | Patch |
   | %d omitidos (ya existían o sin URL válida). | %d skipped (already existing or no valid URL). |
   | %d importados, %d omitidos. | %d imported, %d skipped. |
   | No se pudo importar el catálogo. | Could not import the catalogue. |
   | No se pudo guardar el catálogo. | Could not save the catalogue. |
   | Catálogo exportado (%d enlaces). | Catalogue exported (%d links). |
   | No se pudo guardar el informe. | Could not save the report. |
   | Informe %s guardado (%d enlaces). | %s report saved (%d links). |
   | No se pudo exportar el diagnóstico (%d errores). | Could not export diagnostics (%d errors). |
   | Diagnóstico guardado en %s. | Diagnostics saved to %s. |
   | No se pudo limpiar las capturas. | Could not clean the captures. |
   | No hay capturas huérfanas. | No orphan captures. |
   | ¿Borrar %d capturas huérfanas? | Delete %d orphan captures? |
   | No hay copia de seguridad disponible. | No backup available. |
   | No se pudo restaurar la copia. | Could not restore the backup. |
   | Catálogo restaurado desde la copia. | Catalogue restored from backup. |
   | No se pudo guardar el enlace. | Could not save the link. |
   | Ya existe: %s | Already exists: %s |
   | Enlace agregado: %s | Link added: %s |
   | No se pudo guardar el lote. | Could not save the batch. |
   | No se encontró el enlace. | Link not found. |
   | No se pudo procesar la imagen. | Could not process the image. |
   | Enlace actualizado: %s | Link updated: %s |
   | %d enlaces | %d links |
   | Nada que comprobar | Nothing to check |
   | Comprobando %d/%d. | Checking %d/%d. |
   | Listo: %d caídos de %d | Done: %d down of %d |
   | ¿Reanudar escaneo de %d enlaces? | Resume scanning %d links? |
   | Re-comprobando %s. | Re-checking %s. |
   | ¿Eliminar «%s» para siempre? | Delete “%s” forever? |
   | URL copiada: %s | URL copied: %s |
   | Enlace eliminado | Link deleted |
   | No se pudo guardar la configuración. | Could not save the settings. |
   | No se pudo guardar el orden. | Could not save the order. |
   | Nueva versión disponible | New version available |
   | Hay una nueva versión: %s | A new version is available: %s |
   | Ver release | View release |
   | Estás al día (v%s) | You are up to date (v%s) |
   | No se pudo comprobar actualizaciones. | Could not check for updates. |
   | %s - %s - %s | %s - %s - %s |

   Cualquier clave adicional que devuelva el volcado sigue el mismo glosario.

3. CSV con coma como separador; si una celda contiene comas o comillas se escribe entre comillas dobles (comillas internas duplicadas). No usar `\n` dentro de una celda (las celdas con saltos ya se excluyen).

### 4) `project.godot` — registro (staging selectivo)

1. `git archive HEAD project.godot | tar -x -C C:\Users\sonsc\AppData\Local\Temp\opencode\t2\project.godot`
2. Añadir al final del fichero temporal:
   ```
   [internationalization]
   locale/translations=PackedStringArray("res://locale/gestor_es_en.csv")
   ```
3. `git diff --no-index project.godot <temp>` y comprobar que el único cambio añadido es el bloque de internacionalización (sobre la versión de HEAD; los cambios ajenos en working tree no deben aparecer).
4. `git hash-object -w <temp>` → `BLOB`; `git update-index --cacheinfo "100644,$BLOB,project.godot"`; verificar de nuevo `git diff` para confirmar que solo ha quedado lo nuestro sobre HEAD.

### 5) `test_locale.gd` — Grupo A y B (literal, sin comentarios; patrón `_check`/`_fallos` del repo)

```gdscript
extends SceneTree

const RUTA_CSV := "res://locale/gestor_es_en.csv"
const Extraer := preload("res://scripts/extraer_cadenas.gd")

var _fallos := 0


func _initialize() -> void:
	var filas := _leer_csv(RUTA_CSV)
	if filas.is_empty():
		_check(false, "el CSV existe y se puede leer")
		_cerrar()
		return
	_a_cabecera(filas)
	_a_integridad(filas)
	_b_cobertura(filas)
	_cerrar()


func _a_cabecera(filas: Array) -> void:
	var cab: Array = filas[0]
	_check(cab.size() >= 3 and cab[0] == "keys" and cab[1] == "es" and cab[2] == "en", \
		"la cabecera del CSV es keys,es,en")


func _a_integridad(filas: Array) -> void:
	var repetidas := {}
	var celdas_vacias := 0
	for i in range(1, filas.size()):
		var f: Array = filas[i]
		if f.size() < 3 or f[0].is_empty() or f[1].is_empty() or f[2].is_empty():
			celdas_vacias += 1
		if repetidas.has(f[0]):
			_check(false, "clave duplicada: %s" % f[0])
		repetidas[f[0]] = true
	_check(celdas_vacias == 0, "todas las filas tienen keys,es,en no vacías")
	_check(filas.size() > 1, "el CSV tiene filas de traducción")


func _b_cobertura(filas: Array) -> void:
	var claves := {}
	for i in range(1, filas.size()):
		claves[filas[i][0]] = true
	var ausentes := []
	for cadena in Extraer.ui_strings():
		if not claves.has(cadena):
			ausentes.append(cadena)
	if ausentes.is_empty():
		_check(true, "todas las cadenas de UI extraídas son claves del CSV")
	else:
		for a in ausentes:
			_check(false, "falta clave: %s" % a)


func _leer_csv(path: String) -> Array:
	var src := FileAccess.get_file_as_string(path)
	var filas: Array = []
	var campos: Array = []
	var buf := ""
	var entre := false
	var i := 0
	while i < src.length():
		var c: String = src[i]
		if entre:
			if c == '"':
				if i + 1 < src.length() and src[i + 1] == '"':
					buf += '"'
					i += 1
				else:
					entre = false
			else:
				buf += c
		elif c == '"':
			entre = true
		elif c == ",":
			campos.append(buf)
			buf = ""
		elif c == "\n":
			campos.append(buf)
			filas.append(campos)
			campos = []
			buf = ""
		else:
			buf += c
		i += 1
	if not buf.is_empty() or not campos.is_empty():
		campos.append(buf)
		filas.append(campos)
	return filas


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
```

> El parser soporta campos entre comillas con comas internas y comillas dobladas (`""`); las claves del CSV van siempre sin comillas salvo necesidad. El patrón `_check`/`_cerrar` es el estándar de los tests del repo.

## GREEN verificado

Correr `test_locale.gd` → `TESTS OK` con el CSV completo. Correr también `test_config_store.gd` (sigue OK).

## Commit

```
feat(locale): #30 CSV ES/EN, registro en project.godot y test de cobertura
```

Staging selectivo para `project.godot`; `git add project.godot scripts/extraer_cadenas.gd res://locale/gestor_es_en.csv tests/test_locale.gd`.

---

# Tarea 3 — Banderas de idioma en `generar_iconos.gd` + `test_iconos.gd` (TDD)

**Archivos:** `scripts/generar_iconos.gd`, `scripts/generar_iconos.gd` (script cuerpo), `tests/test_iconos.gd`, regeneración de `Assets/icon/*`.

## RED

En `tests/test_iconos.gd`: el caso actual espera 4 ficheros generados. Cambiarlo/usarlo de base para que el `total` pase a 6 y existan `flag_es.svg` y `flag_gb.svg` tras `generar()`.

## GREEN

Editar `scripts/generar_iconos.gd`:

- Añadir dos constantes SVG (tamaño 64×64, sin texto, solo bandera):
  ```gdscript
  const _SVG_FLAG_ES := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" fill="#f5b301"/>
  <rect y="6" width="64" height="14" fill="#c8102e"/>
  <rect y="44" width="64" height="14" fill="#c8102e"/>
  <rect x="28" y="10" width="8" height="44" fill="#c8102e"/>
  </svg>
  """
  const _SVG_FLAG_GB := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" fill="#012169"/>
  <path d="M32 0v64M0 32h64" stroke="#ffffff" stroke-width="14"/>
  <path d="M32 0v64M0 32h64" stroke="#c8102e" stroke-width="6"/>
  <path d="M-9 -9L32 32M73 -9L32 32M-9 73L32 32M73 73L32 32" stroke="#ffffff" stroke-width="10"/>
  <path d="M-9 -9L32 32M73 -9L32 32M-9 73L32 32M73 73L32 32" stroke="#c8102e" stroke-width="4"/>
  </svg>
  """
  ```
- En `generar(destino: String) -> Dictionary`: escribir además `flag_es.svg` y `flag_gb.svg` (bytes UTF-8 de las constantes, igual que `icon.svg`) y pasar `"total"` de `4` a `6`.

Regenerar iconos: `godot --headless --path . --script res://scripts/generar_iconos.gd --quit-after 500` (crea `Assets/icon/flag_es.svg`, `Assets/icon/flag_gb.svg` y sus `.import` — estos `.import` quedan como untracked, documentado).

## GREEN verificado

Correr `test_iconos.gd` → `TESTS OK`. Comprobar que `Assets/icon/flag_es.svg` y `flag_gb.svg` existen y que `load("res://Assets/icon/flag_es.svg")` no da error en headless.

## Commit

```
feat(iconos): #30 banderas de idioma generadas con el resto de iconos
```

`git add scripts/generar_iconos.gd tests/test_iconos.gd Assets/icon/flag_es.svg Assets/icon/flag_gb.svg` (+ sus `.import` untracked si fueron creados; no tocar los ajeno).

---

# Tarea 4 — Preferencias: selector de idioma + señal con `idioma` (TDD)

**Archivos:** `scenes/Preferencias.tscn`, `scripts/preferencias.gd`, `tests/test_preferencias.gd`.

## RED

En `tests/test_preferencias.gd`:

1. Ampliar el caso de la señal `aplicado` para recibir 6 argumentos (el 6º = `idioma`).
2. Inyectar una configuración previa con `idioma = "en"` y comprobar que `%Idioma` queda seleccionado en el índice 1 ("English").
3. Simular guardado en inglés y verificar que la señal emite `idioma == "en"`.

## GREEN

### `scripts/preferencias.gd` (ediciones exactas sobre el fichero actual, 47 líneas)

- Señal: `signal aplicado(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int, tema: String, idioma: String)` (6.º arg).
- Nuevo `@onready`: `var idioma_opcion: OptionButton = %Idioma`.
- Nuevo `const IDIOMAS := [["es", "Español"], ["en", "English"]]`.
- En `_ready()`, antes de conectar los botones: poblar `%Idioma` recorriendo `IDIOMAS` con índice:
  ```gdscript
  for i in IDIOMAS.size():
  	var icono: Texture2D = null
  	if FileAccess.file_exists("res://Assets/icon/flag_%s.svg" % IDIOMAS[i][0]):
  		icono = load("res://Assets/icon/flag_%s.svg" % IDIOMAS[i][0])
  	idioma_opcion.add_icon_item(icono, IDIOMAS[i][1], i)
  ```
- Firma de `abrir()`: añadir `idioma := "es"` y la línea `_seleccionar_idioma(idioma)` tras `_seleccionar_tema(tema)`.
- Nuevo método:
  ```gdscript
  func _seleccionar_idioma(idioma: String) -> void:
  	for i in IDIOMAS.size():
  		if IDIOMAS[i][0] == idioma:
  			idioma_opcion.select(i)
  			return
  	idioma_opcion.select(0)
  ```
- En `_on_guardar()`: añadir a `aplicado.emit(...)` el arg `IDIOMAS[idioma_opcion.get_selected_id()][0]` (idioma de configuración `"es"`/`"en"`). El botón Guardar no escribe config (lo hace main vía la señal, patrón actual).

> `abrir()` no lee `ConfigStoreScript`: es main quien pasa los valores (incluido `idioma`) al abrir Preferencias. El call en `main.gd` se actualiza en la Tarea 5.

### `scenes/Preferencias.tscn`

Insertar, entre el bloque del Tema (`EtiquetaTema` + `Tema`, líneas 89-100) y el nodo `Error`, el bloque literal (mismo patrón que `EtiquetaTema`/`Tema`):

```
[node name="EtiquetaIdioma" type="Label" parent="Margen/Columna"]
layout_mode = 2
text = "Idioma"

[node name="Idioma" type="OptionButton" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
```

(`text = "Idioma"` es una clave CSV nueva: añadir la fila `"Idioma","Idioma","Language"` a `gestor_es_en.csv` en esta tarea para que el test de cobertura de `test_locale.gd` siga en verde. La ventana ajusta su alto con `wrap_controls = true`, igual que hoy.)

### `tests/test_preferencias.gd`

Ajustar a la nueva firma de 6 argumentos y añadir cobertura de idioma:

1. Lambda del callback: `func(p: int, t: float, a: bool, i: int, tm: String, id: String)` (guardar también `id` en `_aplicado`).
2. Tras `ventana.abrir(5, 20.0, false, 15, "oscuro")`: `_check(ventana.get_node("%Idioma").get_selected_id() == 0, "abrir precarga el idioma es")`.
3. Nueva precarga en inglés: `ventana.abrir(5, 20.0, true, 30, "claro", "en")` → `_check(ventana.get_node("%Idioma").get_selected_id() == 1, "abrir precarga el idioma en")`.
4. En el caso de guardar: `_check(_aplicado != null and _aplicado[5] == "en", "guardar emite el idioma elegido")` (al haber abierto en `"en"` y no tocar el selector).

## GREEN verificado

Correr `test_preferencias.gd` → `TESTS OK`.

## Commit

```
feat(ui): #30 selector de idioma con banderas en Preferencias
```

`git add scenes/Preferencias.tscn scripts/preferencias.gd tests/test_preferencias.gd res://locale/gestor_es_en.csv` (si se añadió la clave "Idioma").

---

# Tarea 5 — `main.gd`: aplicar idioma + traducción runtime + `idioma.gd` (TDD)

**Archivos:** `scripts/idioma.gd` (nuevo), `scripts/main.gd`, `scripts/historial.gd`, `tests/test_main_barra.gd`, `tests/test_locale.gd` (Grupo C y D).

## RED

- `tests/test_locale.gd` Grupo C — funciones puras del idioma:
  1. `IdiomaScript.aplicar("", "en_US") == "en"` (autodetectado)
  2. `IdiomaScript.aplicar("", "es_ES") == "es"`
  3. `IdiomaScript.aplicar("", "fr_FR") == "es"` (fallback)
  4. `IdiomaScript.aplicar("en", "es_ES") == "en"` (config manda)
  5. `IdiomaScript.aplicar("es", "en_US") == "es"`
- Grupo D — enrollado de templates: escanear `SCRIPTS_UI` con `r'\.(?:text|dialog_text|ok_button_text)\s*=\s*"([^"]*%[^"]*)"'`; para cada coincidencia, el texto de la línea (incluidos prepuestos/binarios) debe contener `tr(`. Fallo si no.
- En `tests/test_main_barra.gd`: en una nueva config base con `idioma="en"`, tras `_arrancar` el `TranslationServer.get_locale()` es `"en"`; restaurar `"es"` al final del test (y en el bloque de limpieza del suite).

## GREEN

### 1) `scripts/idioma.gd` (nuevo, sin comentarios) — carga manual del CSV

Esta build no tiene loader de recursos CSV (ver "Desviaciones"). `idioma.gd` añade dos funciones estáticas puras (`aplicar`) y una de carga que sustituye al registro en `project.godot`:

```gdscript
extends RefCounted

const IDIOMAS := ["es", "en"]

static func aplicar(guardado: String, locale_so: String) -> String:
	if guardado in IDIOMAS:
		return guardado
	var prefijo := locale_so.to_lower().substr(0, 2)
	return "en" if prefijo == "en" else "es"

static func cargar_traducciones() -> void:
	var filtros := _leer_csv("res://locale/gestor_es_en.csv")
	if filtros.is_empty():
		return
	for i in range(1, filtros.size()):
		if filtros[i].size() < 3 or filtros[i][1].is_empty():
			continue
		TranslationServer.add_translation(_traduccion(filtros[i]))
```

Con un parser quote-aware (`_leer_csv`) y un constructor `Translation` (`_traduccion`) que rellena `add_message(singular, messages[lang])` por fila, ambos idénticos en semántica al del test:

```gdscript
static func _traduccion(fila: Array) -> Translation:
	var t := Translation.new()
	t.locale = "es"
	t.add_message(fila[0], fila[1])
	if fila.size() >= 3 and not fila[2].is_empty():
		var en := Translation.new()
		en.locale = "en"
		en.add_message(fila[0], fila[2])
		TranslationServer.add_translation(en)
	return t
```

`main.gd` llama `IdiomaScript.cargar_traducciones()` en `_ready` (antes de `set_locale`); el test D/A la invoca igualmente. Las cadenas ES del CSV se registran con keys idénticas a las literales del código, luego `tr()` traduce a `en`.

### 2) `scripts/main.gd`

- `const IdiomaScript := preload("res://scripts/idioma.gd")` en la zona de preloads (al lado de `ConfigStoreScript`).
- En `_ready`, tras aplicar el tema y **antes** de construir la UI del filtro/menús: `TranslationServer.set_locale(IdiomaScript.aplicar(String(_config_store.cargar().get("idioma", "")), OS.get_locale()))`.
- `_on_aplicar_preferencias(paralelismo, timeout, auto, intervalo, tema, idioma)`: aplicar `TranslationServer.set_locale(idioma)` y llamar a `ConfigStoreScript.guardar(paralelismo, timeout, auto, intervalo, tema, idioma)` con **rollback** (patrón usado en #17 para el orden): capturar el locale actual antes de `set_locale`; si `guardar` devuelve `false`, restaurar el locale anterior y mostrar `progreso.text = tr("No se pudo guardar la configuración.")`.
- Al abrir Preferencias (línea 261): añadir el idioma al final de la llamada:
  ```gdscript
  preferencias.abrir(_paralelismo, _timeout, _auto_abrir, _intervalo_auto, String(_config_store.cargar().get("tema", "oscuro")), String(_config_store.cargar().get("idioma", "")))
  ```
  (El valor `""` lo resuelve `_seleccionar_idioma` a la opción 0 = español.)

### 3) Enrollado de runtime con `%` en `scripts/main.gd` y `scripts/historial.gd`

Regla mecánica: todo literal de `<propiedad de texto> = "<…%…>"` se convierte a `… = tr("<…%…>") …` manteniendo los argumentos fuera, p. ej.:

- `progreso.text = tr("%d omitidos (ya existían o sin URL válida).") % omitidos`
- `progreso.text = tr("%d importados, %d omitidos.") % [nuevas, reiteradas]`
- `progreso.text = tr("Catálogo exportado (%d enlaces).") % int(res.get("total", 0))`
- `progreso.text = tr("Informe %s guardado (%d enlaces).") % [formato.to_upper(), int(res.get("total", 0))]`
- `progreso.text = tr("No se pudo exportar el diagnóstico (%d errores).") % errores`
- `progreso.text = tr("Diagnóstico guardado en %s.") % ruta`
- `%ConfirmarLimpieza.dialog_text = tr("¿Borrar %d capturas huérfanas?") % borradas`
- `%ConfirmarReanudar.dialog_text = tr("¿Reanudar escaneo de %d enlaces?") % validas.size()`
- `%ConfirmarBorrado.dialog_text = tr("¿Eliminar «%s» para siempre?") % item.get_node("Margen/Fila/Textos/NombreLabel").text`
- `progreso.text = tr("URL copiada: %s") % url`
- `progreso.text = tr("Enlace agregado: %s") % nombre`
- `progreso.text = tr("Ya existe: %s") % nombre`
- `progreso.text = tr("Enlace actualizado: %s") % nombre`
- `progreso.text = tr("Re-comprobando %s.") % url`
- `progreso.text = tr("Comprobando %d/%d.") % [i, total]`
- `progreso.text = tr("Nada que comprobar")` (no tiene `%`; opción de consistencia, se puede dejar sin `tr`)
- `progreso.text = tr("Listo: %d caídos de %d") % [rotos, validos]`
- `rotos_label.text = tr("Rotos: %d") % c.get("rotos", 0)` (igual `activos_label`, `total_label`)
- `progreso.text = tr("Hay una nueva versión: %s") % version` (igual bloque "al día")
- `fila.text = tr("%s - %s - %s") % [nombre, fecha, estado]` (en `historial.gd`)
- Textos de estado en `main.gd` (`var estado_texto := tr("Sin comprobar")`, `tr("Válido")`/`tr("Caído")`) y en `historial.gd` el ternario `"Válido"/"Caído"` envuelto en `tr()`.
- Cabeceras de columna en `_pintar_cabeceras`: `boton.text = tr(titulos[col])` combinado con la flecha del orden (`("%s %s" % [tr(titulos[col]), flecha])`).

El Grupo D del test garantiza que no quede ningún template con `%` sin `tr()`: el fallo del grupo lista cada línea pendiente, se aplica la regla y se vuelve a correr.

### 4) `scripts/main.gd` — no tocar

No se modifica la lógica de filtros, ordenación, escaneo ni persistencia.

## GREEN verificado

Correr `test_locale.gd` (Grupos A–D), `test_main_barra.gd`, `test_preferencias.gd`, `test_config_store.gd`, `test_iconos.gd` → todos `TESTS OK`. La batería completa se corre en la Tarea 6.

## Commit

```
feat(i18n): #30 idioma aplicado en main y cadenas runtime traducidas
```

`git add scripts/idioma.gd scripts/main.gd scripts/historial.gd tests/test_locale.gd tests/test_main_barra.gd res://locale/gestor_es_en.csv`

---

# Tarea 6 — Verificación final + README + CHANGELOG + cierre (sin TDD, verificación)

**Archivos:** `README.md`, `CHANGELOG.md` (nuevo), plan (`docs/superpowers/plans/2026-09-23-internacionalizacion.md`, marcar checkboxes `[x]`), spec (si se añade algún matiz, anotarlo igual que se hizo en #17 bajo "Correcciones durante la ejecución").

## Pasos

1. **Batería completa**: recorrer `tests/test_*.gd` con el runner de batería (21 + `test_locale` = **22 suites**). Todas `TESTS OK`.
2. **Boot headless**: `godot --headless --path "K:\gestor-de-enlaces" --quit-after 500` → `exit=0`, sin `SCRIPT ERROR`.
3. **Cobertura final en inglés**: ejecutar el boot con la config temporal que fija `idioma="en"` (dos arranques: `es` y `en`) y verificar headless que no hay errores; el chequeo visual queda para el usuario (`godot --path .`) opcional.
4. **README.md**:
   - Cambiar **todas** las ocurrencias de "17 suites" por "22 suites".
   - Añadir en Features/funciónes: ordenación por columnas (issue #17, persistida) e internacionalización ES/EN con selector de idioma y banderas (issue #30).
   - Estructura: incluir `locale/gestor_es_en.csv`, `CHANGELOG.md` y `scripts/extraer_cadenas.gd` (scanner de cadenas de UI).
   - Roadmap: marcar #17 y #30 como hechos.
5. **CHANGELOG.md** (nuevo, formato Keep a Changelog):
   - `# Changelog`
   - Sección `## [Sin publicar]` con las entradas de #30 (internacionalización, banderas, selector, tr runtime, test_locale) y #17 (ordenación por columnas persistida).
   - Sección `## [0.x.y] – 2026-09-23`? No: agrupar **por día** según el histórico real (11 días con commits):
     - `## 2026-09-05` … `09-23`, cada una listando los commits de ese día leídos de
       `git log --date=short --pretty=format:"%ad|%s" |` agrupados. Volumen por día: 09-05:19, 09-06:24, 09-07:1, 09-12:15, 09-13:20, 09-14:30, 09-15:8, 09-18:10, 09-19:22, 09-20:7, 09-23:12 (total 168).
     - Las entradas se describen en español, por grupos de trabajo del día (número de commits sin detallar cada uno).
   - El fichero respeta la estructura de heading única y no escribe en los ficheros ajenos.
6. **Chequeo de trabajo**: `git status` para confirmar que solo quedan los ajenos y los untracked documentados (nada propio sin commitear salvo previsible `Assets/icon/*.import` de banderas).
7. **Plan**: marcar todos los checkboxes de este documento como `[x]` (editar vía replaceAll) y commit.
8. **Cerrar issue #30**:
   ```bash
   gh issue close 30 --repo scorpio21/gestor-de-enlaces --comment "Resumen del trabajo + lista de commits"
   ```

## Commit

Fases de commit separadas:
- `docs(README): #30 actualizar features, estructura y numero de suites`
- `docs(changelog): historico por dias (168 commits)`
- `docs(plan): #30 internacionalizacion completado (checkboxes)`

---

## Desviaciones durante la ejecución

- **`project.godot` NO registra traducciones (Tarea 2 completada).** Esta build del motor (`Godot_v4.7.2-stable_win64_console`) no trae registrado ningún `ResourceFormatLoader` para `.csv`: `load("res://locale/gestor_es_en.csv")` devuelve `No loader found for resource`, y el arranque intentaría cargar `locale/translations` desde `project.godot` con el mismo error en cada ejecución. Se omite el registro en `project.godot` (paso 4 de la Tarea 2) y, en su lugar, **`idioma.gd` (Tarea 5) carga el CSV a mano**: parsear el fichero (parser quote-aware idéntico al del test) y registrar un `Translation` por idioma con `TranslationServer.add_translation()` antes de `set_locale`. Esto hace `tr()` funcional sin depender del loader. El paso 4 de la Tarea 2 queda anulado por esta nota.
- **Scanner (Tarea 2):** `PATRON_MENU` usaba `[^"]*` que cruzaba líneas (falsos positivos `nombre`, `individual`): se fija a `[^"\n]*`. `PATRON_ESCENA` ganó `/` opcional para capturar `popup/item_N/text` (items de `OptionButton`). Se añaden skips: `txt == "v"` (etiqueta de versión) y `txt == "Open a File"` (FileDialog del SO).
- **CSV (Tarea 2):** el test de cobertura usa las claves reales del scanner; las del plan (tercer caso, p. ej. `Comprobando %d/%d.` con punto) son aproximadas — las claves reales usan «…». Se autoraron las 130 claves reales; la fila `%d importados, %d omitidos.` lleva sus 3 celdas entre comillas (contiene comas).
- **Named arguments en llamadas (Tarea 5):** GDScript no acepta `guardar(..., idioma = "es")` ni en la llamada encadenada del test ni en `main.gd` (`Parse Error: Assignment is not allowed inside an expression`). Se usa el 9º argumento posicional de `guardar()`: `(paralelismo, timeout, auto_abrir, intervalo, tema, ultima_version_vista, orden_columna, orden_direccion, idioma)`.

## Correcciones / contingencias conocidas

- **Auto-traducción**: si tras la Tarea 5 una cadena simple no deja de mostrarse en ES en pantalla (detectable en el arranque visual opcional), el fix es envolverla en `tr(...)` igual que los templates; el Grupo D + cobertura no lo detecta por estar ES en el CSV, así que el arranque manual final juzga.
- **`%Idioma` y `FileDialog`**: el título "Open a File" del SO no se traduce (fuera de alcance por spec).
- **SVG GB**: si el resultado del path es feo, se puede simplificar a la Cruz de San Jorge sobre azul (sin cruces diagonales) en la Tarea 3; el test solo comprueba existencia.
- **`project.godot` ajeno**: toda edición vía staging selectivo; si el editor reescribe el fichero, re-comitar solo el bloque `[internationalization]` sin tocar lo ajeno.

---

## Checkboxes del plan

- [x] Tarea 1 — config_store guarda y valida idioma
- [x] Tarea 2 — scanner, CSV ES/EN, registro en project.godot, test_locale
- [x] Tarea 3 — banderas SVG de idioma + test_iconos
- [x] Tarea 4 — selector de idioma en Preferencias + señal
- [x] Tarea 5 — idioma aplicado en main + tr() runtime
- [x] Tarea 6 — batería 22, boot, README, CHANGELOG, cierre #30