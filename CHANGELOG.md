# Changelog

Todos los cambios relevantes de GestorAO por día.

## [0.3.0]

### Cambiado

- Versión del proyecto a 0.3.0.

### Añadido

- **Un único fichero para todos los datos** (`#63`, fase 2): Preferencias → Almacenamiento suma el selector **Cómo se guardan los datos**, con **Ficheros sueltos** (los ocho JSON de siempre, que siguen siendo el modo por defecto y no cambian un byte de lo que ya tiene el usuario), **Un único fichero** (todo dentro de `gestorao.json`) y **Base de datos** (todavía no, y el tooltip lo dice). El backend nuevo es `scripts/almacen_uno.gd`: las ocho secciones dentro de un solo JSON, escritura atómica como el resto (`.tmp`, `.bak` y rename) y `schema_version` dentro de cada sección, igual que la que lleva `enlaces.json` por dentro. Un fichero escrito por una versión más nueva se marca `_futuro` y **rechaza toda escritura** en vez de dejarse pisar, y el arranque avisa de que esos datos no se tocarán hasta que se abran con esa versión. Elegir un modo **migra**: primero la copia, con los recuentos de sección por el medio, y solo después la preferencia, así que una migración que pierde algo no deja nada escrito ni apunta la app a un sitio al que no llegó nada. `guardar_estados_y_borrados()` convierte estados y borrados en **una** escritura (borrar una entrada deja su estado y su marca juntos; con dos ficheros sueltos un corte a mitad deja una cosa sin la otra), `limpiar_cola()` vacía la sección en vez de borrar el fichero y `hay_copia()`/`restaurar_copia()` se apoyan en el `.bak` del fichero único. Piezas nuevas: `scripts/almacen_uno.gd` y las suites `tests/test_almacen_uno.gd` (26 comprobaciones) y `tests/test_stores_almacen.gd` (16).

### Cambiado

- **Los stores escriben a través de la interfaz** (`#63`): `AlmacenController.para_stores()` devuelve el backend **solo cuando no es el de ficheros**, y con él arrancan ahora `config_store`, `cola_store`, `estado_store`, `instantanea_store`, `presets_store` y los cambios pendientes de `cambios_controller` — que hasta ahora escribían siempre sus JSON en `user://` mientras el catálogo se iba a otra parte. Cada store conserva su lógica y solo decide **dónde** persiste: en modo ficheros se comporta igual que antes, fichero por fichero, y en cualquier otro modo todo va al mismo sitio. `main.gd` pasa a leer y guardar el catálogo del usuario por el mismo camino (`entradas_de()`, `guardar_entradas_en()`, `hay_copia()` y `restaurar_copia()`), que es la única parte de los datos que escribía a pelo. En modo ficheros esos cuatro métodos respetan la ruta que les pasa quien llama, porque `main` y las suites reapuntan `DATA_USER` a su carpeta: ignorándola se leería el catálogo real del usuario y, al limpiar capturas huérfanas, se le borrarían sus imágenes. La preferencia sigue viviendo en `user://almacenamiento.json` en todos los modos, también en el único: si se mudara con los datos no quedaría forma de saber dónde estaban.

### Corregido

- **La ventana de Preferencias ya no se sale de la pantalla** (`#64`): al abrirla se estiraba al alto de todo su contenido (`wrap_controls = true`) y, con la sección de Almacenamiento de la fase 2, pasaba de los 1000 px cuando la ventana del juego mide 810: los botones **Guardar** y **Cancelar** quedaban por debajo del borde. La lista de ajustes va ahora dentro de un `ScrollContainer` de alto acotado (420 px), así que la ventana se queda en unos 569 × 526 px y lo que no cabe se desplaza; los botones viven fuera del área que se desplaza, siempre a la vista. `test_preferencias` añade dos comprobaciones —el área se desplaza y la ventana cabe en la pantalla— verificadas en su dirección negativa subiendo el tope.
- **Elegir destino a mano al cambiar de carpeta o de modo** (`#63`): `_carpeta_elegida()` migraba siempre a `AlmacenJson`, así que en modo único copiaba los datos como ocho ficheros con la preferencia apuntando a `gestorao.json`, y al reiniciar la app abría un fichero que no existía: catálogo vacío. `_modo_elegido()` hacía lo contrario y construía siempre `AlmacenUno`, con lo que pasar de único a ficheros re-copiaba `gestorao.json` sobre sí mismo y dejaba los ocho JSON sin tocar, de modo que la preferencia apuntaba a un catálogo que nadie había escrito. Los dos casos pasan por `AlmacenController.crear_en(modo, base)`, la misma fábrica que usa el arranque, y el cambio de modo admite además `pisar`: en la misma carpeta el «destino con datos» es la otra versión de estos mismos datos, y negarlo dejaba el selector sin poder volver atrás nunca.
- **`cambios_pendientes.json` se abría en `WRITE` y se escribía encima** (`#63`): un corte a mitad dejaba el fichero corrupto y con él se perdía el aviso de cambios sin ver de la sesión anterior. Pasa a la escritura atómica del resto, igual que los otros stores en los que ya se había hecho.

### Mantenimiento

- **Cobertura de la fase 2** (`#63`): la batería sube de 57 a **59 suites** (`test_almacen_uno`, `test_stores_almacen`) y el estático de 111 a **114 ficheros**. `test_stores_almacen` monta `Main.tscn` en modo único con `GESTORAO_ALMACEN`/`GESTORAO_BASE` para cubrir el cableado de `main.gd` **sin escribir el `user://almacenamiento.json`** de la máquina, y `test_preferencias` re-apunta el fichero de preferencias a su carpeta propia (`config_ruta`) antes de cambiar de modo. Las rutas de destino, el `pisar` de la migración y el guardián de `ruta` se han verificado también en su dirección negativa (mutaciones revertidas y comprobadas una a una).

