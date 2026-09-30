# Changelog

Todos los cambios relevantes de GestorAO por día.

## [Sin publicar]

### Añadido

- **Aceptar los certificados TLS no válidos** (`#56`): Preferencias → Escaneo suma un tercer interruptor, **Aceptar los certificados TLS no válidos**, desactivado por defecto. La comprobación es en dos pasos: primero valida el certificado como siempre y, solo si el handshake **falla de verdad**, repite la conexión con `TLSOptions.client_unsafe(null)`; así la revisión se mantiene intacta para los enlaces con buen certificado en vez de avisar de todo lo que sea `https`. Si esa segunda conexión responde, el enlace pasa a **válido con aviso** (`estado = "ok_tls"`, pintado con la clave de paleta `aviso`): sigue contando como disponible en el contador, en el dashboard y en el filtro «válido», no aparece entre los problemáticos y solo salta en la columna **Causa** y en el tooltip. Si tampoco responde se informa de **Sin conexión segura** y no se da por bueno. Con la opción desactivada se comporta como hasta ahora (caído, motivo `tls`). El diagnóstico (`info.txt`) registra `tls_aceptar_certificados` y `tls_aviso`, y el log de escaneo distingue `valido_tls` de `caido_tls`. Fixture TLS versionado en `tests/fixtures/` y suite `tests/test_link_checker_tls.gd`.

- **Reintentos y «sin comprobar»** (`#54`): Preferencias gana el bloque **Escaneo** con dos interruptores independientes y activos por defecto, **Reintentar los fallos transitorios (2 veces)** y **Marcar los fallos de red como «sin comprobar» en vez de «caído»**; la fila y el historial añaden el sufijo «(N intentos)» al detalle; y el informe CSV/HTML gana la columna **Causa** más un bloque **Resumen por causa** (`InformeStore.estado_texto()`, `causa_texto()` y `resumen_por_causa()`).

- **Internacionalización ES/EN** (`#30`): selector de idioma con banderas en Preferencias, CSV de traducciones (`locale/gestor_es_en.csv`), carga de traducciones al arrancar y `tr()` en toda la UI (textos de escaneo, dialogs, menús, cabeceras de columna e historial). Scanner de cadenas de UI (`scripts/extraer_cadenas.gd`) con test de cobertura (`test_locale.gd`).
- **Ordenación por columnas** (`#17`): cabeceras pulsables en la lista (fecha, nombre, imagen, estado) con criterio persistido en configuración y restauración al arrancar.
- **Capturas del catálogo**: las tres entradas de Twister-AO (cliente, códigos y servidor) usan ya la imagen `Twister-AO (Servidor).jpg`, y la captura de la liberación de Tierras Sagradas pasa a llamarse como su enlace (`Liberación Tierras Sagradas - v2.png`, entrada `Tierras Sagradas - v2`) para que el recurso siga al nombre del enlace.
- **Rediseño del dashboard de estadísticas** (`#49`): la ventana pasa de dos listas planas sobre un `ColorRect` a un panel con superficies `PanelContainer` y, de arriba abajo, una fila de tarjetas KPI (total, disponibles, caídos y sin comprobar, con barra de ratio), un bloque de disponibilidad con el porcentaje grande y su barra, el gráfico diario con rejilla, eje de valores, etiquetas de fecha, leyenda y globo al pasar el ratón, las tablas de categoría y de host con cabecera pulsable (orden por nombre, válidos, caídos, disponibilidad y fecha; segunda pulsación invierte el sentido), barra de disponibilidad por fila y doble clic para llevar ese filtro a la lista, y el bloque **Enlaces que más han caído** con veces, último código HTTP y fecha. Se añade el selector de rango (7/30/90 días o todo el histórico, por defecto todo), el estado vacío de catálogo (con botón **Comprobar enlaces**) y el aviso de catálogo todavía sin comprobar. El store gana `serie_diaria(dias)`, `top_caidos()` y `ultima_comprobacion()`, y el CSV/JSON exportados incluyen el bloque de enlaces problemáticos. El gráfico mantiene las dos series (válidos/caídos) porque el historial no guarda un contador diario de "sin comprobar"; los días sin comprobaciones no aparecen en la serie. Piezas nuevas `scenes/TarjetaKpi.tscn`, `scenes/FilaTabla.tscn` y suite propia `tests/test_dashboard_ui.gd`; `tema_store` expone `relleno()` y un `TooltipPanel` temático para el globo del gráfico.

