# Spec: Categorías por enlace y filtro por categoría (#5)

**Fecha:** 2026-09-13
**Issue:** scorpio21/gestor-de-enlaces#5 — [Catálogo] Categorías o etiquetas por enlace y filtro por categoría

## Objetivo

Añadir un campo de categoría a cada enlace (`cliente`, `servidor`, `códigos fuente`, `parche`, `otro`) y permitir filtrar la lista por categoría además de por estado, sin romper los datos existentes (catálogo base y `user://enlaces.json`).

## Contexto (estado actual)

- Datos: **arrays JSON planos** de entradas `{"nombre","desc","url","img"}` (`main._cargar_datos`/`_guardar_datos`; `_leer_array(path)` parsea y valida `TYPE_ARRAY`, devuelve `[]` si no existe). `DATA_RES = res://data/data.json`, `DATA_USER = user://enlaces.json`. Sin clave `cat` en ninguna entrada.
- El "catálogo base" es `data/data.json` (58 entradas commiteadas). Su `desc` contiene pistas tipo `(Cliente)`, `(Servidor)`, `(Códigos Cliente)`, `(Servidor + Códigos)`, `(Full)`, `(Gráficos)`.
- Filtro actual en Main.tscn: OptionButton `%FiltroEstado` en `BarraAcciones` con ids 0=Todos, 1=Válidos, 2=Caídos / no existen, 3=Sin comprobar; `_aplicar_filtro()` (main.gd:540) alterna `hijo.visible` según `hijo.valido`. `_mostrar_lista()` (main.gd:380) crea los items vía `item.setup(nombre, desc, url, img)`.
- `list_item.gd`: `setup(nombre, descripcion, enlace, imagen := "")`; fila compuesta por `%Imagen`, `%Indicador`, `%Textos` (VBox: `%NombreLabel` + `%DescripcionLabel`), `%EstadoLabel`. Ya preloads `LinkCheckerScript`.
- `agregar_enlace.gd`: Window con modos individual/edición/varias. `_mostrar_individual(bool)` oculta/muestra `%EtiquetaNombre/%Nombre/%EtiquetaDesc/%Descripcion/%EtiquetaUrl/%Url/%VistaPrevia/%FilaImagen`. Emite `guardado(datos)`, `editado(datos, url_original)`, `lote_guardado(urls)`.
- `gestor_catalogo.gd`: `RefCounted` con `static funcs` (`dominio`, `separar`); ya preload en `main.gd` como `GestorCatalogoScript`. `main._on_lote_guardado` crea entradas `{"nombre": dominio, "desc": "", "url", "img": ""}`.
- `main._on_enlace_editado` (main.gd:300) sobreescribe nombre/desc/url/img de la entrada encontrada y persiste.
- Límite de la install: `_aplicar_filtro` no contempla nada más allá del estado.

## Enfoque

Extender el modelo de datos con la clave `cat` (una de 5 claves estables), migrar el catálogo base con un mapeo determinista por `desc`, normalizar toda entrada al cargar (ausente/desconocida → `"otro"`) y añadir un segundo desplegable de filtro combinado en AND con el de estado. La lógica de normalización/etiquetas vive en `gestor_catalogo.gd` (funciones estáticas testables); `main`, `list_item` y `agregar_enlace` solo consumen esas helpers.

## Alcance

Dentro:

- Clave `cat` en el modelo de datos con 5 valores: `"otro"`, `"cliente"`, `"servidor"`, `"codigos"`, `"parche"`.
- `gestor_catalogo.gd`: `const CATEGORIAS`, `normalizar_categoria(valor) -> String`, `categoria_display(cat) -> String`.
- Migración de `data/data.json` (58 entradas con `cat`) + normalización tolerante al cargar (datos de usuario antiguos sin `cat`).
- `%FiltroCategoria` (OptionButton) en Main.tscn, combinado en AND con `%FiltroEstado`.
- Etiqueta de categoría en cada fila (`%CategoriaLabel` en `ListItem`) y desplegable de categoría en `AgregarEnlace` (individual/editar; lote → `"otro"`).
- Pruebas unitarias e integradas; regresión de batería completa.

Fuera de alcance:

- Editar categoría desde la fila sin abrir el formulario; persistir el filtro elegido entre sesiones; multiselección de categorías; contadores "por categoría"; colores/chips por categoría (el label es gris plano).
- Cambiar el esquema de ficheros de preferencias ni el formato de `estados.json`.

## Comportamiento detallado

### `gestor_catalogo.gd` — helpers de categoría

Nuevos miembros estáticos:

- `const CATEGORIAS: Array = ["otro", "cliente", "servidor", "codigos", "parche"]` — fuente única de orden (los índices del desplegable y las claves almacenadas dependen de ella).
- `static func normalizar_categoria(valor: Variant) -> String`:
  - Normaliza la entrada: `String(valor).strip_edges().to_lower()` y sin acentos.
  - Mapa de equivalencias: `"otro"`→`"otro"`, `"cliente"`→`"cliente"`, `"servidor"`→`"servidor"`, `"codigos"`/`"codigos fuente"`/`"codigo fuente"`→`"codigos"`, `"parche"`/`"patch"`→`"parche"`.
  - Cualquier otro valor (incluido ausente/vacío/desconocido) → `"otro"`.