## [0.2.0]

### Cambiado

- Versión del proyecto a 0.2.0.

### Añadido

- **Interfaz de almacenamiento y carpeta de datos configurable** (`#63`, fase 1 de 2): los datos dejan de estar repartidos en hardcodes y pasan a hablar con una interfaz, `scripts/almacen.gd`, que describe las ocho secciones que la app guarda (`entradas`, `estados`, `borrados`, `cola`, `config`, `capturas`, `instantaneas`, `presets` y `cambios` — ocho ficheros, no los cinco que decía el issue). El backend de ficheros, `scripts/almacen_json.gd`, escribe **exactamente los mismos JSON que los stores de siempre**: la suite escribe con `estado_store`, `cola_store`, `config_store` y `gestor_datos` en una carpeta, y con el backend en otra, y compara el resultado, de modo que elegir esta opción no cambia un byte de lo que ya tiene el usuario. El groundwork sirve igual para el backend de base de datos que se deja para la fase 2: es lo único que habría que escribir ahí, porque todo lo demás (migración, rutas, recuento) ya habla con la interfaz. `scripts/almacen_config.gd` lee `user://almacenamiento.json` (`{modo, base, ruta_bd, esquema}`) y ese fichero **vive siempre en `user://`**, aunque los datos se muden: si se moviera con ellos, al cambiar de sitio dejaría de haber forma de saber cuál era el sitio viejo y los datos quedarían huérfanos. Se puede apuntar a otra carpeta con `-- --almacen=<ruta>` (útil para portable), `GESTORAO_BASE` o la propia UI; los tres mandan sobre el fichero, en ese orden. Preferencias suma la sección **Almacenamiento**: dónde está cada cosa, cuánto ocupa, y los botones **Cambiar carpeta…** (que copia todo ahí, verificado por recuento, y avisa de que se aplica al reiniciar) y **Abrir carpeta**. El cambio de carpeta **no** se aplica en caliente: los stores ya tienen sus rutas abiertas y cambiarlas a mitad de sesión es la forma fácil de partir un JSON. Una migración que pierde algo se marca como **fallida** con el detalle de qué sección no cuadra, en vez de dejar una copia «migrada» que parece buena; `migra_a()` solo lee el origen, así que un fallo a medias deja los originales intactos. Piezas nuevas: `scripts/almacen.gd`, `scripts/almacen_json.gd`, `scripts/almacen_config.gd`, `scripts/almacen_controller.gd` y las cuatro suites `tests/test_almacen_json.gd`, `tests/test_almacen_config.gd`, `tests/test_almacen_migracion.gd` y `tests/test_almacen_stores.gd`.

- **Instantánea diaria del catálogo** (`#60`): el gráfico del dashboard pasa a tener tres series. Al terminar un escaneo se guarda en `user://instantaneas.json` una fila por día con `{fecha, total, validos, caidos, sin_comprobar}` — el estado **completo** del catálogo, no solo lo que se movió ese día — y así el gráfico muestra por fin los enlaces **sin comprobar** como lo que son, en vez de dejar huecos. Un día es una foto, no un acumulado: comprobar tres veces el mismo día **reemplaza** la fila de ese día en lugar de sumarla, y un catálogo vacío no se fotografía (no pisaría la foto buena del día con un cero). La fila se recorta sola a la retención configurada (365 días por defecto, mínimo 30, máximo 3650). El gráfico apila **válidos / caídos / sin comprobar**, la leyenda suma el tercer color y el globo pasa a `texto_dia(dia)`, que da el total, el desglose, los cambios de estado del día y el delta contra la foto anterior (`+2 válidos, -1 caídos`, medido contra la última foto aunque en medio haya días sin comprobar). Los días en los que no hubo Instantánea llevan una marca fina en la base y el globo dice **Sin datos** en vez de fingir un cero; los cambios del historial de esos días siguen apareciendo en la serie y en el recuento de cambios. Sin ninguna Instantánea el gráfico conserva **exactamente** el comportamiento anterior (válidos y caídos sacados del historial) y lo dice con un aviso, de modo que actualizar la app no altera los datos ya exportados. La cabecera del CSV pasa a `Seccion;Clave;Comprobados;Activos;Rotos;Disponible;Total;SinComprobar;Foto`, y solo las filas de la serie llevan las tres columnas nuevas (el resto del CSV queda igual). Preferencias suma **Instantáneas diarias** (spinbox de días) y Utilidades suma **Purgar instantáneas antiguas…**, que borra lo que pase de la retención y dice cuántos se han ido. Piezas nuevas: `scripts/instantanea_store.gd` y la suite `tests/test_instantanea_store.gd`.
- **Actualizar la URL tras una redirección** (`#59`): el escaneo guarda la URL a la que acabó yendo cada enlace (`link_checker.terminado` pasa a cuatro argumentos y `estado_store` persiste `url_final` en el estado y en cada entrada del historial), y con ese dato la app distingue tres cosas: una redirección que solo normaliza (`http` a `https`, sin `www.`), que **no** se toca; una redirección **reubicable**, que se puede actualizar de un clic; y el resto, que solo se informa. Se considera reubicable cuando el destino está en otro host o cuando conserva el mismo nombre de archivo, y se descartan a propósito las páginas de servicio (`login`, `index`, `error`…) aunque la extensión coincida, porque actualizar a una portada dejaría el enlace apuntando a otra cosa. La fila de la lista y la tarjeta de la grilla muestran la marca «movido» con un tooltip que explica el cambio, el tooltip de la fila añade la línea `Redirige a: …`, el historial dice a dónde iba en cada comprobación y el menú contextual suma **Actualizar URL a la nueva**, habilitada solo cuando el destino sirve y con el destino en su tooltip. Al pedirla se confirma con el nombre del enlace y la URL nueva (`¿Actualizar «Foto» a https://…?`, o `¿Actualizar la URL de 3 enlaces a la nueva?` en bloque) y `catalogo_controller.actualizar_url()` cambia la URL **conservando nombre, categoría, etiquetas y captura**, traslada el estado a la clave nueva y deja la redirección pendiente resuelta; la barra informa de cuántas URLs se actualizaron. El dashboard suma el panel **Enlaces movidos** (enlace, host de origen, host de destino y fecha de comprobación) con el botón **Actualizar URLs** que lanza el mismo proceso en bloque, y su CSV/JSON incluyen el bloque `Reubicado;`. Todo el criterio vive en el módulo puro `scripts/redirecciones.gd` (`normalizada()`, `reubicable()`, `clasificar()`, `explicar()`, `destino_de()`, `reubicados_de()` y los textos), con la suite `tests/test_redirecciones.gd`.