### Cambiado

- **Tarjeta de la vista de grilla** (`#43`): altura mínima de 176 a 240 px, fuente de las cinco etiquetas a 10 y sin autowrap (con `clip_text`) para que la tarjeta mantenga un tamaño fijo en la grilla en vez de crecer con la longitud del texto.

### Rendimiento

- **Reverse-lookup de mensajes de estado cachado** (`#40`): mapa render→clave construido una vez por locale para los mensajes fijos y caché memoizada para los mensajes con `%d`; `_clave_de_mensaje()` ya no recorre todas las claves del CSV por fila y por tooltip en cada reconstrucción de la lista.

### Mantenimiento

- **El guardado de la configuración sale de `main.gd`** (`#62`, parte 3 de 4): persistir la configuración estaba repetido en cuatro funciones de `main.gd` que llamaban a `ConfigStore.guardar()` con veinte argumentos posicionales, y dos de ellas (`_persistir_orden()` y `_persistir_filtros()`) eran copia literal una de otra. El orden de esos argumentos era un contrato invisible: nadie lo comprobaba y nadie lo escribía dos veces igual. Ahora la lista de claves vive en `scripts/config_controller.gd` (`RefCounted`), una sola vez, y es la que se expande en los veinte posicionales; `main.gd` solo aporta el estado de la UI con `_config_desde_ui()` y llama a `guardar(cambios)`, que fusiona esos cambios sobre la configuración guardada y descarta claves desconocidas. Se elimina una de las dos funciones duplicadas (`_persistir_orden` / `_persistir_filtros` quedan en una sola, `_persistir_config()`). Nueva suite `tests/test_config_controller.gd` (30 comprobaciones) que verifica contra `ConfigStore.get_method_list()` que la lista de claves tiene tantos elementos como argumentos tiene `guardar()` y en el mismo orden, así que añadir un campo nuevo al store sin actualizar el controlador hace fallar el test. `test_empaquetado` vigila que la extracción no se revierta y que `main.gd` no vuelva a crecer. `main.gd` baja de 1573 a 1546 líneas.
- **La lógica de filas, filtros y orden sale de `main.gd`** (`#62`, parte 2 de 4): el pool de filas recicladas, la aplicación de filtros y el reordenado estaban en cinco funciones de `main.gd` que había que probar levantando la escena `Main` entera. Ahora viven en `scripts/lista_controller.gd` (`RefCounted`), que expone `configurar()` (criterios), `aplicar()` (visibilidad + orden en una pasada), `ordenar()`, `filas_visibles()` y el pool (`pool_tomar()`, `pool_devolver()`, `pool_vaciar()`, `cambiar_vista()`). Se corrigen de paso dos fragilidad sin cobertura: `clave_de_categoria()` ahora devuelve `""` en vez de reventar si el índice se sale de `CATEGORIAS` (`main.gd` indexaba a ciegas), y `aplicar()`, `ordenar()` y `filas_visibles()` toleran un contenedor nulo. Nueva suite `tests/test_lista_controller.gd` (47 comprobaciones) que ejercita los filtros de estado (incluido el triestado `valido` de #54), categoría, etiqueta, código y rango de días, los cuatro modos de orden, y el ciclo completo del pool **sin instanciar `Main`**. `main.gd` baja de 1615 a 1573 líneas.
- **El control del escaneo sale de `main.gd`** (`#62`, parte 1 de 4): la máquina de estados del escaneo estaba repartida en quince funciones de `main.gd` que mezclaban la cola con la barra de progreso, el diálogo de reanudación y los temporizadores del auto-escaneo, así que solo se podía probar instanciando la escena `Main` completa. Ahora vive en `scripts/scan_controller.gd` (`RefCounted`, sin una sola dependencia de la UI), con `preparar()` / `lanzar()` / `item_terminado()` y las señales `progreso(hechos, total)`, `item_actualizado(item)` y `terminado(total, caidos)`. `main.gd` se queda solo con traducirlas a etiquetas, colores y botones. Se extraen también las tres piezas de lógica que estaban incrustadas en el diálogo: el filtrado de la cola guardada contra el catálogo (`pendientes_validas()`, que reutiliza `clave_unica` y por tanto respeta el mismo criterio que el resto de la app), la reconstrucción de la cola al reanudar (`rearmar_pendientes()`) y la conversión del intervalo de minutos a segundos del Timer (`auto_espera()`). Nueva suite `tests/test_scan_controller.gd` (51 comprobaciones) que cubre paralelismo, tope por host, huecos reutilizados, items liberados a mitad de cola, triestado `valido` (cuenta como caído solo el `false`, no el `null` de #54), reanudación y auto-escaneo **sin instanciar `Main`**. `test_main_flujos` y `test_main_arranque` se quedan con lo que es integración de verdad. Batería 40/40.
- **La CI podía colgarse seis horas sin decir qué suite era** (`#61`, parte 1 de 2): una suite con un `Parse Error` no compila y por tanto nunca llega a llamar a `quit()`, así que Godot se quedaba vivo para siempre; sin red de seguridad eso no es un rojo, es el job entero quemando las 6 horas por defecto de GitHub Actions. Además `run_battery.sh` **abortaba en silencio**: el `salida="$(…)"` estaba bajo `set -e`, de modo que una suite con `exit != 0` mataba el script entero sin imprimir una sola línea de la que falló. Ahora cada suite va con `timeout -k 10` propio (`TIMEOUT_SUITE`, 180 s por defecto, `PATRON` para correr una sola), los códigos 124/137 se reportan como `COLGADA` en vez de confundirse con un fallo normal, cada invocación captura su estado con `|| estado=$?` y el resumen dice cuántas se colgaron. Nuevo `tests/run_estatico.sh`, que analiza los 77 `.gd` de `scripts/` y `tests/` con `--check-only` (un segundo por fichero, sin cargar escenas) y **sí** devuelve código distinto de 0 con un error de parseo, al contrario que `--import`, que escupe el ruido benigno ya conocido (`Parse Error: Native class TextFile` y el `Failed to load script` del `preload` del `.tscn` en `test_preferencias.gd`) y sale con `exit=0`. El job de CI lleva `timeout-minutes: 20` y ejecuta el paso estático entre el import y la batería. `test_empaquetado` sube el listón y comprueba que las protecciones siguen ahí. Batería 39/39.
- **Limpieza de residuos sin versionar** (`#41`): versionados el addon tercero `addons/godot_ai` (Godot AI v3.2.1, licencia MIT incluida) y el bloque `[autoload]/[editor_plugins]` de `project.godot` (el addon retira su autoload MCP de los builds exportados); `export_presets.cfg` regenerado por el editor 4.7 (la CI exporta con rutas explícitas); metadatos de Godot pendientes (16 `.uid`, 2 `.translation`, 7 `.import`). Eliminados localmente `data/data2.json` (no lo usa la app) y 2 `.import` huérfanos de `Assets/png`. Los planes ajenos sin commitear quedan en `.gitignore`.
- **Aislamiento de los tests de integración** (`#48`): `main.gd` y `agregar_enlace.gd` tenían la base de assets escrita a pelo (`res://Assets`), así que las cuatro suites que instancian `Main` (`test_main_arranque`, `test_main_catalogo`, `test_main_flujos`, `test_main_orden`) escribían y **borraban las capturas reales del catálogo** en cada batería, sin que ningún check fallara. Ahora la base es `ASSETS_BASE` (junto a `DATA_RES`/`DATA_USER`/`CONFIG_BASE`, y la ventana de alta la hereda), las suites la apuntan a `user://__test_*__/Assets` y `test_proyecto` falla si alguien vuelve a escribir `res://Assets` a pelo o si una suite instancia `Main` sin aislar la base. Nuevo `tests/ayuda.gd` con `borrar_arbol()` para la limpieza de las bases temporales.
- **Addon `godot_ai` actualizado de v3.2.1 a v4.2.3**: se vendoriza el árbol completo de la línea 4.x (clientes codebuddy/omp/zcode, handlers de comandos, navegación, shaders y mutaciones de ficheros, locks de cliente, verificador de releases y puente de migración v3→v4). Requisito Godot 4.7+ y autoload `_mcp_game_helper` sin cambios; solo afecta al editor y el `EditorExportPlugin` sigue retirando el autoload MCP de los builds exportados. Batería 33/33.

### Corregido

- **Ordenar la lista borraba tus preferencias de escaneo** (`#62`): al guardar el criterio de orden, los filtros o la versión vista, `main.gd` reescribía `config.json` entero pasando solo diecisiete de los veinte campos de `ConfigStore.guardar()`, así que los tres añadidos para reintentos y certificados (`reintentar_transitorios`, `red_sin_comprobar`, `aceptar_certificados`, de `#54` y `#56`) volvían silenciosamente a su valor por defecto. En la práctica: activar **Aceptar los certificados TLS no válidos** y luego pulsar una cabecera de columna deshacía el ajuste —el checkbox de Preferencias se desmarcaba solo—, y **Reintentar los fallos transitorios** volvía a activarse. Ahora el guardado pasa siempre por `config_controller.guardar()`, que fusiona los cambios sobre lo que ya estaba guardado, así que un campo que no se toca conserva su valor. Cubierto en `tests/test_config_controller.gd` y en `tests/test_main_orden.gd` (el camino real: aplicar preferencias → ordenar → cerrar el diálogo de versión).
- **Un fallo puntual de red marcaba el enlace como caído y el menú ofrecía borrarlo** (`#54`): el verificador decidía en el **primer** error de red o en el primer 429/503 y emitía `terminado(false, …)` sin reintentar, así que un corte de Wi-Fi, un «503» de MediaFire o un «429 Too Many Requests» se guardaban como **caído** en el historial, contaminaban el dashboard y dejaban la fila con **Eliminar** a dos clics: pérdida de datos causada por un fallo ajeno al enlace. Ahora `link_checker` clasifica el fallo (`es_transitorio()`: red y DNS; 429, 500, 502, 503 y 504) y reintenta dos veces con espera creciente (1 s y 4 s) **desde el mismo comprobador**, de modo que no se abren comprobadores extra ni se salta el tope por host, y el reintento vuelve siempre a la URL inicial tras un redirect; el timeout sigue contando por intento. Se respeta la cabecera `Retry-After` (segundos o fecha HTTP, capada a 10 s para que un 429 de 600 s no deje el escaneo colgado) y los definitivos (404/410, marcas de archivo muerto, TLS inválido, URL inválida) no se reintentan nunca. Si aun así el fallo es de entorno, la fila se guarda como **sin comprobar** (`valido = null`, `estado = "sin_comprobar_red"`) y no como caída, así que ni el menú de la fila, ni el contador de caídos de la barra final, ni el dashboard lo cuentan como roto; el motivo (`ok|red|dns|tls|http|muerto|url`) queda en el tooltip, en el log de escaneo y en la columna **Causa**. `estado_store` persiste `intentos` y `motivo` y no reescribe la entrada cuando solo cambian esos campos, para no llenar el historial de ruido. Suites nuevas `tests/test_link_checker_reintentos.gd` y `tests/test_historial.gd`, y `tests/servidor_http.gd` extraído como servidor local reutilizable.
- **El dashboard de estadísticas no se podía cerrar**: la ventana `VentanaDashboard` es una `Window` con `exclusive = true` pero, a diferencia de Preferencias, Historial y Agregar enlace, no conectaba `close_requested` a `hide` ni tenía botón de cerrar, así que la X del SO no hacía nada y la ventana principal quedaba bloqueada por el modo exclusivo. Ahora la X, un botón **Cerrar** en la fila de acciones y la tecla Esc cierran el dashboard.
- **Exportar a `.exe` no arrancaba (`Cannot get class ''`)**: las subescenas de `Main.tscn` (`AgregarEnlace`, `Preferencias`, `Historial`, `ListItem`, `GridItem`) declaraban uids inventados en su cabecera (`uid://hpreferencias001`, `uid://bhistorial0001`, `uid://bgestoritem001/002`) no registrados en `uid_cache.bin` — dos de las referencias de `Main` (`uid://cxtkcrqj7ne7i`, `uid://cup4r7bqx0age`) además con 13 chars, fuera de rango int64 (uids inválidos). Al exportar, el pack convierte las escenas a `.scn` y las resuelve por uid, así que `VentanaAgregar`/`VentanaPreferencias` quedaban como placeholders vacíos y `main.gd` fallaba en cadena (`main.gd:44`, `main.gd:98`); peor aún, al guardar `Main.tscn` desde el editor, este borraba silenciosamente los nodos instanciados cuya referencia por ruta apunta a una escena con uid fake (dejaba las ventanas sin `instance=` y `%VentanaAgregar` sin resolver). Arreglado eliminando los uids falsos de las cabeceras de las 6 escenas (quedan sin uid, patrón de `Dashboard.tscn`, que siempre funcionó) con referencias solo por ruta. Verificado exportando el PCK y el `.exe` completo y arrancándolos en headless y con ventana D3D12/consola sin errores; batería 33/33.
- **Ventana principal cortada/solapada a los lados**: la fila de acciones (12 controles tras los filtros avanzados de `#44`) exigía un ancho mínimo de ~1412 px, más que la ventana base de 1152 px (default de Godot: nunca hubo `viewport_width/height` definido), desbordando el contenido y recortándolo por ambos lados. Arreglado fijando el tamaño base de ventana a 1440×810 (`display/window/size`) y convirtiendo `BarraAcciones` de `HBoxContainer` a `FlowContainer`, de modo que la barra salta a dos líneas en ventanas más estrechas en vez de cortarse.
- **Colores de estado que no seguían al tema** (`#55`): "Comprobando…" y "URL inválida" se pintaban con colores sueltos escritos a pelo en la fila (visibles sobre todo en tema claro) y, al cambiar de tema, la etiqueta y el punto de estado de cada fila se quedaban con el color del tema anterior: `tema_store.aplicar()` solo recoloreaba los `Label` con overlay viejo y los `ColorRect` llamados `Fondo`. Ahora la paleta declara las claves `comprobando`, `aviso` y `acento` en los dos temas, y `tema_store` gana `color_clave(clave)` y `marcar(nodo, clave)`, que guarda la clave en el meta `tema_clave` del nodo para que `aplicar()` repinte la etiqueta y el indicador en cada cambio de tema sin rehacer la lista. `list_item` pinta por clave semántica en los cinco estados, y la barra final de progreso y el contador **Total** también toman el color de la paleta. El verde del tema claro se oscurece un punto (`0.09, 0.5, 0.2`) para llegar a 3.49:1 de contraste sobre el fondo real del botón (antes 2.97:1). `test_tema_store` mide el contraste de los cinco estados contra el fondo del tema y `test_main_arranque` comprueba que una fila real sigue al cambio de tema en los dos sentidos.
- **El verificador daba por buenos enlaces borrados y se comía el archivo entero** (`#53`): al recibir las cabeceras leía **un solo chunk** de cuerpo y decidía con ese trozo, así que la página de "archivo eliminado" que llega después (o partida en varios chunks) se escapaba y el enlace se guardaba como **OK**; además la petición no llevaba `Range`, así que un enlace a un archivo grande empezaba a bajar entero para nada. Ahora `link_checker` acumula evidencia de cuerpo hasta 64 KB (`LIMITE_CUERPO`) y solo decide cuando el cuerpo está completo (`Content-Length` alcanzado), se agota el presupuesto o pasan 0.4 s sin bytes nuevos (`ESPERA_CUERPO`), y busca la marca de página muerta en todo lo leído, parando en cuanto aparece. La petición lleva `Range: bytes=0-65535` y un `416` se reintenta una vez sin `Range` (archivos vacíos), y un `206` se reporta como `OK (200)`. El timeout de `timeout_s` pasa a cubrir también la fase de cuerpo. Además el checker ya no se cuelga ni reporta "error" cuando el servidor termina la respuesta y cierra (o corta el cuerpo a medias): antes eso acababa en "Error de conexión" y marcaba como caído un enlace sano. `test_link_checker_timeout` monta un servidor HTTP local y cubre los nueve casos (cuerpo tardío, `Range`, 206, 416, presupuesto, chunked, cierre del servidor, goteo con timeout y 404).

---

## [0.1.9]

### Añadido

- **Capturas con el nombre del enlace** (`#47`): al adjuntar una imagen, el archivo se guarda en `Assets/png|jpg` con el nombre del enlace (p. ej. `BowAO (Cliente).png`), limpiando caracteres no válidos del sistema de archivos, colisiones con sufijo numérico (`-1`, `-2`…) y márgen de 60 caracteres. Sin nombre útil se conserva el patrón `img_<ts>`.
- **Limpieza y dedup con capturas con nombre**: `copiar()` y `limpiar_huerfanas()` ya no filtran por prefijo `img_`; escanean cualquier `.png`/`.jpg` de las carpetas de capturas y protegen los recursos fijos (`no-disponible.png`). `copiar()` y `limpiar_huerfanas()` admiten una base de assets parametrizable (los tests usan `user://__test_*__`, sin residuos en `res://`).

### Cambiado

- Versión del proyecto a 0.1.9.

---

## [0.1.8]

### Añadido

- **Diálogos de archivo nativos del sistema** (`#38`): los 6 `FileDialog` del proyecto (elegir imagen, importar catálogo, exportar, informe de disponibilidad, diagnóstico y exportar estadísticas del dashboard) usan `use_native_dialog = true`, abriendo el diálogo nativo de Windows/macOS y, en Linux, el del XDG desktop portal (proceso separado, no bloquea el hilo). Aporta historial de archivos recientes del SO y navegación completa del disco con aspecto familiar. En entornos sin soporte nativo (headless/CI) Godot mantiene el diálogo embebido.

### Cambiado

- Versión del proyecto a 0.1.8.

---

## [0.1.7]

### Añadido

- **Tema automático del sistema** (`#46`): nueva opción **Automático** en Preferencias (junto a Oscuro y Claro). Al arrancar detecta el modo claro/oscuro del SO (`DisplayServer`) y aplica el tema correspondiente; si el sistema cambia de tema mientras la app está abierta, el tema se actualiza en vivo. El override manual sigue disponible y la preferencia (auto/manual + tema elegido) se guarda en configuración. En sistemas sin soporte de detección cae al tema oscuro.

### Cambiado

- Versión del proyecto a 0.1.7.

---

## [0.1.6]

### Añadido

- **Deduplicación de capturas** (`#36`): al adjuntar la misma imagen a varios enlaces, la segunda copia reutiliza la captura existente (hash SHA-256 del contenido) y avisa en la barra de estado; no se acumulan archivos duplicados en `Assets/png` y `Assets/jpg`.

### Cambiado

- Versión del proyecto a 0.1.6.

---

## [0.1.5]

### Añadido

- **Dashboard de estadísticas** (`#45`): ventana desde el menú Utilidades con resumen de disponibilidad (válidos, caídos, sin comprobar y % disponible sobre los comprobados), distribución por categoría y por host (los más problemáticos primero), gráfico de comprobaciones válidas vs caídas por día a partir del historial y exportación a CSV/JSON.

### Cambiado

- Versión del proyecto a 0.1.5.

---

## [0.1.4]

### Añadido

- **Vista de grilla** (`#43`): botón que alterna entre lista y cuadrícula de tarjetas (miniatura grande con nombre, estado y fecha); los filtros y la ordenación se aplican igual en ambas vistas y la vista elegida queda persistida en configuración.

### Cambiado

- Versión del proyecto a 0.1.4.

---

## [0.1.3]

### Añadido

- **Presets de filtros** (`#44`): guardar la combinación actual de filtros (estado, categoría, etiqueta, búsqueda, código HTTP, días y modo) bajo un nombre, aplicarla desde el desplegable y eliminarla; hasta 20 presets en `user://presets_filtros.json`. El filtro por días se aplica en vivo al cambiar el SpinBox.

### Cambiado

- Versión del proyecto a 0.1.3.

---

## [0.1.2]

### Añadido

- **Filtros avanzados** (`#44`): búsqueda booleana AND/OR por palabras en nombre/descripción/URL, filtro por código HTTP (200, 301, 302, 403, 404, 410, 500, 503) y filtro por última comprobación (últimos N días), combinables con estado, categoría y etiquetas; los tres criterios nuevos se persisten en configuración.

### Cambiado

- Versión del proyecto a 0.1.2.

---

## [0.1.1]

### Añadido

- **Etiquetas personalizadas** (`#42`): campo en el alta de enlaces con sugerencias por uso frecuente, normalización de etiquetas y filtro por etiqueta combinable con estado y categoría, con el criterio persistido en configuración.
- **Barra de estado con colores**: nombre de contador en blanco y número en color — Rotos (rojo), Activos (verde) y Total (azul).

### Cambiado

- Versión del proyecto a 0.1.1.

---

## 2026-09-24

- Implementación completa de `#30` (internacionalización): `config_store` guarda y valida el idioma, CSV ES/EN con scanner y test de cobertura, banderas de idioma generadas, selector en Preferencias y aplicación de idioma con `tr()` runtime (6 commits).

---

## 2026-09-23

- Spec y plan de `#30` (internacionalización).
- Ordenación por columnas (`#17`): spec, plan, persistence del criterio en config, exposición de nombre/imagen en `list_item`, cabeceras en la escena e integración con persistencia y rollback (7 commits).
- Orden manual de la lista (`#6`): helpers de reorden, estados del menú contextual, tests con filtros y persistencia; plan y spec (4 commits).
- Detalles de la convención de cierre de issues (AGENTS.md).

---

## 2026-09-20

- Aviso de nueva versión (`#27`): comparador de versiones y parse de `releases/latest` (TDD), nodo `HTTPClient` que consulta la API y aviso una vez por versión con opción de menú. Orden manual de la lista (`#6`): spec y plan del menú contextual Subir/Bajar (7 commits).

---

## 2026-09-19

- Tema claro/oscuro (`#19`): store con paletas y `aplicar` (TDD), selector `%Tema` en Preferencias y aplicación en arranque; `list_item` pinta con paleta (4 commits).
- Informe de disponibilidad (`#11`): store CSV/HTML, menú Archivo con FileDialog y checks de integración (3 commits).
- Cola de escaneo persistida (`#13`): store de `user://colas.json`, persistencia en cada avance y diálogo de reanudación (4 commits).
- Detectores de enlace caído por host (`#12`): marcas host-específicas (MEGA, MediaFire, Drive, Sites, Dropbox, WeTransfer) con unión a las genéricas (2 commits).
- Ajustes de Preferencias por contenido, import ETC2 ASTC para macOS universal, import previo a la batería en CI y README/empaquetado/logs/diagnóstico (9 commits).

---

## 2026-09-18

- Empaquetado y CI (`#26`): presets Windows/Linux/macOS y workflow GitHub Actions (2 commits).
- Logs y diagnóstico (`#28`): logger rotativo app/scan y exportador de ZIP con `info.txt` (3 commits).
- Icono y metadatos (`#29`): generador de iconos SVG/PNG/ICO/ICNS y proyecto 0.1.0 (2 commits).
- Correcciones de la spec de empaquetado y extras (3 commits).

---

## 2026-09-15

- Disponibilidad de enlaces (`#8`, `#9`, `#10`): auto-escaneo al abrir con intervalo, fecha de última comprobación visible, selector de orden por fecha y diálogo de historial con cap de 50 (8 commits).

---

## 2026-09-14

- Datos persistentes confiables (`#23`, `#24`): `gestor_datos.gd` con esquema versionado, escritura atómica y copia de seguridad; menú Restaurar copia y detección de fallos (5 commits).
- Normalización de URLs (`#25`): `normalizar_url` y `clave_unica`, deduplicación de variantes en carga, alta, lote y edición; estados y contadores por clave canónica (4 commits).
- Ventana Agregar enlace (`#32`, `#33`): redimensionable, diálogo de imagen jpg/jpeg/webp y copiado por formato con limpieza en Assets/jpg (4 commits).
- Importar/exportar catálogo y atajos (`#3`, `#14`): desde el menú Archivo; Ctrl+F/N/R y Esc (3 commits).
- Tests de `link_checker` (`#31`): marcadores, parseo, redirects y sin red (3 commits).
- Correcciones y planes asociados (11 commits).

---

## 2026-09-13

- Categorías (`#5`): helpers en `gestor_catalogo`, campo en alta/edición, etiqueta en filas y desplegable de filtro combinado estado+categoría (7 commits).
- Capturas (`#20`, `#21`, `#22`): cambiar/quitar captura al editar con reporte de imagen pendiente, limpieza de huérfanas desde menú y al cerrar, y redimensionado a 800px (8 commits).
- Sidecars `.uid` de Godot 4.7 versionados y ajustes de conteos (5 commits).

---

## 2026-09-12

- Alta y edición de enlaces (`#1`, `#2`, `#4`): helpers de catálogo (dominio, separar), diálogo multi-modo, edición con remapeo de estado y borrados, lote de URLs con duplicados y menú contextual (14 commits).
- Plan y spec del catálogo; correcciones de conteos y tipos (1 commit).

---

## 2026-09-07

- Corrección de `abrir_edicion` en modo Varias y conteos del plan (1 commit).

---

## 2026-09-06

- Preferencias de escaneo (`#7`): `config_store` para paralelismo/timeout, diálogo de preferencias e integración en main (7 commits).
- Lote de UI (`#15`, `#16`, `#18`): barra de progreso, copiar URL, tooltip de estado, código HTTP y fecha (5 commits).
- Contadores con código HTTP y fecha; lista de servidores inicial y sidecars `.uid` (5 commits).
- Plan y spec del catálogo base; ajustes de checks (7 commits).

---

## 2026-09-05

- Base del proyecto (1 commit).
- Barra de estado (`#8` parcial): contadores del catálogo y versión 0.0.1 (4 commits).
- Persistencia del escaneo (`#1`, `#2`): `EstadoStore`, eliminación de caídos y re-comprobación individual (5 commits).
- Capturas/imagen (`#1`): selector y copiado, miniatura con placeholder y borrado del archivo (6 commits).
- README profesional y ajustes varios (3 commits).

---

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/).