# Categorías por enlace y filtro por categoría Implementation Plan (#5)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir el campo `cat` (5 categorías) a cada enlace, migrar el catálogo base, y filtrar la lista por categoría y estado.

**Architecture:** La lógica de categorías (claves, normalización, etiquetas) vive en `gestor_catalogo.gd` como helpers estáticos: única fuente de orden para desplegables. `main.gd` normaliza al cargar (ausente → `"otro"`), construye un segundo OptionButton `%FiltroCategoria` y combina estado+categoría en AND en `_aplicar_filtro()`. `list_item.gd` muestra la etiqueta y expone el campo `categoria`. `agregar_enlace.gd` ofrece el desplegable en individual/editar; el lote crea `"otro"`.

**Tech Stack:** Godot 4 GDScript (headless), JSON plano, tests `SceneTree` + `_check`.

## Global Constraints

- Sin `class_name` nuevo; preloads estilo `const X := preload("...")` (patrón ya usado en `main.gd`/`list_item.gd`).
- Scripts de producción **sin comentarios**; UI en español.
- Indentación con tabs (el repo usa tabs en `.gd` y `.tscn`).
- Si Godot reclama "Cannot infer the type", tipar explícito.
- No tocar `data/data.json.bak`, `data/data2.json` ni `docs/superpowers/plans/2026-09-05-captura-enlaces.md`.
- Orden de `CATEGORIAS` fijo: `["otro", "cliente", "servidor", "codigos", "parche"]` (índices de desplegables dependen de él).
- Comando de test headless habitual del proyecto:
  `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/<archivo>.gd`
- Batería final: las 10 suites `tests/*.gd` deben acabar con `TESTS OK`.

**Esquema de datos:** cada entrada `{"nombre","desc","url","img"}` (una `cat` extra). Claves: `"otro"`, `"cliente"`, `"servidor"`, `"codigos"`, `"parche"`. Etiquetas: `"Otro"`, `"Cliente"`, `"Servidor"`, `"Códigos fuente"`, `"Parche"`.

---
### Task 1: Helpers de categoría (gestor_catalogo.gd)

**Files:**
- Modify: `scripts/gestor_catalogo.gd`
- Test: `tests/test_gestor_catalogo.gd` (13 → 21 checks)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `CATEGORIAS` (const Array) = `["otro", "cliente", "servidor", "codigos", "parche"]`
  - `static func normalizar_categoria(valor: Variant) -> String`
  - `static func categoria_display(cat: String) -> String`

- [ ] **Step 1: Write the failing tests**

In `tests/test_gestor_catalogo.gd`, insert before `if _fallos == 0:` (line 31):

```gdscript
	# Categorías
	_check(GestorCatalogo.CATEGORIAS == ["otro", "cliente", "servidor", "codigos", "parche"], "CATEGORIAS tiene las 5 claves en orden")
	_check(GestorCatalogo.normalizar_categoria("") == "otro", "normalizar categoría vacía a otro")
	_check(GestorCatalogo.normalizar_categoria("cliente") == "cliente", "normalizar conserva clave válida")
	_check(GestorCatalogo.normalizar_categoria("Códigos fuente") == "codigos", "normalizar etiqueta con acentos a clave")
	_check(GestorCatalogo.normalizar_categoria("patch") == "parche", "normalizar patch a parche")
	_check(GestorCatalogo.normalizar_categoria("desconocida") == "otro", "normalizar valor desconocido a otro")
	_check(GestorCatalogo.categoria_display("codigos") == "Códigos fuente", "display de codigos")
	_check(GestorCatalogo.categoria_display("cliente") == "Cliente" and GestorCatalogo.categoria_display("") == "Otro", "display de cliente y de desconocida")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_catalogo.gd`
Expected: FALLOs (no existe `CATEGORIAS`/`normalizar_categoria`/`categoria_display`).

- [ ] **Step 3: Write minimal implementation**

Append to `scripts/gestor_catalogo.gd` (tras `separar`):