- **Acciones en bloque** (`#58`): barra de selección que aparece en cuanto hay algo elegido, con contador (`1 seleccionado` / `3 seleccionados`), **Seleccionar todo lo que se ve**, **Comprobar seleccionados**, **Copiar URLs**, **Exportar selección**, **Eliminar seleccionados** y **Quitar selección**. El clic normal elige una sola fila y sigue abriendo el enlace como hasta ahora; con `Ctrl`/`Cmd` se alterna una fila sin abrirla y con `Mayús` se marca el rango desde la última elegida. La selección se identifica por la URL completa, así que sobrevive a los cambios de filtro, y se poda sola cuando un enlace deja de estar en el catálogo. Atajos: `Ctrl+A` selecciona lo visible, `Esc` quita la selección (si no hay ningún diálogo abierto), `Ctrl+C` copia las URLs una por línea, `Ctrl+Intro` comprueba solo las elegidas y `Mayús+Supr` las elimina con **una sola confirmación que dice cuántas son**. Las filas seleccionadas se marcan con un borde del color de acento (`tema_store.marcar_seleccion()`, reaplicado al cambiar de tema), y la marcada añade al tooltip la línea con los atajos. Exportar la selección abre el diálogo de informe proposing `seleccion.csv` y escribe solo esas filas. Piezas nuevas: `scripts/seleccion_controller.gd`, `scripts/informe_controller.gd` y las suites `tests/test_seleccion_controller.gd`, `tests/test_informe_controller.gd` y `tests/test_main_seleccion.gd`.

- **Resumen de cambios** (`#57`): ventana nueva (`scenes/Cambios.tscn` + `scripts/cambios.gd`) que responde a la pregunta «qué ha pasado desde que lo dejé». Al terminar un escaneo se compara el estado de cada enlace con el que había en la comprobación anterior (`scripts/cambios_store.gd`, `delta()`) y, si hay novedades, se abre sola con un contador por tipo (**nuevos caídos**, **recuperados**, **reubicados**, con forma singular y plural) y una tabla con enlace, fecha, salto de estado y detalle. Cada fila lleva el color de su tipo. Si el resultado fue un enlace nuevo que nace caído se cuenta como nuevo caído; un enlace que ya estaba caído igual no se vuelve a anunciar. Debajo se indica hasta qué fecha llega el historial, porque `estado_store` guarda 50 cambios por URL y el resumen no puede prometer más. Desde la ventana se **filtra la lista en caídos** o se abre el dashboard. Utilidades gana **Viendo cambios…** para volver a abrirla a mano. En la lista, las filas que han cambiado llevan una marca «cambió» con el color de su tipo y un tooltip que lo explica, y la marca desaparece al recomprobar el enlace o al empezar otra pasada. Si se cierra la app sin llegar a ver el resumen, los cambios se guardan y se muestran al abrir la siguiente vez; con la preferencia **comprobar al abrir** activada, el escaneo automático espera a que se cierre la ventana. Exportación a CSV (`cambios,fecha,nombre,tipo,antes,despues,mensaje,url`). Piezas nuevas: `scripts/cambios_store.gd`, `scripts/cambios_controller.gd` y las suites `tests/test_cambios_store.gd`, `tests/test_cambios_controller.gd`, `tests/test_cambios_ui.gd` y `tests/test_main_cambios.gd`.

- **Aceptar los certificados TLS no válidos** (`#56`): Preferencias → Escaneo suma un tercer interruptor, **Aceptar los certificados TLS no válidos**, desactivado por defecto. La comprobación es en dos pasos: primero valida el certificado como siempre y, solo si el handshake **falla de verdad**, repite la conexión con `TLSOptions.client_unsafe(null)`; así la revisión se mantiene intacta para los enlaces con buen certificado en vez de avisar de todo lo que sea `https`. Si esa segunda conexión responde, el enlace pasa a **válido con aviso** (`estado = "ok_tls"`, pintado con la clave de paleta `aviso`): sigue contando como disponible en el contador, en el dashboard y en el filtro «válido», no aparece entre los problemáticos y solo salta en la columna **Causa** y en el tooltip. Si tampoco responde se informa de **Sin conexión segura** y no se da por bueno. Con la opción desactivada se comporta como hasta ahora (caído, motivo `tls`). El diagnóstico (`info.txt`) registra `tls_aceptar_certificados` y `tls_aviso`, y el log de escaneo distingue `valido_tls` de `caido_tls`. Fixture TLS versionado en `tests/fixtures/` y suite `tests/test_link_checker_tls.gd`.