- `static func categoria_display(cat: String) -> String`: `"otro"`→`"Otro"`, `"cliente"`→`"Cliente"`, `"servidor"`→`"Servidor"`, `"codigos"`→`"Códigos fuente"`, `"parche"`→`"Parche"`; desconocida → `"Otro"`.

### `data/data.json` — migración del catálogo base

Regla determinista aplicada a las 58 entradas (sobre la `desc` doblegada a minúsculas y sin acentos):

1. contiene `"codigo"`/`"codigos"` → `"codigos"`
2. si no, contiene `"cliente"` y `"servidor"` → `"servidor"` (paquetes completos servidor+cliente)
3. si no, contiene `"cliente"` → `"cliente"`
4. si no, contiene `"servidor"` → `"servidor"`
5. si no, contiene `"parche"`/`"patch"` → `"parche"`
6. si no → `"otro"` (p. ej. `(Full)`, `(Gráficos)`)

Cada entrada gana `"cat": "<clave>"`. **No se tocan** `data/data.json.bak` ni `data/data2.json`.

### `main.gd` — carga tolerante y persistencia

- Nuevo `_normalizar_categorias() -> void`: recorre `_entradas`; para cada entrada `Dictionary` fija `entrada["cat"] = GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))`. Llamado al final de `_cargar_datos()`. Así `user://enlaces.json` viejo (sin `cat`) queda en memoria con `"otro"` y se persiste con `cat` en la siguiente escritura.
- `_on_enlace_guardado`: antes de `_entradas.append(datos)`, defensivo `datos["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", "otro"))`.
- `_on_lote_guardado`: cada entrada nueva incluye `"cat": "otro"`.
- `_on_enlace_editado`: tras localizar la entrada, `entrada["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", entrada.get("cat", "otro")))`.

### `main.gd` + Main.tscn — filtro combinado

- Nuevo OptionButton `%FiltroCategoria` (unique_name_in_owner) en `BarraAcciones`, tras `%FiltroEstado`. En `_ready`: construir items — `"Todas"` con id 0 y después las 5 categorías (id = índice+1, texto = `categoria_display`) —, `select(0)` y `item_selected` → `_aplicar_filtro`.
- `@onready var filtro_cat: OptionButton = %FiltroCategoria`.
- `_mostrar_lista`: llama `item.setup(nombre, desc, url, img, GestorCatalogoScript.normalizar_categoria(entrada.get("cat", "")))` (5º arg).
- `_aplicar_filtro()`: además del modo de estado, `var cat_id := filtro_cat.get_selected_id()`; si `cat_id > 0`, `clave_cat = GestorCatalogoScript.CATEGORIAS[cat_id - 1]`. `hijo.visible = visible_estado and (cat_id == 0 or hijo.categoria == clave_cat)`.

### `list_item.gd` + ListItem.tscn — label y campo

- Nuevo Label `%CategoriaLabel` en `Textos` bajo `%DescripcionLabel`: fuente 13, color `Color(0.75, 0.75, 0.75, 1)`, `mouse_filter = 2`, siempre visible.
- Nuevo miembro `var categoria: String = "otro"` y preload `GestorCatalogoScript`.
- `setup(..., categoria := "")` (parámetro opcional final, no rompe llamadas/tests existentes): `categoria = GestorCatalogoScript.normalizar_categoria(categoria)` y `%CategoriaLabel.text = GestorCatalogoScript.categoria_display(categoria)`.

### `agregar_enlace.gd` + AgregarEnlace.tscn — desplegable

- Nuevos nodos `%EtiquetaCategoria` (Label) y `%Categoria` (OptionButton) en la sección individual, junto al resto de `%Etiqueta*`/campos existentes.
- `_ready`/construcción: items de `%Categoria` en orden `CATEGORIAS` con `categoria_display`; `select(0)` por defecto (`"otro"`, que ocupa el índice 0 de `CATEGORIAS`).
- `_mostrar_individual(individual)`: añade `%EtiquetaCategoria.visible = individual` y `%Categoria.visible = individual` (en modo "varias" y edición se comporta como el resto de la sección individual — en edición `abrir_edicion` llama `_mostrar_individual(true)`).
- `abrir()`: `%Categoria.select(0)` (reset a `"otro"`, índice 0 en `CATEGORIAS`).
- `abrir_edicion(datos, ...)`: `%Categoria.select(GestorCatalogoScript.CATEGORIAS.find(GestorCatalogoScript.normalizar_categoria(datos.get("cat", ""))))` (find nunca devuelve -1: normalizar garantiza clave válida).
- `_on_guardar` (rama individual/editar): `var cat_clave := GestorCatalogoScript.CATEGORIAS[%Categoria.get_selected_index()]`; `datos["cat"] = cat_clave`. Lote queda intacto (emite URLs; `main` añade `"otro"`).
- Preload `GestorCatalogoScript` en `agregar_enlace.gd`.