```gdscript
const CATEGORIAS := ["otro", "cliente", "servidor", "codigos", "parche"]


static func normalizar_categoria(valor: Variant) -> String:
	var texto: String = String(valor).strip_edges().to_lower()
	var limpio: String = texto.replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n")
	var equivalencias := {
		"otro": "otro",
		"cliente": "cliente",
		"servidor": "servidor",
		"codigos": "codigos",
		"codigo fuente": "codigos",
		"codigos fuente": "codigos",
		"parche": "parche",
		"patch": "parche",
	}
	return equivalencias.get(limpio, "otro")


static func categoria_display(cat: String) -> String:
	var etiquetas := {
		"otro": "Otro",
		"cliente": "Cliente",
		"servidor": "Servidor",
		"codigos": "Códigos fuente",
		"parche": "Parche",
	}
	return etiquetas.get(normalizar_categoria(cat), "Otro")
```

- [ ] **Step 4: Run test to verify it passes**

Run: same command as Step 2
Expected: `TESTS OK` (21 checks).

- [ ] **Step 5: Commit**

```bash
git add scripts/gestor_catalogo.gd tests/test_gestor_catalogo.gd
git commit -m "feat: helpers de categoría en gestor_catalogo (#5)"
```

---
### Task 2: Normalización de cat en main + migración de data.json

**Files:**
- Modify: `scripts/main.gd` — `_cargar_datos()` (llamar a `_normalizar_categorias()` al final), nueva `_normalizar_categorias()`, `_on_enlace_guardado` (línea 201), `_on_lote_guardado` (línea 239), `_on_enlace_editado` (línea 334)
- Modify: `data/data.json` (añadir `"cat"` a las 58 entradas)
- Test: `tests/test_main_barra.gd` (53 → 56 checks)

**Interfaces:**
- Consumes: `GestorCatalogoScript.normalizar_categoria` (Task 1).
- Produces (para Task 4/5): tras esta task, toda entrada en `_entradas` tiene `cat` normalizada; `_on_lote_guardado` crea entradas con `"cat": "otro"`.

- [ ] **Step 1: Write the failing tests**

En `tests/test_main_barra.gd`, insertar antes de `_cerrar()` (final de `_arrancar`, línea 222), como bloque «Catálogo: categorías — persistencia y normalización»:

```gdscript
	# Catálogo: categorías (persistencia y normalización)
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_lote_guardado(["https://nueva.test"])
	_check(main_script._entradas[1].get("cat") == "otro", "el lote crea los enlaces con cat otro")
	main_script._entradas = [
		{"nombre": "A", "url": "https://a.test"},
		{"nombre": "B", "url": "https://b.test", "cat": "cliente"},
		{"nombre": "C", "url": "https://c.test", "cat": "raro"},
	]
	main_script._normalizar_categorias()
	_check(main_script._entradas[0].get("cat") == "otro" and main_script._entradas[1].get("cat") == "cliente", "normalizar fija otro a ausente y conserva la clave válida")
	_check(main_script._entradas[2].get("cat") == "otro", "normalizar lleva el valor desconocido a otro")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `... -s tests/test_main_barra.gd`
Expected: FALLOs (no existe `_normalizar_categorias`; el lote no guarda `cat`).

- [ ] **Step 3: Write minimal implementation**

En `scripts/main.gd`:

1. Nueva función (añadir tras `_cargar_datos`):

```gdscript
func _normalizar_categorias() -> void:
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			entrada["cat"] = GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))
```

2. En `_cargar_datos()`, al final (tras el bloque `_entradas = _entradas.filter(...)`), añadir `_normalizar_categorias()`.

3. En `_on_enlace_guardado`, justo antes de `_entradas.append(datos)`:

```gdscript
	datos["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", "otro"))
```

4. En `_on_lote_guardado`, el Dictionary de cada nueva entrada (línea 240) gana la clave `"cat": "otro",`:

```gdscript
		_entradas.append({
			"nombre": GestorCatalogoScript.dominio(u),
			"desc": "",
			"url": u,
			"img": "",
			"cat": "otro",
		})
```

5. En `_on_enlace_editado`, junto al resto de asignaciones (`entrada["img"] = destino`), añadir:

```gdscript
	entrada["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", entrada.get("cat", "otro")))