- **Reintentos y «sin comprobar»** (`#54`): Preferencias gana el bloque **Escaneo** con dos interruptores independientes y activos por defecto, **Reintentar los fallos transitorios (2 veces)** y **Marcar los fallos de red como «sin comprobar» en vez de «caído»**; la fila y el historial añaden el sufijo «(N intentos)» al detalle; y el informe CSV/HTML gana la columna **Causa** más un bloque **Resumen por causa** (`InformeStore.estado_texto()`, `causa_texto()` y `resumen_por_causa()`).

- **Internacionalización ES/EN** (`#30`): selector de idioma con banderas en Preferencias, CSV de traducciones (`locale/gestor_es_en.csv`), carga de traducciones al arrancar y `tr()` en toda la UI (textos de escaneo, dialogs, menús, cabeceras de columna e historial). Scanner de cadenas de UI (`scripts/extraer_cadenas.gd`) con test de cobertura (`test_locale.gd`).
- **Ordenación por columnas** (`#17`): cabeceras pulsables en la lista (fecha, nombre, imagen, estado) con criterio persistido en configuración y restauración al arrancar.
- **Capturas del catálogo**: las tres entradas de Twister-AO (cliente, códigos y servidor) usan ya la imagen `Twister-AO (Servidor).jpg`, y la captura de la liberación de Tierras Sagradas pasa a llamarse como su enlace (`Liberación Tierras Sagradas - v2.png`, entrada `Tierras Sagradas - v2`) para que el recurso siga al nombre del enlace.
- **Rediseño del dashboard de estadísticas** (`#49`): la ventana pasa de dos listas planas sobre un `ColorRect` a un panel con superficies `PanelContainer` y, de arriba abajo, una fila de tarjetas KPI (total, disponibles, caídos y sin comprobar, con barra de ratio), un bloque de disponibilidad con el porcentaje grande y su barra, el gráfico diario con rejilla, eje de valores, etiquetas de fecha, leyenda y globo al pasar el ratón, las tablas de categoría y de host con cabecera pulsable (orden por nombre, válidos, caídos, disponibilidad y fecha; segunda pulsación invierte el sentido), barra de disponibilidad por fila y doble clic para llevar ese filtro a la lista, y el bloque **Enlaces que más han caído** con veces, último código HTTP y fecha. Se añade el selector de rango (7/30/90 días o todo el histórico, por defecto todo), el estado vacío de catálogo (con botón **Comprobar enlaces**) y el aviso de catálogo todavía sin comprobar. El store gana `serie_diaria(dias)`, `top_caidos()` y `ultima_comprobacion()`, y el CSV/JSON exportados incluyen el bloque de enlaces problemáticos. El gráfico mantiene las dos series (válidos/caídos) porque el historial no guarda un contador diario de "sin comprobar"; los días sin comprobaciones no aparecen en la serie. Piezas nuevas `scenes/TarjetaKpi.tscn`, `scenes/FilaTabla.tscn` y suite propia `tests/test_dashboard_ui.gd`; `tema_store` expone `relleno()` y un `TooltipPanel` temático para el globo del gráfico.

### Cambiado

- **`FilaTabla` admite anchuras propias** (`#57`): `configurar_columnas(texto_nombre, columnas, color, color_columna, anchos, alineaciones)` deja fijar el ancho y la alineación de cada columna, que antes venían cableados en la escena y no cabían en la ventana de cambios (46, 46 y 58 px). `configurar()` no cambia, así que el dashboard sigue igual.
- **Tarjeta de la vista de grilla** (`#43`): altura mínima de 176 a 240 px, fuente de las cinco etiquetas a 10 y sin autowrap (con `clip_text`) para que la tarjeta mantenga un tamaño fijo en la grilla en vez de crecer con la longitud del texto.

### Rendimiento

- **Reverse-lookup de mensajes de estado cachado** (`#40`): mapa render→clave construido una vez por locale para los mensajes fijos y caché memoizada para los mensajes con `%d`; `_clave_de_mensaje()` ya no recorre todas las claves del CSV por fila y por tooltip en cada reconstrucción de la lista.

### Mantenimiento