## Errores y casos borde

| Caso | Resultado |
|---|---|
| Entrada de catálogo base con desc que menciona "códigos" (p. ej. `(Códigos Cliente)`, `(Servidor + Códigos)`) | `cat = "codigos"` (regla 1, máxima precedencia). |
| Entrada `(Servidor + Cliente)` | `cat = "servidor"` (regla 2). |
| Entrada `(Cliente)`, `(Servidor)` | `cliente` / `servidor` respectivamente. |
| Entrada `(Full)` / `(Gráficos)` / sin pista | `otro`. |
| `user://enlaces.json` viejo sin `cat` | Se normaliza a `"otro"` en memoria al cargar; se persiste con `cat`. |
| Valor `cat` desconocido o vacío (p. ej. editado a mano) | `normalizar_categoria` → `"otro"`; filtro y etiqueta coherentes. |
| Valor con acentos/etiqueta (`"Códigos fuente"`, `"Patch"`) | `normalizar_categoria` los lleva a su clave (`"codigos"`, `"parche"`). |
| Lote ("varias"): no hay desplegable visible | Cada enlace se crea con `"otro"`. |
| Filtro categoría en "Todas" (id 0) | No filtra por categoría; el estado sigue aplicando. |
| Filtro categoría seleccionada + estado | Ambos en AND; fila invisible si falla cualquiera. |
| `%FiltroCategoria` de una instalación vieja | Se construye desde `CATEGORIAS` en `_ready`; sin estado persistido. |

## Pruebas

### `tests/test_gestor_catalogo.gd` (13 → 21 checks) — categorías

1. `normalizar_categoria("")` → `"otro"`.
2. `normalizar_categoria("cliente")` → `"cliente"`.
3. `normalizar_categoria("Códigos fuente")` → `"codigos"` (normaliza etiqueta con acentos a clave).
4. `normalizar_categoria("patch")` → `"parche"`.
5. `normalizar_categoria("desconocida")` → `"otro"`.
6. `CATEGORIAS` guarda las 5 claves en orden `["otro","cliente","servidor","codigos","parche"]`.
7. `categoria_display("codigos")` → `"Códigos fuente"`.
8. `categoria_display("cliente")` → `"Cliente"` y `categoria_display("")` → `"Otro"`.

### `tests/test_list_item.gd` (17 → 21 checks) — label de categoría

- Item con `setup(..., "cliente")` → `%CategoriaLabel.text == "Cliente"` y campo `categoria == "cliente"`.
- Item con `setup(..., "codigos")` → label `"Códigos fuente"`.
- Item con `setup(..., "")` (sin categoría) → label `"Otro"` y `categoria == "otro"`.
- Item con `setup(..., "rara")` → label `"Otro"` (desconocida).

### `tests/test_agregar_enlace.gd` (19 → 24 checks) — desplegable

- Alta individual (default) → `emitido.get("cat") == "otro"`.
- Alta individual cambiando `%Categoria` a "Cliente" (índice 1) → `emitido.get("cat") == "cliente"`.
- Modo "varias" → `%Categoria.visible == false` (y la etiqueta idem).
- `abrir_edicion` con `{"cat": "servidor", ...}` → `%Categoria` seleccionado en el índice de `"servidor"` en `CATEGORIAS`; al guardar `emitido.get("cat") == "servidor"`.
- `abrir_edicion` sin `cat` → `%Categoria` en índice de `"otro"`; al guardar `emitido.get("cat") == "otro"`.

### `tests/test_main_barra.gd` (53 → 59 checks) — filtro y normalización

Nuevo bloque «Catálogo: categorías», con `main_script._persistir = false`, sembrando `_entradas` y refrescando vista (helpers existentes):

1. `%FiltroCategoria` tiene 6 items: `"Todas"` en 0 y las 5 etiquetas en orden de `CATEGORIAS`.
2. Filtro estado=Válidos + cat=Servidor → solo la fila del servidor válido es visible (oculta cliente válido y servidor caído).
3. Filtro estado=Válidos + cat="Todas" (id 0) → se respeta el estado pero no filtra por categoría.
4. `_on_lote_guardado(["https://nueva.com"])` → la entrada nueva queda con `"cat": "otro"`.
5. `_normalizar_categorias()` sobre `_entradas` sembradas con entrada sin `cat` → `"otro"`; con `"cliente"` → se conserva.
6. Entrada con `"cat": "raro"` → `_normalizar_categorias()` la deja en `"otro"`.

Regresión: batería completa (10 suites) con `TESTS OK`. `data/data.json.bak` y `data/data2.json` permanecen intactos.

## Notas

- Las claves estables en JSON (`"codigos"` sin acento) evitan problemas de codificación; la etiqueta visible se deriva siempre con `categoria_display`.
- `list_item.gd` y `agregar_enlace.gd` preload `gestor_catalogo.gd` (mismo patrón que el preload existente de `LinkCheckerScript` en la fila).
- El desplegable de edición no necesita un caso "sin categoría" distinto de "Otro".