```

6. **Migrar `data/data.json`**: a cada una de las 58 entradas, añadir la clave `"cat"` según esta tabla (coincidir por `url`):

```
codigos  http://www.4shared.com/file/173944718/b7d1687e/InfernusAO_by_ZardoK.html
servidor  http://www.4shared.com/file/134947833/4a310bd3/_2__AO_DX8.html
codigos  http://www.4shared.com/file/210545656/34b3628b/LibearcionArmionsAO.html
servidor  http://www.4shared.com/account/file/33950056/956610c3/2006-06-30-IAO-Server-12.html
codigos  http://www.4shared.com/file/191825495/7d4a62e9/Tierras_Del_SurAO_Codigos_Del_.html
codigos  http://www.4shared.com/file/135450151/47eaff95/Neithan.html
cliente  http://www.4shared.com/file/135460955/93410e4/Neithan_Ao.html
codigos  http://www.4shared.com/file/191775782/c1c545f7/Black_And_White_Codigos_Del_Cl.html
servidor  http://www.4shared.com/file/100298961/687ef359/fenixao-Cliente-src.html
cliente  http://rapidshare.com/files/317156901/Tiempos_Ao_Cliente_Completo.rar.html
codigos  http://rapidshare.com/files/317148654/Codigos_del_Cliente_de_Twister-Ao.rar.html
otro  http://www.4shared.com/file/134979259/5656cd7e/Winter-AO_Liberado.html
cliente  http://www.4shared.com/file/120013045/ba6804fb/2009-07-22-Toxik-AO-Cliente-mod-IAO-_Mathyaas_-_FULLsrc_.html
codigos  http://www.4shared.com/file/120015505/fda45cc8/2009-07-22-Toxik-AO-Servidor-mod-IAO-_Mathyaas_-_FULLsrc_.html
codigos  http://www.4shared.com/file/191904178/92931691/World_Of_Warrios_AO_Codigos_De.html
codigos  http://www.4shared.com/file/191893719/ecd8745e/AODrag_Codigos_Del_Cliente__Co.html
codigos  http://www.4shared.com/file/191909212/d4303e8d/MindAO_Codigos_Del_Cliente__Co.html
codigos  http://www.filefront.com/14756653/Zeus-AO-Completo-Codigos--Server--Instalador-Del-Cliente.rar
servidor  http://www.4shared.com/account/file/33928363/bbf3fd29/2001-09-30-Servidor-AOv0670.html
servidor  http://www.4shared.com/account/file/33928331/288a6840/2001-07-30-Servidor-AOv0673.html
servidor  http://www.4shared.com/account/file/33934272/a39b00c1/2001-10-11-Servidor-AOv070.html
servidor  http://www.4shared.com/account/file/33928314/6ad6fe4d/2001-06-19-Servidor-AOv0716.html
servidor  http://www.4shared.com/account/file/33928498/aef62eeb/2001-11-19-Servidor-AOv0753.html
servidor  http://www.4shared.com/account/file/33928592/4fe1adc2/2002-05-18-Servidor-AOv090.html
servidor  http://www.4shared.com/account/file/33928693/3aa0230d/2002-06-13-Servidor-AOv092.html
servidor  http://www.4shared.com/account/file/33828507/251531a1/2002-07-24-Servidor-AOv094.html
servidor  http://www.4shared.com/account/file/34017607/1164599d/2002-07-24-Servidor-AOv095.html
servidor  http://www.4shared.com/account/file/34016479/2a55156/2003-09-06-ServidorArgentum099z0806-src.html
servidor  http://www.4shared.com/account/file/33929171/f7de1e4f/2006-05-11-AOServer-srcres-0115.html
servidor  http://www.4shared.com/account/file/33929289/7cdb34eb/2007-05-14-AOServerSrc-012.html
servidor  http://www.4shared.com/account/file/34450831/2a725e0e/2005-08-08-ServidorAOReady-02-2.html
servidor  http://www.4shared.com/account/file/34452020/e074c6ea/2005-10-28-ServidorAOReady-04.html
servidor  http://www.4shared.com/account/file/34453290/b8b8ac2a/2006-02-09-ServidorAOReady-05-scr.html
cliente  http://sourceforge.net/projects/morgoao/files/Argentum%20Online/0.12.2/InstaladorArgentumOnline0.12.2.exe/download
codigos  http://www.4shared.com/file/144907792/33c03b2b/Bow_AO_122_By_Hardoz.html
otro  http://www.4shared.com/file/145836177/4b935b3c/Graphics.html
codigos  http://www.4shared.com/file/209866325/69e9cd00/Maniac-AO.html
codigos  http://www.4shared.com/file/92581360/55372cbf/Codigos_del_Servidor_y_Cliente_FighAO.html
cliente  http://www.megaupload.com/?d=IF6JOSJX
codigos  http://www.4shared.com/file/191156575/65910766/SummerAO_Codigos_Del_Cliente__.html
codigos  http://www.4shared.com/file/195385736/c8d2a9f1/DevastAO_Codigos_Del_Cliente__.html
codigos  http://www.4shared.com/file/191825641/cc0d0cd3/AOYind_Codigos_Del_Cliente__Co.html
codigos  http://www.4shared.com/file/191869149/78cf8b1c/GeoAO_Codigos_Del_Cliente__Cod.html
codigos  http://www.4shared.com/file/189163440/b02f0e06/Vicious_10_Codigos_Del_Cliente.html
codigos  http://www.4shared.com/file/189160488/f466d6/Vicious_20_Codigos_Del_Cliente.htm
codigos  http://www.4shared.com/file/191852091/52d9ea85/AOSpain_Codigos_Del_Servidor.html
codigos  http://www.4shared.com/file/191845202/b921c511/MagmaAO_Codigos_Del_Servidor.htmll
otro  http://www.4shared.com/file/134958504/92a36706/Dixit_AO.html
otro  http://www.4shared.com/file/134960768/4cdf0afa/EmpiresAo.html
codigos  http://www.4shared.com/file/134970954/59ba11a8/Rider_AO.html
otro  http://www.megaupload.com/?d=3K166CGB
codigos  http://www.megaupload.com/?d=4XXO5JJA
servidor  http://www.4shared.com/file/78592425/da51c093/Cliente-Servidor.html
codigos  http://www.4shared.com/file/134955200/62eb6d47/Destiny.html
servidor  http://rapidshare.com/files/317140651/Servidor_Twister-AO.rar.html
servidor  http://www.4shared.com/account/file/33935541/ac4c7358/2004-08-03-ServidorHiperAo099z-src.html
```

Formato: `"cat": "<clave>",` tras `"img": ...` en cada entrada (mismo estilo de tabulación que el resto del fichero).

- [ ] **Step 4: Run test to verify it passes**

Run: `... -s tests/test_main_barra.gd`
Expected: `TESTS OK` (56 checks).

Verificar además la migración del JSON:

```powershell
$j = Get-Content -Raw data/data.json | ConvertFrom-Json
$j.Count
($j | Where-Object { -not $_.cat }).Count
($j | Where-Object { $_.cat -notin @('otro','cliente','servidor','codigos','parche') }).Count
```
Expected: `58`, `0`, `0`.

- [ ] **Step 5: Commit**

```bash
git add scripts/main.gd data/data.json tests/test_main_barra.gd
git commit -m "feat: cat en persistencia y migración del catálogo base (#5)"
```

---
### Task 3: Etiqueta de categoría en las filas (ListItem)

**Files:**
- Modify: `scripts/list_item.gd` — preload + campo + `setup(...)` + label
- Modify: `scenes/ListItem.tscn` — `%CategoriaLabel`
- Test: `tests/test_list_item.gd` (17 → 21 checks)

**Interfaces:**
- Consumes: `GestorCatalogoScript.normalizar_categoria`, `categoria_display` (Task 1).
- Produces (para Task 5): `setup(nombre: String, descripcion: String, enlace: String, imagen := "", categoria := "") -> void`, campo `var categoria: String` y nodo `%CategoriaLabel`.

- [ ] **Step 1: Write the failing tests**

En `tests/test_list_item.gd`, insertar antes de `if _fallos == 0:` (línea 100):

```gdscript
	var cat_cliente := _crear_item()
	cat_cliente.setup("Nom", "Desc", "https://ejemplo.com/cat1", "", "cliente")
	var cat_codigos := _crear_item()
	cat_codigos.setup("Nom", "Desc", "https://ejemplo.com/cat2", "", "codigos")
	var cat_vacia := _crear_item()
	cat_vacia.setup("Nom", "Desc", "https://ejemplo.com/cat3", "", "")
	var cat_rara := _crear_item()
	cat_rara.setup("Nom", "Desc", "https://ejemplo.com/cat4", "", "rara")
	root.add_child(cat_cliente)
	root.add_child(cat_codigos)
	root.add_child(cat_vacia)
	root.add_child(cat_rara)
	await process_frame
	_check(cat_cliente.get_node("%CategoriaLabel").text == "Cliente" and cat_cliente.categoria == "cliente", "la fila muestra y guarda la categoría cliente")
	_check(cat_codigos.get_node("%CategoriaLabel").text == "Códigos fuente", "la fila muestra la etiqueta de códigos fuente")
	_check(cat_vacia.get_node("%CategoriaLabel").text == "Otro" and cat_vacia.categoria == "otro", "sin categoría la fila normaliza y muestra Otro")
	_check(cat_rara.get_node("%CategoriaLabel").text == "Otro", "categoría desconocida muestra Otro")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `... -s tests/test_list_item.gd`
