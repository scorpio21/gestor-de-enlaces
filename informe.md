# Informe de revisión técnica — GestorAO

> Revisión del repositorio `K:\gestor-de-enlaces` (Godot 4.7.2, GDScript).
> Fecha: 2026-10-07 · Versión revisada: `0.3.0` (`config/version`), HEAD `2dd92c4`.
> Método: lectura directa del código fuente, de la documentación y de los artefactos de
> configuración/CI. El grafo de `codebase-memory` se usó como apoyo y se contrastó con el
> código cuando aportaba algo; en GDScript de UI deja `parse_partial` y no es la fuente
> principal.

---

## 1. Resumen ejecutivo

GestorAO es una **aplicación de escritorio** para Argentum Online que cataloga y verifica la
disponibilidad de enlaces de descarga (servidores, clientes, código fuente). No es un juego:
es una herramienta de escritorio construida sobre Godot, y usa el motor como *framework* de
UI (`Control`), red (`HTTPClient`), persistencia (`FileAccess`/`JSON`/SQLite), TLS, ZIP y
traducción. Esa decisión es deliberada y está bien explotada.

El nivel de ingeniería está **muy por encima de la media** de un proyecto Godot personal:

- **Arquitectura por capas** clara: vistas (nodos), controladores y stores sin dependencia de
  escena, y módulos puros de dominio. La lógica testeable se sacó progresivamente de `main.gd`
  (issues #57–#63).
- **Tres backends de almacenamiento intercambiables** (ficheros sueltos, fichero único,
  SQLite) tras una interfaz común `almacen.gd`, con migración verificada por recuento y
  escritura atómica.
- **Verificación HTTP** seria: reintentos de fallos transitorios, tope por host, detección de
  marcadores de "archivo borrado", soporte de certificados TLS no válidos como *opt-in* y
  propagación de la URL final tras redirección.
- **Verificación automatizada excepcional** para un proyecto de este tamaño: 60 suites headless,
  comprobación estática con `--check-only`, *smoke test* del binario exportado y una suite
  (`test_empaquetado`) que actúa como **guarda de arquitectura** (impide que la lógica vuelva
  a `main.gd` y que se degraden CI/empaquetado). Hay además rastro de *mutation testing* en la
  documentación.
- **CI multiplataforma** (Ubuntu + Windows) con caché de importación, y un job de exportación
  que arranca el binario real para cazar fallos que solo existen dentro del `.pck`.

Los puntos flojos son de **forma y deuda acumulada**, no de corrección: `main.gd` sigue siendo
un monolito de ~1.700 líneas con un techo vigilado por test, la documentación tiene cifras
desactualizadas, hay convenciones mixtas (`class_name` vs. `preload`), falta un `LICENSE` en la
raíz pese a redistribuir addons MIT, y el árbol de trabajo estaba sucio con `.uid` sin
versionar. Nada de esto es un error funcional; son tareas de orden.

**Veredicto:** proyecto apto para uso y publicación, con ingeniería notable y deuda técnica
menor y acotada. Las recomendaciones de la §15 son de bajo riesgo y alto retorno de
mantenimiento.

---

## 2. Ficha técnica

| Campo | Valor |
|---|---|
| Motor | Godot **4.7.2** (`config/features=["4.7","Forward Plus"]`) |
| Lenguaje | GDScript (100 % del código propio) |
| Versión | `0.3.0` (`config/version`, `display/window/title="GestorAO v0.3.0"`) |
| Escena principal | `res://scenes/Main.tscn` |
| Ventana | 1440 × 810, `stretch/mode="canvas_items"`, `aspect="expand"` |
| Render Windows | `rendering_device/driver.windows="d3d12"` |
| Autoload | `_mcp_game_helper` (solo editor; el addon lo retira en los exports) |
| Addons | `godot_ai` v4.x (editor, MIT) · `godot-sqlite` 4.9 (MIT, SQLite 3.51, 19,3 MB de binarios) |
| Tamaño del código propio | **54 scripts / 9.847 líneas** · **60 suites + 2 helpers / 12.509 líneas** |
| Escenas | 10 (`Main`, `AgregarEnlace`, `Preferencias`, `Historial`, `Cambios`, `Dashboard`, `ListItem`, `GridItem`, `FilaTabla`, `TarjetaKpi`) |
| Catálogo base | `data/data.json` con **57 entradas** |
| Traducciones | `locale/gestor_es_en.csv` (308 líneas) |
| Presets de export | Windows / Linux-X11 / macOS (universal) |

---

## 3. Arquitectura

### 3.1 Capas

El proyecto sigue un patrón consistente de **vista → controlador → store/dominio**:

```
scenes/*.tscn  +  scripts/<vista>.gd        Nodes/Windows/Controls: solo pintan y cablean
        │
scripts/*_controller.gd                      Lógica de caso de uso (RefCounted, sin UI)
scripts/*_store.gd                           Persistencia (RefCounted, delegan en el backend)
scripts/almacen*.gd                          Backends de almacenamiento tras una interfaz
scripts/<dominio>.gd                         Módulos puros (static func, sin estado)
```

Los módulos de dominio son **funciones puras y sin dependencias de escena**, lo que los hace
trivialmente testeables en headless: `gestor_catalogo.gd` (clave canónica/dominio/URL),
`etiquetas.gd`, `filtros.gd`, `ordenador.gd`, `versiones.gd`, `redirecciones.gd`,
`gestor_contadores.gd`, `gestor_datos.gd`, `tema_sistema.gd`.

### 3.2 Flujo de arranque (`scripts/main.gd`)

`_ready()` orquesta el arranque en un orden que la propia suite `test_empaquetado` vigila:

1. `_abrir_almacen()` — **antes que los stores**, porque decide de dónde salen los datos.
   `AlmacenController.new(OS.get_cmdline_user_args())` resuelve modo y base
   (`--almacen=`, `GESTORAO_ALMACEN`, `GESTORAO_BASE`, o `user://almacenamiento.json`) y
   `aplicar_a(self)` reescribe en el nodo `DATA_RES`/`DATA_USER`/`CONFIG_BASE`/`ASSETS_BASE`.
2. Se crean los stores (`config`, `estado`, `instantanea`, `presets`, `cola`, cambios)
   conectados al backend vía `AlmacenController.para_stores()`.
3. `_cargar_datos()` mezcla `data/data.json` (base) con `enlaces.json` (usuario), deduplicando
   por `GestorCatalogo.clave_unica`.
4. `_configurar_menus()`, aplicación de tema/idioma, y `SmokeScript.arrancar_desde_consola()`
   (que sale con 0/1 en modo `--smoke`).
5. Después, señales y handlers de UI.

Este orden es exactamente el que rompió #65: `cola_store.cargar()` pedía `almacen.seccion("cola")`
y el backend SQLite no lo implementaba, así que `_ready()` moría con
`Nonexistent function 'seccion'`. La corrección añadió `seccion()` al backend y un `{}` por
defecto en la superficie, de modo que **un backend incompleto degrada en vacío en vez de
reventar**.

### 3.3 Inyección de dependencias ligera

No hay `class_name` como mecanismo general ni un contenedor DI. El patrón es:
`const XScript := preload(...)` + parámetros de constructor con valor por defecto. Los
controladores reciben el store **como argumento y no lo cachean** (decisión documentada en
`MEMORIA.md`: cachearlo desincronizaba el test de reversión). `main.gd` mantiene el array
`_entradas` y lo pasa a los controladores, porque las suites de integración lo reasignan
directamente.

### 3.4 Convención `preload` vs. `class_name`

La convención del repo (`AGENTS.md`) es **preload-const en vez de `class_name`**. El código la
respeta en general, pero quedan 5 excepciones de rondas antiguas:
`CacheTexturas`, `ColaStore`, `EstadoStore`, `InformeStore`, `TemaStore`. Es una inconsistencia
menor, no un problema.

---

## 4. Inventario de módulos

Los 54 scripts, ordenados por tamaño (líneas reales, sin excluir líneas en blanco):

| Área | Ficheros |
|---|---|
| Integración | `main.gd` (1.707), `smoke.gd` (170) |
| Almacenamiento | `almacen_bd.gd` (454), `almacen.gd` (334), `almacen_uno.gd` (308), `almacen_json.gd` (225), `almacen_controller.gd` (203), `almacen_config.gd` (154) |
| Verificación | `link_checker.gd` (472), `cola_escaneo.gd` (77), `actualizador.gd` (155) |
| Stores | `dashboard_store.gd` (354), `config_store.gd` (235), `cambios_store.gd` (178), `instantanea_store.gd` (177), `estado_store.gd` (160), `presets_store.gd` (152), `informe_store.gd` (147), `cola_store.gd` (95) |
| Controladores | `catalogo_controller.gd` (221), `seleccion_controller.gd` (199), `scan_controller.gd` (154), `lista_controller.gd` (124), `cambios_controller.gd` (96), `informe_controller.gd` (50), `config_controller.gd` (43) |
| Dominio puro | `redirecciones.gd` (181), `gestor_catalogo.gd` (106), `gestor_datos.gd` (86), `etiquetas.gd` (66), `filtros.gd` (57), `versiones.gd` (46), `ordenador.gd` (44), `gestor_contadores.gd` (19) |
| Vistas | `list_item.gd` (414), `dashboard_ui.gd` (320), `tema_store.gd` (249), `agregar_enlace.gd` (234), `preferencias.gd` (223), `grafico_dashboard.gd` (177), `cambios.gd` (146), `fila_tabla.gd` (60), `historial.gd` (46), `tarjeta_kpi.gd` (17) |
| Infra/aux | `gestor_imagenes.gd` (146), `generar_iconos.gd` (130), `diagnostico.gd` (67), `idioma.gd` (66), `logger.gd` (63), `gestor_archivo.gd` (62), `rutas.gd` (55), `extraer_cadenas.gd` (52), `cache_texturas.gd` (51), `tema_sistema.gd` (20) |

---

## 5. Almacenamiento

Es la pieza más elaborada del proyecto y la que más rondas de revisión acumula (#63 fases 1 y 2,
#65). La superficie común es `scripts/almacen.gd`:

- `MODO_FICHEROS` (`ficheros`), `MODO_UNICO` (`unico`), `MODO_BASE_DATOS` (`base_datos`).
- `SECCIONES = [entradas, estados, borrados, cola, config, capturas, instantaneas]`.
- `ESQUEMA_ACTUAL = 1`, `escribir_json()` atómica (`.tmp` → `.bak` → `rename`), `ruta_de()`,
  `con_barra()`, `ruta_ok()`.

`almacen_controller.gd` es la **fábrica**: conoce los tres backends (que `almacen.gd` no puede
preloadear por dependencia circular — hay un test que lo impide), resuelve el modo desde
argumentos/env/config, migra entre modos/carpetas y expone `aplicar_a(nodo)` y `para_stores()`.

| Backend | Fichero | Formato | Notas |
|---|---|---|---|
| Ficheros sueltos | `almacen_json.gd` | 8 JSON en `base` | Modo por defecto; **byte a byte idéntico** al de los stores antiguos |
| Fichero único | `almacen_uno.gd` | `gestorao.json` (8 secciones) | `schema_version` por sección; guardián `_futuro` que rechaza escritura |
| Base de datos | `almacen_bd.gd` | `gestorao.db` (SQLite) | Addon `godot-sqlite` vendorizado; una tabla por sección, payload JSON |

Decisiones de diseño sólidas y bien justificadas en `CHANGELOG.md`/`MEMORIA.md`:

- **La base no reinterpreta los datos**: cada fila guarda la carga útil en JSON, así que la
  ida y vuelta es exacta entre los tres modos. Los números vuelven como `float` por el redondeo
  de `JSON.parse_string` (documentado; los stores normalizan con `int()`).
- **Escritura atómica compartida**: `config_store` y `cola_store` abrían el destino en `WRITE`
  (un corte a mitad dejaba el fichero en cero, y en `config.json` eso son *todos* los ajustes).
  Ahora los cuatro stores delegan en `AlmacenScript.escribir_json()`, con guarda en
  `test_empaquetado` para que no vuelvan a hacerlo.
- **Migración verificada por recuento**: `migra_a()` solo lee el origen; un fallo a medias deja
  los originales intactos y la migración se marca fallida indicando qué sección no cuadra.
- **El fichero de preferencia vive siempre en `user://`**, aunque los datos se muden, para no
  dejar los datos huérfanos. El cambio de carpeta **no** se aplica en caliente (los stores ya
  tienen rutas abiertas): se copia, se verifica y se pide reinicio.
- **`guardar_estados_y_borrados()`** en una sola escritura / una transacción (BEGIN/COMMIT con
  ROLLBACK en SQLite): borrar una entrada deja estado y marca juntos, sin estados intermedios.
- **Guardián de versión futura**: una base o fichero con `schema_version`/`esquema` mayor queda
  `bloqueado()` y **rechaza toda escritura** en vez de dejarse pisar.
- La base SQLite nace en `<carpeta>/gestorao.db`, derivada de `base`, no en un `user://` fijo:
  cambiar de carpeta mueve también el `.db`.

**Riesgo/observación:** el `.bak` en SQLite se toma con `backup_to` antes de *cada* escritura
(solo si ya había datos). Es coherente con el resto, pero implica una copia completa de la base
por escritura; con bases grandes podría notarse. Hoy el catálogo es de decenas de entradas, así
que es irrelevante.

---

## 6. Verificación de enlaces (`link_checker.gd`, 472 líneas)

Es el módulo más complejo y el más expuesto a fallos de terceros. Aspectos destacables:

- **Máquina de estados sobre `HTTPClient`** con `MAX_REDIRECTS = 6`, `timeout_s` configurable
  (3–60 s), `User-Agent`, y cobertura de los estados `DISCONNECTED`, `CONNECTION_ERROR`,
  `STATUS_BODY`, `STATUS_CONNECTED`/`STATUS_REQUESTING` (los dos últimos significan "cuerpo
  terminado" si ya hay código). Este detalle se documentó tras medirlo: sin cubrirlos, la
  comprobación se quedaba colgada hasta el timeout.
- **Reintentos de fallos transitorios** (`es_transitorio()`: `red`, `dns`, y HTTP
  429/500/502/503/504) con esperas crecientes `[1 s, 4 s]` desde el mismo comprobador (no abre
  comprobadores extra ni salta el tope por host). Respeta `Retry-After` (segundos o fecha HTTP),
  **capado a 10 s** para que un 429 de 600 s no cuelgue el escaneo. Los fallos definitivos
  (404/410, marcadores de archivo muerto, TLS inválido, URL inválida) no se reintentan.
- **Fallos de entorno → "sin comprobar"** (`valido = null`) en vez de "caído", para no ofrecer
  "Eliminar" por un corte de red ajeno. Motivo persistido: `ok|red|dns|tls|http|muerto|url`.
- **Detección de "archivo borrado"**: lee hasta `LIMITE_CUERPO = 65536` bytes del cuerpo y busca
  `MARCAS_MUERTO` (y marcas por host). Es heurística por naturaleza; está acotada y documentada.
- **Certificados TLS no válidos** (`#56`): dos pasos. Primero validación normal; solo si el
  handshake falla **de verdad**, repite con `TLSOptions.client_unsafe(null)`. Si responde, el
  enlace queda `ok_tls` ("válido con aviso", color `aviso`); si no, "sin conexión segura".
  Desactivado por defecto, con advertencia de seguridad en README.
- **URL final** (`url_final`): se propaga en la señal `terminado(valido, mensaje, codigo, url_final)`,
  se persiste en `estado_store` y alimenta el módulo `redirecciones.gd`.

`actualizador.gd` consulta `releases/latest` de GitHub para avisar de versiones nuevas
(comparador de versiones en `versiones.gd`). Es una llamada de red sin verificación de firma;
para una app de este tipo es aceptable.

---

## 7. Stores y controladores

**Stores** (persistencia): `estado_store` (historial de 50 por URL, volcado cada 25),
`config_store` (20 campos con validación de rangos), `cola_store` (cola de escaneo reanudable),
`instantanea_store` (una foto diaria del catálogo, retención 30–3650, por defecto 365),
`presets_store` (hasta 20 presets de filtros), `cambios_store` (delta entre escaneos),
`informe_store` (CSV/HTML y textos de causa), `dashboard_store` (resumen, categorías, hosts,
serie diaria, top caídos). Todos reciben el backend o usan `user://` según modo.

**Controladores** (casos de uso): `scan_controller` (máquina de estados del escaneo, sin UI,
con señales `progreso`/`item_actualizado`/`terminado`), `lista_controller` (filtros, orden y pool
de filas), `config_controller` (la **lista única de claves** de `ConfigStore.guardar()`, que el
test contrasta con `get_method_list()`), `catalogo_controller` (alta/edición/borrado,
normalización, dedupe, renombrado de clave de estado, capturas huérfanas),
`seleccion_controller` (álgebra de selección por URL + `atajo_de(event)` estático),
`informe_controller` (armado de filas CSV/HTML), `cambios_controller` (registro y pendientes).

El valor arquitectónico principal aquí es que **la lógica testeable no vive en `main.gd`** y hay
tests que lo verifican por introspección de código.

---

## 8. UI, escenas y tema

- 10 escenas; cada `Window` conecta `close_requested → hide` (lección aprendida: el dashboard se
  colgó la app por no hacerlo y sin botón de cierre).
- `tema_store.gd` (249 líneas) aplica paletas claro/oscuro/auto con `DisplayServer.is_dark_mode()`,
  y repinta por **meta** (`TemaStore.marcar(nodo, clave)` guarda la clave en el nodo), de modo que
  cambiar de tema no obliga a reconstruir la lista. El contraste mínimo está verificado en test.
- La lista recicla filas con un **pool** (`lista_controller`) y cada elemento (`list_item.gd`,
  414 líneas) tiene menú contextual, marca de cambio, marca de reubicado y estado por colores.
- El dashboard redibuja su gráfico en `_draw()` (`grafico_dashboard.gd`) con rejilla, tres series
  apiladas (válidos/caídos/sin comprobar), marcas de "sin datos" y globo de tooltip.
- `gestor_imagenes.gd` copia capturas a `Assets/png|jpg` con el nombre del enlace, las deduplica
  por contenido y evita borrar una captura que otra entrada aún referencia
  (`borrar_captura_si_huerfana`).

---

## 9. Internacionalización

- Selector ES/EN en Preferencias con banderas; `idioma.gd` aplica el idioma guardado o el del
  SO y **carga las traducciones en runtime parseando el CSV** `locale/gestor_es_en.csv` a mano
  (parser propio que respeta comillas).
- Todo texto pasa por `tr()` / `TranslationServer.translate()`.
- `extraer_cadenas.gd` es un **scanner de cadenas de UI** (regex sobre escenas y una lista
  explícita de scripts `SCRIPTS_UI`) y `test_locale.gd` falla si alguna cadena de UI no tiene
  clave en el CSV. Es una red de seguridad excelente, con la trampa documentada de que hay que
  **añadir los controladores nuevos a `SCRIPTS_UI`** o sus `tr()` dejan de comprobarse en
  silencio.

**Observación:** el repo contiene además `locale/gestor_es_en.en.translation` y
`locale/gestor_es_en.es.translation` (recursos `Translation` importados) que **ningún script
carga**; las traducciones se inyectan por código. Son artefactos generados por el importador a
partir del CSV; conviene confirmar que no inducen a confusión.

---

## 10. Pruebas y aseguramiento de calidad

Es, junto con el almacenamiento, la parte más destacable.

### 10.1 Batería headless (`tests/run_battery.sh` + 60 suites)

Cada suite es `tests/test_<área>.gd` que extiende `SceneTree`, imprime `TESTS OK` y hace
`quit(0)`. El runner:

- Da a **cada suite su propio `timeout`** (`TIMEOUT_SUITE`, 180 s) y distingue el código
  124/137 como `COLGADA`. El motivo está documentado: una suite con `Parse Error` no compila,
  no llega a `quit()` y **se cuelga para siempre**; sin timeout, eso no es un rojo, es el job
  entero quemando sus 6 h por defecto.
- Captura el estado con `|| estado=$?` (antes, bajo `set -e`, un `exit != 0` mataba el script
  sin imprimir qué suite falló).
- Resuelve la ruta con `cygpath -w` en Windows/Git Bash y soporta `PATRON=` para una sola suite.

### 10.2 Comprobación estática (`tests/run_estatico.sh`)

`godot --headless --check-only --script` sobre los 116 `.gd` de `scripts/` y `tests/`: un
segundo por fichero, sin cargar escenas, y **sí** devuelve código distinto de 0 ante un error de
parseo (a diferencia de `--import`, que emite ruido benigno y sale con 0). Es el filtro rápido
antes de la batería.

### 10.3 Smoke del binario exportado (`tests/run_smoke.sh` + `scripts/smoke.gd`)

Caza lo que **solo** existe dentro del `.pck`: recursos/escenas que no entran, scripts que no
compilan en release, `user://` no escribible. Comprueba escritura+relectura en `user://`, carga
de recursos con `ResourceLoader.load()` (no `FileAccess.file_exists()`, que **miente dentro de un
pck**), instanciación de las 10 escenas, respuesta de los stores y funcionamiento del backend de
almacenamiento. `run_smoke.sh` no se conforma con el código de salida: exige la marca
`GestorAO smoke OK` y que no aparezca ni un `SCRIPT ERROR`, porque Godot puede imprimir un error
y salir con 0. En Windows hay que usar el `.console.exe`.

### 10.4 `test_empaquetado.gd` — guardas de arquitectura

Es una idea poco común y muy valiosa: además de comprobar presets y CI, **falla si la
arquitectura se degrada**. Vigila, entre otras cosas, que:

- el escaneo, la lista/filtros, el guardado de config, el alta/edición/borrado, los cambios, la
  selección, el informe y el criterio de reubicación **no vuelvan a `main.gd`**;
- `main.gd` no crezca por encima de un techo (**1710** líneas, hoy 1707: solo 3 líneas de margen);
- el almacenamiento se abra **antes** de crear los stores;
- `almacen.gd` no preloadee sus backends (dependencia circular);
- la escritura atómica compartida siga usándose en `config_store` y `cola_store`;
- cada paso de CI que toca Godot lleve `shell: bash`, y cada `curl` de la acción lleve `-f`.

### 10.5 Mutation testing

`MEMORIA.md` documenta rondas de **mutación deliberada** (`mut63.py`, `mut63b/c/d.py`, etc.):
se revierte una decisión, se comprueba que la suite la caza, y se restaura. No es habitual en un
proyecto personal y explica por qué las suites están afinadas en "las dos direcciones".

### 10.6 Aislamiento de las suites

- Las suites que instancian `Main` apuntan `ASSETS_BASE`/`DATA_USER`/`CONFIG_BASE` a
  `user://__test_*__` y fijan `GESTORAO_ALMACEN=ficheros` para no heredar el modo de la máquina
  (bug real de #65: con la máquina en Base de datos, seis suites fallaban o se colgaban).
- `test_proyecto.gd` falla si alguien vuelve a escribir `res://Assets` a pelo o instancia `Main`
  sin aislar la base. Antes, la batería **borraba las capturas reales** del catálogo y aun así
  daba 33/33 verdes.
- `tests/servidor_http.gd` es un `TCPServer` de test reutilizable para el checker.

---

## 11. CI y empaquetado

`.github/workflows/ci.yml`:

- **`battery`**: matriz `ubuntu-latest` / `windows-latest`, `fail-fast: false`,
  `timeout-minutes: 30`, **todos los pasos con `shell: bash`** (Git Bash en Windows; con el
  shell por defecto, pwsh, un `.sh` no se ejecuta y el job pasaría sin correr nada).
- **`test-export`**: importa, exporta los 3 presets a `build/`, comprime el `.app` y **arranca
  el binario exportado** (`run_smoke.sh`); publica artefactos.
- Acción compuesta local `.github/actions/godot` para descargar motor y plantillas (con caché),
  con `curl -f` en todas las descargas (sin `-f`, un 404 sale con código 0 y guarda el "Not
  Found" dentro del `.zip`, y el error visible es de `unzip`, no de la URL).
- Caché de `.godot/imported` + `.godot/uid_cache.bin` con clave
  `hashFiles('project.godot','Assets/**','data/**')`, que es la parte lenta a reimportar.

`export_presets.cfg`: Windows (`embed_pck=true`, salida `..//gestor-de-enlaces.exe`),
Linux/X11 (`build/gestor-de-enlaces.x86_64`) y macOS universal.

---

## 12. Rendimiento

Decisiones relevantes, todas documentadas:

- **Tope de concurrencia por host** (`TOPE_POR_HOST = 2`) además del paralelismo global
  (por defecto 3, rango 1–8): evita ráfagas contra un mismo dominio.
- **Pool de filas** recicladas y **caché de texturas** LRU (`cache_texturas.gd`, límite 200,
  invalidada por firma mtime+size).
- **Reverse-lookup de mensajes de estado memoizado** (`#40`): antes se recorrían todas las claves
  del CSV por fila y por tooltip en cada reconstrucción de la lista.
- **Lectura de cuerpo acotada** a 64 KB en el checker; el desarrollo se midió con sockets locales
  para no confundir "bloquea" con "no hay datos aún".

No se observan bucles costosos ni reconstrucciones completas evitables en las rutas calientes.

---

## 13. Seguridad y robustez

- **TLS**: la aceptación de certificados inválidos es *opt-in*, desactivada por defecto, en dos
  pasos, y con advertencia explícita de riesgo en el README. Correcto.
- **CSV/HTML**: verificado. `informe_store.gd` pasa todo campo por `_escape_csv()` y
  `_escape_html()` antes de escribirlo, así que nombres/descripciones/URLs con `;`, `"`, `<`, `&`
  no rompen el informe.
- **Rutas**: `rutas.es_escribible()` prueba escritura antes de escribir en `res://`; en export
  el catálogo base no se toca.
- **Red**: `actualizador.gd` sigue redirecciones de GitHub sin verificar firma; aceptable para
  un aviso de versión, no para auto-instalar.
- **Datos del usuario**: `user://` real no se toca desde las suites (hay comparación antes/después
  en `test_preferencias`).

---

## 14. Deuda técnica y hallazgos

Ordenados por impacto. Ninguno es un fallo funcional.

1. **`main.gd` sigue siendo un monolito (1.707 líneas).** La meta del issue #62 (~500 líneas) no
   se cumplió y se reconoce en `MEMORIA.md`: lo que queda son manejadores de diálogo cableados.
   El problema práctico es que el techo de `test_empaquetado` es **1710**, así que solo hay **3
   líneas** de margen: cualquier cableado nuevo hará fallar el test y forzará una decisión
   consciente. Es un techo *deliberado*, pero el margen es frágil.
2. **Documentación con cifras desactualizadas.**
   - `README.md` sigue diciendo "33 suites" y lista solo 3 escenas/estructura antigua.
   - `MEMORIA.md` dice "Batería completa (34 suites)".
   - `README.md` no menciona los tres modos de almacenamiento (solo describe `user://*.json`).
   El `CHANGELOG.md` sí está al día (60/60, 116/116).
3. **Falta `LICENSE` en la raíz.** El README dice "uso libre", pero se redistribuyen addons MIT
   (`godot_ai`, `godot-sqlite`) e iconos generados. Conviene un `LICENSE` propio y un `NOTICE`
   con las licencias de terceros.
4. **Convención mixta:** 5 ficheros usan `class_name` (`CacheTexturas`, `ColaStore`,
   `EstadoStore`, `InformeStore`, `TemaStore`) contra la convención `preload-const` de
   `AGENTS.md`.
5. **`export_presets.cfg` de macOS con versión obsoleta:**
   `application/bundle_version="0.1.0"` y `bundle_short_version="0.1.0"` frente a
   `config/version="0.3.0"`. Conviene regenerar el preset desde el editor o corregirlo.
6. **Árbol de trabajo sucio con `.uid` sin versionar.** 46 ficheros `.uid` (Godot 4.4+) sin
   trackear al terminar la sesión. El repo ya versiona algunos `.uid`; hay que decidir una regla
   (versionarlos todos, o ignorarlos) y aplicarla.
7. **Duplicados/residuos menores:** `icon.svg` + `icon.svg.import` en la raíz (el icono real es
   `res://Assets/icon/icon.svg`); `data/servidores.json` es un `[]` de 3 bytes sin uso aparente;
   `locale/*.translation` que ningún script carga.
8. **`physics/3d/physics_engine="Jolt Physics"`** en `project.godot`: irrelevante para una app
   de UI (inofensivo).
9. **Mutation testing no reproducible:** los scripts `mut63*.py` no están en el repo (vivían en
   `%TEMP%`), así que el proceso no se puede repetir tal cual.
10. **Nota de método para futuras auditorías:** `Get-Content | Measure-Object -Line` en PowerShell
    **omite las líneas en blanco**, así que subestima el tamaño; para contar líneas reales usar
    `[IO.File]::ReadAllText` o `git show`. Es una nota de método, no del código.

---

## 15. Recomendaciones priorizadas

**Alta prioridad (rápidas y de alto valor):**

1. **Sincronizar la documentación**: actualizar el recuento de suites y la estructura en
   `README.md`, y la cifra de suites en `MEMORIA.md`; documentar en el README los tres modos de
   almacenamiento.
2. **Añadir `LICENSE` + `NOTICE`** con las licencias de `godot_ai` y `godot-sqlite`.
3. **Corregir la versión del bundle macOS** en `export_presets.cfg` (regenerar desde el editor).
4. **Resolver los `.uid`**: versionarlos todos (recomendado, para reproducibilidad del import en
   CI) o añadir la regla que falte al `.gitignore`.
5. **Ampliar el techo de `main.gd` de forma explícita** o dejar documentado por qué 1710 es
   definitivo, para que el siguiente cambio no tropiece con 3 líneas de margen.

**Media prioridad (calidad de mantenimiento):**

6. **Continuar la extracción de `main.gd`** por el patrón ya probado (#57–#63): los manejadores
   de diálogo podrían migrar a un `dialogos_controller` puro, y las funciones `_ui_*` que solo
   delegan podrían agruparse. Bajar el techo de 1710 en vez de subirlo.
7. **Unificar la convención**: eliminar los 5 `class_name` o adoptarlo de forma general y
   actualizar `AGENTS.md`.
8. **Limpieza de residuos**: `icon.svg` de la raíz, `data/servidores.json`, `locale/*.translation`.
9. **Versionar un arnés de mutation testing** (aunque sea un script mínimo) para poder repetir
    el proceso.

**Baja prioridad (mejoras):**

10. Revisar la cadencia de `backup_to` en SQLite si el catálogo crece mucho (backup por escritura).
11. Quitar `physics/3d/physics_engine` de `project.godot`.
12. Añadir un `pipeline` de *lint*/formato GDScript (p. ej. `gdtoolkit`) a la CI, que hoy no
    comprueba estilo (tabs, orden) más allá del parseo.

---

## 16. Anexo — comandos y rutas verificados

**Ejecutar la batería** (Windows, Git Bash):

```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'
```

**Una sola suite** (`PATRON=tests/test_almacen_bd.gd`) o directa:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_almacen_bd.gd
```

**Comprobación estática** (antes de la batería):

```bash
GODOT_BIN=/ruta/a/godot bash tests/run_estatico.sh
```

**Smoke del binario exportado**:

```bash
godot --headless --path . --export-release "Windows" build/gestor.exe
SMOKE_BIN=build/gestor.console.exe bash tests/run_smoke.sh
```

**Regenerar iconos**:

```bash
godot --headless --path . --script res://scripts/generar_iconos.gd
```

**Rutas en ejecución:**

- `user://` → `C:\Users\<usuario>\AppData\Roaming\Godot\app_userdata\GestorAO\`.
- Datos del usuario: `enlaces.json`, `estados.json`, `borrados.json`, `colas.json`,
  `config.json`, `instantaneas.json`, `presets_filtros.json`, `cambios_pendientes.json`
  (modo ficheros) · `gestorao.json` (único) · `gestorao.db` (base de datos).
- Preferencia de almacenamiento: `user://almacenamiento.json` (siempre en `user://`).
- Capturas: `Assets/png|jpg` (dentro de la base de datos elegida).

**Gotchas operativos (documentados en `MEMORIA.md`):**

- SQLite necesita `--headless --import` una vez: si no, `preload(".../almacen_bd.gd")` revienta
  con `Identifier "SQLite" not declared`.
- Un checkout fresco (CI) no trae `.godot/`: hay que `--import` antes de la batería o los
  `--script` se cuelgan.
- Las suites que montan `Main` fijan `GESTORAO_ALMACEN=ficheros` para no heredar el modo del
  `user://almacenamiento.json` real.

---

*Fin del informe.*