- **Las escrituras ya no pasan por encima del destino** (`#63`): `config_store.gd` abría `config.json` en `WRITE` y escribía encima, así que un corte a mitad lo dejaba en cero — y con él se perdían **todos los ajustes del usuario de golpe**, sin forma de recuperarlos. `cola_store.gd` e `instantanea_store.gd` (`#60`) hacían `.tmp` y rename, pero `cola_store` quitaba el destino antes de renombrar, dejando un hueco en el que no había ni el fichero viejo ni el nuevo. Los cuatro stores usan ahora la misma escritura atómica, `AlmacenScript.escribir_json()`: `.tmp`, `.bak` y rename, con el `.bak` de la versión anterior siempre disponible. Una escritura a una ruta imposible devuelve `false` en vez de decir que ha guardado. El issue daba por hecho que ningún store era atómico: `estado_store.gd` y `gestor_datos.gd` ya lo eran desde antes, así que antes de «arreglar» nada había que mirar.
- **Un `enlaces.json` corrupto ya no ensucia la consola** (`#63`): `gestor_datos._parsear()` usaba `JSON.parse_string()`, que escribe el error del parser aunque el fichero esté corrupto y el llamante lo trate como un `null` normal. En el arranque eso era un `Parse JSON failed` para un usuario que no sabe leer un «Expected key». Ahora usa `JSON.new().parse()`, igual que el resto del proyecto.
- **La CI corre en Windows y arranca el binario exportado** (`#61`, parte 2 de 2): el job único de `ubuntu-latest` se parte en dos. `battery` es ahora una **matriz `ubuntu-latest` / `windows-latest`** — Windows es donde se desarrolla y desde donde se depura, y hasta ahora los paths, el separador `\` y `user://` no se ejercitaban nunca en el SO del usuario —, con `fail-fast: false` para que un SO roto no esconda al otro, y con los dos pasos de test en `shell: bash` (Git Bash en el runner de Windows, que es como se corre en local: con el shell por defecto el `.sh` no se ejecuta y el job pasaría sin correr nada). La descarga de Godot y de las plantillas sale a una **acción compuesta** (`.github/actions/godot`) porque iba a estar copiada en tres sitios, y expone la ruta del binario por `outputs.bin`, resuelta siempre en un paso aparte para que el consumidor no dependa de si la caché acertó o falló. `.godot/imported` y `.godot/uid_cache.bin` se cachean con clave `hashFiles('project.godot', 'Assets/**', 'data/**')`, que es justo la parte lenta: reimportar todos los assets en cada corrida.
- **`shell: bash` en todo paso que toca Godot** (`#61`): en `windows-latest` el shell por defecto de un step es `pwsh`, donde `"C:\...\godot.exe" --headless --path . --import` no es ni un comando válido (`ParserError: Unexpected token 'headless'`; en PowerShell hace falta el operador `&` delante) y `bash tests/run_x.sh` tampoco se ejecuta. El job se quedaba rojo antes de arrancar nada, con un mensaje que no señalaba el paso. Los tres pasos de la matriz y los tres del export llevan ya `shell: bash`; `test_empaquetado` añade una guarda que recorre `ci.yml` paso a paso (partiéndolos por su `- name:`, porque el cuerpo de un `run: |` va en líneas siguientes y ahí no aparece el nombre del script) y falla si alguno de los seis pasos que tocan Godot no lo declara.
- **La descarga de Godot para Windows era un 404 en silencio** (`#61`): el asset del release se llama `Godot_v4.7.2-stable_win64.exe.zip`, no `..._win64.zip`, y `curl -sSL` sin `-f` sale con código 0 ante un 404 y se guarda el «Not Found» de GitHub dentro del `.zip`. El fallo que se veía era `End-of-central-directory signature not found` de `unzip`, que no dice nada de la URL, y solo en el job de Windows (el de Linux usaba el nombre correcto y pasaba). Corregido el nombre y puesto `-f` en las tres descargas, de modo que una URL mal escrita falla en el `curl` diciendo la URL. `test_empaquetado` añade una guarda que exige `-f` en todos los `curl` de la acción.
- **Smoke test del binario exportado** (`#61`): hay fallos que solo existen dentro del pck y que ninguna suite ve, porque ellas corren con el proyecto abierto: un recurso o una escena que no entra en el export, un script que no compila en release, un `user://` que ha dejado de poder escribirse. El binario se arranca de verdad con `--headless -- --smoke`, y `--smoke` hace que `main.gd` ejecute `scripts/smoke.gd` y salga con **código 0 o 1**: comprueba que se puede escribir y releer en `user://`, que los recursos declarados cargan, que las diez escenas cargan e instancian y que los cinco stores con datos responden. `tests/run_smoke.sh` no se conforma con el código de salida, porque **Godot puede imprimir un `SCRIPT ERROR` y salir con 0**: además del código exige la marca `GestorAO smoke OK` y que no aparezca ni un `SCRIPT ERROR`, y distingue el timeout (124/137) de un fallo normal. Con dos comprobaciones reales como prueba de que funciona: la primera versión daba falsos positivos con `FileAccess.file_exists()`, que **miente dentro de un pck** (un recurso importado se guarda como `....png.remap` más su `.ctex`, no con su nombre) y con `icon.ico`, que no es un recurso de Godot sino algo que incrusta el exportador; el smoke usa `ResourceLoader.load()`, que es lo que de verdad responde «¿la app puede usar esto?».
- **El «sin comprobar» del gráfico ya no se inventa** (`#60`): el almacén diario es un store más (`scripts/instantanea_store.gd`, con `user://instantaneas.json`), no un campo más del estado de cada enlace: una Instantánea es un hecho del día, del catálogo entero, y por eso se recorta por antigüedad (`purgar()`) y se limpia entera (`limpiar()`), en lugar de crecer para siempre con el historial. `fila_de()` delega el recuento en `DashboardStore.resumen()`, así que la foto y las tarjetas del dashboard no pueden discrepar. `limite_ok()` es el único sitio donde se recortan los límites de la retención y `config_store` lo reutiliza para `instantaneas_dias`, de modo que el spinbox de Preferencias, la purga del menú y el recorte al guardar no pueden discrepar. `clave_de_dia()` se pasa a pública porque la tienda, la suite y el gráfico necesitan el mismo día que la serie; `_clave_dia()` queda como delegador. El texto del globo se extrae a `texto_dia()` para poder comprobarlo sin píxeles.
- **La serie diaria distingue «no había datos» de «no había nada»** (`#60`): antes una fila de la serie era solo el recuento de cambios de ese día, así que un día sin comprobaciones y un día con cero cambios eran lo mismo. Ahora cada fila lleva `instantanea`, `sin_datos`, `total`, `validos`, `caidos`, `sin_comprobar`, `cambios_validos`, `cambios_caidos`, `con_delta`, `delta_validos` y `delta_caidos`. La compatibilidad es explícita: si no hay ninguna Instantánea, `serie_diaria()` reproduce la serie anterior campo a campo (válidos y caídos desde el historial, `sin_comprobar` a 0, ninguna fila marcada como `sin_datos`) y `test_dashboard_store` lo fija con los mismos datos de siempre. `tr()` no es estática, así que `texto_dia()` es un método normal y la escala del eje (`_maximo()`) también, para poder comprobarlas sin depender de que `_draw()` se llegue a pintar en headless.
- **El criterio de redirección sale de `main.gd`** (`#59`): clasificar si una redirección es una normalización o un reubicado, redactar los textos (marca, tooltip, confirmación en singular y plural) y decidir qué enlaces son actualizables en bloque no es cableado de UI sino una decisión que hay que poder probar, así que vive en `scripts/redirecciones.gd` como módulo puro sin dependencias de escena, reutilizando `GestorCatalogo.clave_unica` para no reimplementar el criterio de clave. `main.gd` cablea la confirmación y delega. La captura se conserva porque `actualizar_url()` reaprovecha `editar()` con `assets_base` vacío, de modo que mover un enlace no borra su miniatura ni toca la carpeta de assets.
- **`url_final` se propaga con nombre explícito** (`#59`): `estado_store.guardar_estado()` suma un último argumento con valor por defecto (`""`), así que las llamadas existentes siguen siendo válidas; `_estados_iguales()` compara también el destino, de modo que cambiar solo la URL final cuenta como comprobación nueva en el historial en vez de duplicarse. `test_empaquetado` sube su techo de `main.gd` de 1600 a 1700 líneas y añade dos guardas nuevas (`_reubicar_extraido()` y `_url_final_propaga()`) que fallan si el criterio vuelve a `main.gd` o si `url_final` deja de viajar desde el checker hasta el estado. El techo es reversible: bajar a 1600 exige extraer el cableado, no la lógica.
- **La selección en bloque y el armado del informe salen de `main.gd`** (`#58`): la barra de selección,y con ella todo el álgebra de elegir filas (alternar, rango desde el ancla, seleccionar lo visible, podar lo que ya no está, intersectar con el catálogo para no exportar o borrar enlaces que ya no existen) y el emparejamiento de atajos, viven en `scripts/seleccion_controller.gd`; el armado de las filas del informe CSV/HTML, la detección de formato y el guardado salen de `scripts/informe_controller.gd`. `main.gd` solo cablea y traduce a UI. Los atajos se reconocen en `_unhandled_input` con `SeleccionControllerScript.atajo_de(event)`, un estático puro: **no se toca `project.godot`**, así que no hay mapa de entrada que mantener ni que rompa el Atajo de teclado de Windows. `test_empaquetado` vigila que ninguna de las dos piezas vuelva a `main.gd` y sube su techo de 1500 a 1600 líneas: cablear una barra nueva son ~85 líneas y elController ya se lleva la lógica, lo que se mide es el contenido.
- **`delta()` no reescribe los estados que recibe** (`#57`): al normalizar las claves, `_indices()` añadía el campo `url` **dentro** de los diccionarios de estado que le pasaban, así que la base de la comparación quedaba mutada después de la primera llamada y el segundo escaneo volvía a anunciar como «nuevo caído» un enlace que llevaba dos passes caído. Se corrige copiando el estado antes de anotarlo, y se cubre con una comprobación que llama a `delta()` y verifica que el diccionario de entrada sigue sin `url`.
- **El cálculo de cambios sale de `main.gd`** (`#57`): `main.gd` solo cablea; la comparación vive en `scripts/cambios_controller.gd` (registro, marcas por tipo de cambio, nombres por clave, pendientes en `user://cambios_pendientes.json`) y `scripts/cambios_store.gd` (delta, resumen, cobertura y CSV). `test_empaquetado` vigila que `main.gd` no vuelva a precalcular el delta y sube su techo de 1450 a 1500 líneas, porque cablear una ventana nueva son ~50 líneas inevitables: lo que se mide es que la lógica testeable no vuelva a entrar.
- **El alta, la edición y el borrado de enlaces salen de `main.gd`** (`#62`, parte 4 de 4): las tres funciones que materializan lo que devuelve el diálogo de alta/editación (`_on_enlace_guardado`, `_on_lote_guardado`, `_on_enlace_editado`) y el borrado de fila (`_ui_confirmar_borrado`) sumaban más de 200 líneas entre normalización de URLs, categorías y etiquetas, búsqueda de duplicados por clave canónica, recuento de repetidas e inválidas, renombrado de la clave de estado, copia de la captura y mensaje de la barra. Todo eso vive ahora en `scripts/catalogo_controller.gd`, que devuelve un diccionario con lo que la UI necesita (`ok`, `mensaje`, `reutilizada`, `img_anterior`, `renombrar`, `reabrir`) y deja en `main.gd` solo el pintado, el guardado en disco y el reabrir del diálogo. Junto con él salen los seis helpers de consulta (`urls_existentes`, `url_existente`, `buscar_entrada`, `indice_entrada`, `cambios_url_validos`, `es_captura_propia`/`borrar_captura_si_huerfana`), que en `main.gd` quedan como delegadores de una línea porque los tests de integración los usan. `normalizar_entrada()` se extrae para que la normalización sea la misma en el alta y en la edición. Nueva suite `tests/test_catalogo_controller.gd` (113 comprobaciones) que cubre altas, lotes, ediciones, renombrado de clave de estado, copias de imagen, borrados y borrado de capturas huérfanas **sin instanciar `Main`**; `extraer_cadenas.gd` incluye el controlador en `SCRIPTS_UI`, de modo que sus `tr()` también están cubiertos por `test_locale`. `main.gd` baja de 1546 a 1445 líneas y queda cerrado el issue.
- **El guardado de la configuración sale de `main.gd`** (`#62`, parte 3 de 4): persistir la configuración estaba repetido en cuatro funciones de `main.gd` que llamaban a `ConfigStore.guardar()` con veinte argumentos posicionales, y dos de ellas (`_persistir_orden()` y `_persistir_filtros()`) eran copia literal una de otra. El orden de esos argumentos era un contrato invisible: nadie lo comprobaba y nadie lo escribía dos veces igual. Ahora la lista de claves vive en `scripts/config_controller.gd` (`RefCounted`), una sola vez, y es la que se expande en los veinte posicionales; `main.gd` solo aporta el estado de la UI con `_config_desde_ui()` y llama a `guardar(cambios)`, que fusiona esos cambios sobre la configuración guardada y descarta claves desconocidas. Se elimina una de las dos funciones duplicadas (`_persistir_orden` / `_persistir_filtros` quedan en una sola, `_persistir_config()`). Nueva suite `tests/test_config_controller.gd` (30 comprobaciones) que verifica contra `ConfigStore.get_method_list()` que la lista de claves tiene tantos elementos como argumentos tiene `guardar()` y en el mismo orden, así que añadir un campo nuevo al store sin actualizar el controlador hace fallar el test. `test_empaquetado` vigila que la extracción no se revierta y que `main.gd` no vuelva a crecer. `main.gd` baja de 1573 a 1546 líneas.
- **La lógica de filas, filtros y orden sale de `main.gd`** (`#62`, parte 2 de 4): el pool de filas recicladas, la aplicación de filtros y el reordenado estaban en cinco funciones de `main.gd` que había que probar levantando la escena `Main` entera. Ahora viven en `scripts/lista_controller.gd` (`RefCounted`), que expone `configurar()` (criterios), `aplicar()` (visibilidad + orden en una pasada), `ordenar()`, `filas_visibles()` y el pool (`pool_tomar()`, `pool_devolver()`, `pool_vaciar()`, `cambiar_vista()`). Se corrigen de paso dos fragilidad sin cobertura: `clave_de_categoria()` ahora devuelve `""` en vez de reventar si el índice se sale de `CATEGORIAS` (`main.gd` indexaba a ciegas), y `aplicar()`, `ordenar()` y `filas_visibles()` toleran un contenedor nulo. Nueva suite `tests/test_lista_controller.gd` (47 comprobaciones) que ejercita los filtros de estado (incluido el triestado `valido` de #54), categoría, etiqueta, código y rango de días, los cuatro modos de orden, y el ciclo completo del pool **sin instanciar `Main`**. `main.gd` baja de 1615 a 1573 líneas.
- **El control del escaneo sale de `main.gd`** (`#62`, parte 1 de 4): la máquina de estados del escaneo estaba repartida en quince funciones de `main.gd` que mezclaban la cola con la barra de progreso, el diálogo de reanudación y los temporizadores del auto-escaneo, así que solo se podía probar instanciando la escena `Main` completa. Ahora vive en `scripts/scan_controller.gd` (`RefCounted`, sin una sola dependencia de la UI), con `preparar()` / `lanzar()` / `item_terminado()` y las señales `progreso(hechos, total)`, `item_actualizado(item)` y `terminado(total, caidos)`. `main.gd` se queda solo con traducirlas a etiquetas, colores y botones. Se extraen también las tres piezas de lógica que estaban incrustadas en el diálogo: el filtrado de la cola guardada contra el catálogo (`pendientes_validas()`, que reutiliza `clave_unica` y por tanto respeta el mismo criterio que el resto de la app), la reconstrucción de la cola al reanudar (`rearmar_pendientes()`) y la conversión del intervalo de minutos a segundos del Timer (`auto_espera()`). Nueva suite `tests/test_scan_controller.gd` (51 comprobaciones) que cubre paralelismo, tope por host, huecos reutilizados, items liberados a mitad de cola, triestado `valido` (cuenta como caído solo el `false`, no el `null` de #54), reanudación y auto-escaneo **sin instanciar `Main`**. `test_main_flujos` y `test_main_arranque` se quedan con lo que es integración de verdad. Batería 40/40.
- **La CI podía colgarse seis horas sin decir qué suite era** (`#61`, parte 1 de 2): una suite con un `Parse Error` no compila y por tanto nunca llega a llamar a `quit()`, así que Godot se quedaba vivo para siempre; sin red de seguridad eso no es un rojo, es el job entero quemando las 6 horas por defecto de GitHub Actions. Además `run_battery.sh` **abortaba en silencio**: el `salida="$(…)"` estaba bajo `set -e`, de modo que una suite con `exit != 0` mataba el script entero sin imprimir una sola línea de la que falló. Ahora cada suite va con `timeout -k 10` propio (`TIMEOUT_SUITE`, 180 s por defecto, `PATRON` para correr una sola), los códigos 124/137 se reportan como `COLGADA` en vez de confundirse con un fallo normal, cada invocación captura su estado con `|| estado=$?` y el resumen dice cuántas se colgaron. Nuevo `tests/run_estatico.sh`, que analiza los 77 `.gd` de `scripts/` y `tests/` con `--check-only` (un segundo por fichero, sin cargar escenas) y **sí** devuelve código distinto de 0 con un error de parseo, al contrario que `--import`, que escupe el ruido benigno ya conocido (`Parse Error: Native class TextFile` y el `Failed to load script` del `preload` del `.tscn` en `test_preferencias.gd`) y sale con `exit=0`. El job de CI lleva `timeout-minutes: 20` y ejecuta el paso estático entre el import y la batería. `test_empaquetado` sube el listón y comprueba que las protecciones siguen ahí. Batería 39/39.
- **Limpieza de residuos sin versionar** (`#41`): versionados el addon tercero `addons/godot_ai` (Godot AI v3.2.1, licencia MIT incluida) y el bloque `[autoload]/[editor_plugins]` de `project.godot` (el addon retira su autoload MCP de los builds exportados); `export_presets.cfg` regenerado por el editor 4.7 (la CI exporta con rutas explícitas); metadatos de Godot pendientes (16 `.uid`, 2 `.translation`, 7 `.import`). Eliminados localmente `data/data2.json` (no lo usa la app) y 2 `.import` huérfanos de `Assets/png`. Los planes ajenos sin commitear quedan en `.gitignore`.
- **Aislamiento de los tests de integración** (`#48`): `main.gd` y `agregar_enlace.gd` tenían la base de assets escrita a pelo (`res://Assets`), así que las cuatro suites que instancian `Main` (`test_main_arranque`, `test_main_catalogo`, `test_main_flujos`, `test_main_orden`) escribían y **borraban las capturas reales del catálogo** en cada batería, sin que ningún check fallara. Ahora la base es `ASSETS_BASE` (junto a `DATA_RES`/`DATA_USER`/`CONFIG_BASE`, y la ventana de alta la hereda), las suites la apuntan a `user://__test_*__/Assets` y `test_proyecto` falla si alguien vuelve a escribir `res://Assets` a pelo o si una suite instancia `Main` sin aislar la base. Nuevo `tests/ayuda.gd` con `borrar_arbol()` para la limpieza de las bases temporales.
- **Addon `godot_ai` actualizado de v3.2.1 a v4.2.3**: se vendoriza el árbol completo de la línea 4.x (clientes codebuddy/omp/zcode, handlers de comandos, navegación, shaders y mutaciones de ficheros, locks de cliente, verificador de releases y puente de migración v3→v4). Requisito Godot 4.7+ y autoload `_mcp_game_helper` sin cambios; solo afecta al editor y el `EditorExportPlugin` sigue retirando el autoload MCP de los builds exportados. Batería 33/33.

### Corregido

- **Comprobar no hacía nada en la vista de grilla** (`#58`): el botón **Comprobar** armaba la cola con `lista.get_children()`, así que en vista de grilla la lista estaba vacía y el escaneo se iba solo con el aviso *Nada que comprobar*: los enlaces de la grilla nunca se comprobaban desde ese botón. Ahora usa el contenedor que se está viendo (`_contenedor_activo()`) a través del nuevo `_scan_arrancar(items, todos)`, que es el mismo camino que usa comprobar la selección. Cubierto en `tests/test_main_seleccion.gd` incluyendo el caso con filtro de caídos activo.
- **La marca de cambio petaba en la vista de grilla** (`#58`): `list_item.marcar_cambio()` buscaba `%MarcaCambio` sin comprobar, y ese nodo solo existe en la escena de lista, no en la de grilla. Con un cambio pendiente sin ver, cada fila de la grilla lanzaba `Node not found` al pintarse. Ahora se resuelve con `get_node_or_null()` y se sale sin marcar donde no hay sitio para la marca; `test_empaquetado` vigila que no vuelva a buscarlo a saco.
- **Un borrado que no encontraba nada se contaba como borrado** (`#58`): `_ui_confirmar_borrado()` daba por buena cualquier respuesta del catálogo, y `eliminar()` devuelve `{"ok": false, ...}` —no un diccionario vacío— cuando la URL no está. El estado se marcaba como borrado y la captura se liberaba de todos modos. Ahora se comprueba `ok` antes de tocar nada. Era un fallo latente del refactor de `#62`,visible al generalizar el borrado a varias filas.
- **Cancelar el borrado dejaba la lista pendiente** (`#58`): al cancelar la confirmación de un borrado en bloque quedaban las URLs apuntadas, así que un `Enter` posterior sobre el mismo diálogo podía borrar una selección que el usuario ya había rechazado. Ahora `canceled` limpia la lista pendiente.
- **Eliminar un enlace borraba la captura que otro enlace estaba usando** (`#62`): al confirmar el borrado de una fila, `main.gd` quitaba la entrada del array y acto seguido `DirAccess.remove_absolute()` sobre su imagen, sin mirar si algún otro enlace la seguía usando. Como dos enlaces pueden compartir captura (p. ej. la misma captura de "no disponible" o una reutilizada), **eliminar uno de ellos dejaba al otro con la imagen rota** en la lista, en el dashboard y en el alta de una nueva versión. El borrado ahora pasa por el mismo `borrar_captura_si_huerfana()` que usa la edición, que solo borra el fichero cuando la ruta es de la base de assets, no es un archivo fijo del paquete y **ninguna entrada viva la referencia**. Cubierto en `tests/test_main_catalogo.gd` (eliminación real desde el menú de fila con captura compartida) y en `tests/test_catalogo_controller.gd`.
- **«No se añadió ningún enlace.» no se traducía nunca** (`#62`): la cadena del aviso de lote vacío era un literal sin `tr()`, así que en inglés salía en español. Ahora pasa por `tr()` y `locale/gestor_es_en.csv` tiene su clave; además `catalogo_controller.gd` se añade a `SCRIPTS_UI` de `extraer_cadenas.gd`, de modo que `test_locale` vigila también las cadenas nuevas del controlador (lo detectó y falló al añadirlo).
- **Editar la URL renombraba el estado antes de poder fallar** (`#62`): al cambiar la URL de un enlace, la clave de su estado se renombraba nada más empezar; si la captura no se podía procesar, la función se iba con un error dejando **el estado en la clave nueva y la entrada en la vieja**. Ahora el renombrado va después de la copia, justo antes de tocar la entrada.
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