Expected: FALLOs / error (no existe `%CategoriaLabel`; `setup` no acepta el 5º argumento).

- [ ] **Step 3: Write minimal implementation**

En `scenes/ListItem.tscn`, insertar entre el nodo `DescripcionLabel` y el nodo `EstadoLabel`:

```
[node name="CategoriaLabel" type="Label" parent="Margen/Fila/Textos"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
theme_override_colors/font_color = Color(0.75, 0.75, 0.75, 1)
theme_override_font_sizes/font_size = 13
text = "Otro"
```

En `scripts/list_item.gd`:

1. Añadir preload junto al de `LinkCheckerScript`:

```gdscript
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
```

2. Añadir campo junto a `var valido: Variant = null`:

```gdscript
var categoria: String = "otro"
```

3. Cambiar la firma de `setup` (línea 33):

```gdscript
func setup(nombre: String, descripcion: String, enlace: String, imagen := "", categoria := "") -> void:
```

Y dentro de `setup`, tras `_pintar_estado(...)`:

```gdscript
	self.categoria = GestorCatalogoScript.normalizar_categoria(categoria)
	%CategoriaLabel.text = GestorCatalogoScript.categoria_display(self.categoria)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `... -s tests/test_list_item.gd`
Expected: `TESTS OK` (21 checks).

- [ ] **Step 5: Commit**

```bash
git add scripts/list_item.gd scenes/ListItem.tscn tests/test_list_item.gd
git commit -m "feat: etiqueta de categoría en las filas (#5)"
```

---
### Task 4: Desplegable de categoría en AgregarEnlace

**Files:**
- Modify: `scripts/agregar_enlace.gd` — preload, población de items, `_mostrar_individual`, `abrir`, `abrir_edicion`, `_on_guardar`
- Modify: `scenes/AgregarEnlace.tscn` — `%EtiquetaCategoria` + `%Categoria` (+ tamaño de ventana)
- Test: `tests/test_agregar_enlace.gd` (19 → 24 checks)

**Interfaces:**
- Consumes: `GestorCatalogoScript.CATEGORIAS`, `normalizar_categoria`, `categoria_display` (Task 1).
- Produces (para Task 5): `guardado(datos)`/`editado(datos,...)` con `datos["cat"]` ya normalizado; `%Categoria` seleccionado según el enlace al editar; `select(0)` = `"otro"`.

- [ ] **Step 1: Write the failing tests**

En `tests/test_agregar_enlace.gd`, insertar antes de `if _fallos == 0:` (línea 91):

```gdscript
	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Nombre").text = "Con cat"
	dialogo.get_node("%Url").text = "https://cat.test"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("cat") == "otro", "alta individual fija cat otro por defecto")

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Categoria").select(1)
	dialogo.get_node("%Nombre").text = "Cliente"
	dialogo.get_node("%Url").text = "https://client.test"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("cat") == "cliente", "alta individual usa la categoría elegida")

	dialogo.abrir()
	dialogo.get_node("%Modo").select(1)
	dialogo.get_node("%Modo").item_selected.emit(1)
	_check(not dialogo.get_node("%Categoria").visible and not dialogo.get_node("%EtiquetaCategoria").visible, "en modo Varias se oculta la categoría")

	dialogo.abrir_edicion({"nombre": "Srv", "desc": "", "url": "https://srv.test", "img": "", "cat": "servidor"}, "https://srv.test")
	_check(dialogo.get_node("%Categoria").selected == 2, "edición selecciona la categoría del enlace")
	emitido = {}
	url_original_emitida = ""
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("cat") == "servidor", "editar conserva la categoría")

	dialogo.abrir_edicion({"nombre": "Sin", "desc": "", "url": "https://sin.test", "img": ""}, "https://sin.test")
	_check(dialogo.get_node("%Categoria").selected == 0, "edición sin cat selecciona otro")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `... -s tests/test_agregar_enlace.gd`
Expected: FALLOs (no existen `%Categoria`/`%EtiquetaCategoria`).

- [ ] **Step 3: Write minimal implementation**

En `scenes/AgregarEnlace.tscn`:

1. Insertar entre el nodo `Url` y el nodo `VistaPrevia`:

```
[node name="EtiquetaCategoria" type="Label" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
text = "Categoría"

[node name="Categoria" type="OptionButton" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
```

2. Cambiar `size = Vector2i(540, 470)` → `size = Vector2i(540, 520)` (la fila nueva cabe sin cortarse en una ventana no redimensionable).

En `scripts/agregar_enlace.gd`:

1. Añadir preload junto al de `GestorImagenesScript`:

```gdscript
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
```

2. En `_ready()`, tras la conexión de `%Modo.item_selected`:

```gdscript
	for i in range(GestorCatalogoScript.CATEGORIAS.size()):
		%Categoria.add_item(GestorCatalogoScript.categoria_display(GestorCatalogoScript.CATEGORIAS[i]))
```

3. En `abrir()`, tras `_cambiar_modo(0)`:

```gdscript
	%Categoria.select(0)
```

4. En `abrir_edicion(datos, ...)`, junto al resto de precarga de campos (tras `_fijar_imagen(...)`):

```gdscript
	%Categoria.select(GestorCatalogoScript.CATEGORIAS.find(GestorCatalogoScript.normalizar_categoria(datos.get("cat", ""))))
```

5. En `_mostrar_individual(individual)`:

```gdscript
	%EtiquetaCategoria.visible = individual
	%Categoria.visible = individual
```

6. En `_on_guardar`, antes de construir `var datos`:

```gdscript
	var cat_clave := GestorCatalogoScript.CATEGORIAS[%Categoria.get_selected_index()]
```

y en el Dictionary de `datos`:

```gdscript
	var datos := {"nombre": n, "desc": d, "url": u, "img": img_final, "cat": cat_clave}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `... -s tests/test_agregar_enlace.gd`
Expected: `TESTS OK` (24 checks).

- [ ] **Step 5: Commit**

```bash
git add scripts/agregar_enlace.gd scenes/AgregarEnlace.tscn tests/test_agregar_enlace.gd
git commit -m "feat: desplegable de categoría en el alta/edición de enlaces (#5)"
```

---
### Task 5: Filtro combinado por estado y categoría

**Files:**
- Modify: `scripts/main.gd` — `@onready var filtro_cat`, `_ready` (construir `%FiltroCategoria`), `_mostrar_lista` (5º arg a `setup`), `_aplicar_filtro`
- Modify: `scenes/Main.tscn` — `%FiltroCategoria`
- Test: `tests/test_main_barra.gd` (56 → 59 checks)

**Interfaces:**
- Consumes: `GestorCatalogoScript.CATEGORIAS`/`categoria_display`/`normalizar_categoria` (Task 1); `item.setup(..., categoria)` y `item.categoria` (Task 3); `cat` normalizada en `_entradas` (Task 2).
- Produces: comportamiento visible de la lista (`hijo.visible`) = estado AND categoría; `%FiltroCategoria` con 6 items ("Todas" + 5 categorías).

- [ ] **Step 1: Write the failing tests**

En `tests/test_main_barra.gd`, dentro del bloque «Catálogo: categorías» (tras los checks de normalización del Task 2), añadir:

```gdscript
	var filtro_cat: OptionButton = main.get_node("%FiltroCategoria")
	_check(filtro_cat.get_item_count() == 6 and filtro_cat.get_item_text(0) == "Todas" and filtro_cat.get_item_text(1) == "Otro" and filtro_cat.get_item_text(2) == "Cliente" and filtro_cat.get_item_text(3) == "Servidor" and filtro_cat.get_item_text(4) == "Códigos fuente" and filtro_cat.get_item_text(5) == "Parche", "el filtro de categoría ofrece Todas y las 5 categorías en orden")

	main_script._entradas = [
		{"nombre": "SOK", "url": "https://srv.test", "cat": "servidor"},
		{"nombre": "SCAI", "url": "https://srv2.test", "cat": "servidor"},
		{"nombre": "COK", "url": "https://cli.test", "cat": "cliente"},
	]
	main_script._estados = {
		"https://srv.test": {"valido": true},
		"https://srv2.test": {"valido": false},
		"https://cli.test": {"valido": true},
	}
	main_script._refrescar_vista()
	main.get_node("%FiltroEstado").select(1)
	main.get_node("%FiltroCategoria").select(3)
	main_script._aplicar_filtro()
	var visibles: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			visibles.append(hijo.url)
	_check(visibles == ["https://srv.test"], "el filtro combina estado válido y categoría servidor")
	main.get_node("%FiltroCategoria").select(0)
	main_script._aplicar_filtro()
	var visibles_todas: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			visibles_todas.append(hijo.url)
	_check(visibles_todas == ["https://srv.test", "https://cli.test"], "categoría Todas no filtra por categoría y mantiene el estado")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `... -s tests/test_main_barra.gd`
Expected: FALLOs (no existe `%FiltroCategoria`; `_aplicar_filtro` no combina).

- [ ] **Step 3: Write minimal implementation**

En `scenes/Main.tscn`, tras el bloque del nodo `FiltroEstado` (antes de `Progreso`):

```
[node name="FiltroCategoria" type="OptionButton" parent="ColumnaApp/Margen/Columna/BarraAcciones"]
unique_name_in_owner = true
layout_mode = 2
selected = 0
```

En `scripts/main.gd`:

1. Añadir junto al resto de `@onready`:

```gdscript
@onready var filtro_cat: OptionButton = %FiltroCategoria
```

2. En `_ready()`, tras la conexión de `filtro.item_selected`:

```gdscript
	filtro_cat.clear()
	filtro_cat.add_item("Todas", 0)
	for i in range(GestorCatalogoScript.CATEGORIAS.size()):
		filtro_cat.add_item(GestorCatalogoScript.categoria_display(GestorCatalogoScript.CATEGORIAS[i]), i + 1)
	filtro_cat.select(0)
	filtro_cat.item_selected.connect(func(_i: int) -> void: _aplicar_filtro())
```

3. En `_mostrar_lista`, la llamada a `item.setup(...)` pasa la categoría normalizada como 5º argumento:

```gdscript
		item.setup(
			str(entrada.get("nombre", "")),
			str(entrada.get("desc", "")),
			str(entrada.get("url", "")),
			str(entrada.get("img", "")),
			GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))
		)
```

4. `_aplicar_filtro()` (sustituye el cuerpo, líneas 540-551):

```gdscript
func _aplicar_filtro() -> void:
	var modo := filtro.get_selected_id()
	var cat_id := filtro_cat.get_selected_id()
	var clave_cat := ""
	if cat_id > 0:
		clave_cat = GestorCatalogoScript.CATEGORIAS[cat_id - 1]
	for hijo in lista.get_children():
		var visible_estado := true
		match modo:
			1:
				visible_estado = hijo.valido == true
			2:
				visible_estado = hijo.valido == false
			3:
				visible_estado = hijo.valido == null
		hijo.visible = visible_estado and (cat_id == 0 or hijo.categoria == clave_cat)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `... -s tests/test_main_barra.gd`
Expected: `TESTS OK` (59 checks).

- [ ] **Step 5: Batería completa**

Run: todas las suites. En PowerShell, desde la raíz del repo:

```powershell
$godot = "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe"
foreach ($t in Get-ChildItem tests/*.gd) {
  & $godot --headless --path "K:\gestor-de-enlaces" -s $t.Name
  if ($LASTEXITCODE -ne 0) { Write-Error ("FALLO en " + $t.Name); break }
}
```
Expected: las 10 suites terminan en `TESTS OK` (conteos: config_store 5, gestor_contadores 7, gestor_imagenes 13, preferencias 4, estado_store 12, link_checker_timeout 4, list_item 21, main_barra 59, gestor_catalogo 21, agregar_enlace 24).

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd scenes/Main.tscn tests/test_main_barra.gd
git commit -m "feat: filtro combinado por estado y categoría (#5)"
```