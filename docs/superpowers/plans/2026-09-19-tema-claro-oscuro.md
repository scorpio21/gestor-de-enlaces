# #19 Tema claro/oscuro configurable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir un selector de tema Claro/Oscuro persistido en Preferencias; "oscuro" reproduce el aspecto actual y "claro" re-mapea fondos, textos y colores de estado de toda la app.

**Architecture:** Nuevo `scripts/tema_store.gd` (RefCounted, estáticas) como única fuente de verdad del color. `config_store.gd` persiste el campo `tema`. `preferencias.gd` expone un OptionButton `%Tema` y amplía la señal `aplicado`. `main.gd` aplica el tema en `_ready()` y en `_aplicar_preferencias()` y re-pinta la lista. `list_item.gd` dibuja con `color_estado()` en vez de literales.

**Tech Stack:** Godot 4.7.2, GDScript, tests SceneTree headless.

## Global Constraints

- Motor local: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/<suite>.gd`
- Tabs, sin comentarios; UI en español; preload-const en lugar de class_name nuevo solo para código nuevo (los stores existentes usan `class_name`, y `tema_store.gd` usará `class_name TemaStore`).
- Tests en base `user://__test_<area>__` y se limpian al terminar.
- Batería: `& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'` (hoy 19 suites; 20 al añadir `test_tema_store.gd`).
- Workflow del repo: commits directos en `main` y push al final; cerrar la issue con `gh issue close 19`.
- Default = `oscuro`; el selector guarda en `user://config.json`.

---

### Task 1: `tema_store.gd` + `test_tema_store.gd` (TDD)

**Files:**
- Create: `scripts/tema_store.gd`
- Create: `scripts/tema_store.gd.uid` (generado por `--import`, ver Step 5)
- Test: `tests/test_tema_store.gd`
- Test: `tests/test_tema_store.gd.uid`

**Interfaces:**
- Consumes: nada (solo `Node`/`ColorRect`/`Label` del árbol).
- Produces: `TemaStore.paleta() -> Dictionary`, `TemaStore.color_estado(ok: Variant) -> Color`, `TemaStore.aplicar(modo: String, root: Node) -> void`, `TemaStore.normalizar(v: Variant) -> String`. Paleta activa estática (estado global de `aplicar`). Consumido por las Tasks 2-4.

- [ ] **Step 1: Escribir el test que falla**

Crear `tests/test_tema_store.gd`:

```gdscript
extends SceneTree

const TemaStoreScript := preload("res://scripts/tema_store.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var paleta := TemaStoreScript.paleta()
	_check(paleta.get("texto_suave") == Color(0.75, 0.75, 0.75, 1), "paleta por defecto es el set oscuro")
	_check(TemaStoreScript.normalizar("claro") == "claro" and TemaStoreScript.normalizar("oscuro") == "oscuro", "normalizar acepta los dos modos")
	_check(TemaStoreScript.normalizar("chocolate") == "oscuro" and TemaStoreScript.normalizar(3) == "oscuro", "normalizar cae a oscuro con valores inválidos")

	var verde := TemaStoreScript.color_estado(true)
	var rojo := TemaStoreScript.color_estado(false)
	var gris := TemaStoreScript.color_estado(null)
	_check(verde == paleta.get("valido") and rojo == paleta.get("caido") and gris == paleta.get("sin_comprobar"), "color_estado resuelve los tres estados desde la paleta")

	var root := Node.new()
	root.add_child(_hacer_label("SUAVE", Color(0.75, 0.75, 0.75, 1)))
	root.add_child(_hacer_label("ERROR", Color(0.95, 0.4, 0.4, 1)))
	root.add_child(_hacer_label("FUERA", null))
	var fondo := ColorRect.new()
	fondo.name = "Fondo"
	fondo.color = Color(0.12, 0.12, 0.12, 1)
	root.add_child(fondo)

	TemaStoreScript.aplicar("claro", root)
	_check(root.get_child(0).get("theme_override_colors/font_color") == Color(0.3, 0.3, 0.3, 1), "claro re-mapea el texto suave 0.75 a 0.30")
	_check(root.get_child(1).get("theme_override_colors/font_color") == Color(0.8, 0.15, 0.15, 1), "claro re-mapea el rojo de error")
	_check(fondo.color == Color(0.95, 0.95, 0.95, 1), "claro pinta el ColorRect Fondo")
	_check(root.get_child(2).get("theme_override_colors/font_color") == null, "un Label sin overlay de color no se toca")

	TemaStoreScript.aplicar("oscuro", root)
	_check(root.get_child(0).get("theme_override_colors/font_color") == Color(0.75, 0.75, 0.75, 1), "oscuro restaura el texto suave")
	_check(root.get_child(1).get("theme_override_colors/font_color") == Color(0.95, 0.4, 0.4, 1), "oscuro restaura el rojo de error")
	_check(fondo.color == Color(0.12, 0.12, 0.12, 1), "oscuro preserva el fondo original")
	_check(root.get_child(2).get("theme_override_colors/font_color") == null, "un Label sin overlay sigue intacto tras oscuro")

	TemaStoreScript.aplicar("oscuro", root)
	_check(fondo.color == Color(0.12, 0.12, 0.12, 1) \
		and root.get_child(1).get("theme_override_colors/font_color") == Color(0.95, 0.4, 0.4, 1), "aplicar el mismo modo dos veces es idempotente")

	root.free()
	_cerrar()


func _hacer_label(texto: String, color: Variant) -> Label:
	var l := Label.new()
	l.name = texto
	l.text = texto
	if color != null:
		l.add_theme_color_override("font_color", color)
	return l


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
```

Notas:
- El check de "claro re-mapea el texto suave" compara con `Color(0.3,0.3,0.3,1)`; el override se crea en el Label con `add_theme_color_override("font_color", Color(0.75,0.75,0.75,1))`.
- El `Label "DEFAULT"` está en la posición 2 del root; `"Fuera"` en la 3 (nada del árbol destino se altera). Los índices fijos asumen el orden exacto del `add_child`; si añades nodos, ajusta los índices.

- [ ] **Step 2: Ejecutar y verificar que falla**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_tema_store.gd
```
Expected: parse errors por `tema_store.gd` inexistente (`Preload file ... does not exist`).

- [ ] **Step 3: Implementar `scripts/tema_store.gd`**

```gdscript
class_name TemaStore
extends RefCounted

const TEMA_DEFAULT := "oscuro"
const TEMAS_VALIDOS := ["claro", "oscuro"]

const _PALETA_OSCURO := {
	"fondo_claro": Color(0.95, 0.95, 0.95, 1),
	"fondo_oscuro_principal": Color(0.1, 0.1, 0.1, 1),
	"texto_suave": Color(0.75, 0.75, 0.75, 1),
	"texto_tenue": Color(0.7, 0.7, 0.7, 1),
	"error": Color(0.95, 0.4, 0.4, 1),
	"valido": Color(0.35, 0.85, 0.45, 1),
	"caido": Color(0.95, 0.35, 0.35, 1),
	"sin_comprobar": Color(0.55, 0.55, 0.55, 1),
}

const _PALETA_CLARO := {
	"fondo_claro": Color(0.95, 0.95, 0.95, 1),
	"fondo_oscuro_principal": Color(0.1, 0.1, 0.1, 1),
	"texto_suave": Color(0.3, 0.3, 0.3, 1),
	"texto_tenue": Color(0.35, 0.35, 0.35, 1),
	"error": Color(0.8, 0.15, 0.15, 1),
	"valido": Color(0.1, 0.55, 0.25, 1),
	"caido": Color(0.8, 0.1, 0.1, 1),
	"sin_comprobar": Color(0.45, 0.45, 0.45, 1),
}

static var _actual := TEMA_DEFAULT


static func paleta() -> Dictionary:
	return _PALETA_CLARO if _actual == "claro" else _PALETA_OSCURO


static func color_estado(ok: Variant) -> Color:
	var p := paleta()
	if ok == true:
		return Color(p.get("valido"))
	if ok == false:
		return Color(p.get("caido"))
	return Color(p.get("sin_comprobar"))


static func normalizar(v: Variant) -> String:
	var modo := str(v)
	return modo if TEMAS_VALIDOS.has(modo) else TEMA_DEFAULT


static func aplicar(modo: String, root: Node) -> void:
	_actual = normalizar(modo)
	for nodo in _recorrer(root):
		if nodo is ColorRect and nodo.name == "Fondo":
			if _actual == "claro":
				nodo.color = _PALETA_CLARO.get("fondo_claro")
		elif nodo is Label:
			var clave: String = _clave_texto(nodo)
			if clave != "":
				nodo.add_theme_color_override("font_color", _color_de(clave))


static func _recorrer(raiz: Node) -> Array:
	var nodos: Array = []
	if raiz == null:
		return nodos
	var pila: Array = [raiz]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		nodos.append(n)
		for hijo in n.get_children():
			pila.append(hijo)
	return nodos


static func _clave_texto(nodo: Control) -> String:
	if not nodo.has_theme_color_override("font_color"):
		return ""
	var c := nodo.get_theme_color("font_color")
	for clave in ["texto_suave", "texto_tenue", "error"]:
		if c == _PALETA_OSCURO.get(clave) or c == _PALETA_CLARO.get(clave):
			return clave
	return ""


static func _color_de(clave: String) -> Color:
	return (paleta() if _actual == "claro" else paleta()).get(clave)
```

Notas de implementación:
- `_mapa_conversion` no existe: `_color_de(clave)` devuelve el valor de la paleta **activa** para la clave detectada. Como `_clave_texto` acepta el color actual si coincide con el valor de **cualquiera** de las dos paletas, la operación es idempotente y se restaura bien en claro↔oscuro (0.30 actual → detecta `texto_suave` claro → escribe 0.75).
- `ColorRect "Fondo"` en claro se pinta con `fondo_claro`; en oscuro **no se toca** (nota del spec: Main `0.10` vs diálogos `0.12`, preservar el valor actual en oscuro). La clave `fondo_claro` existe en ambas paletas para consultas uniformes.
- Los colores de estado (`valido`, `caido`, `sin_comprobar`) **no** se mapean por el barrido de Labels: los pintan los items vía `color_estado()` al regenerar la lista.

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run el mismo comando del Step 2.
Expected: `TESTS OK`. Ajusta los índices de `get_child(i)` si reordenas los `add_child` del test.

- [ ] **Step 5: Generar `.gd.uid` y commit**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --import
```
- Verifica que existe `scripts/tema_store.gd.uid`.
- Comprueba `git status --porcelain` y que `project.godot` NO aparezca modificado.
Commit:
```bash
git -C "K:\gestor-de-enlaces" add scripts/tema_store.gd scripts/tema_store.gd.uid tests/test_tema_store.gd tests/test_tema_store.gd.uid docs/superpowers/plans/2026-09-19-tema-claro-oscuro.md
git -C "K:\gestor-de-enlaces" commit -m "feat(tema): store claro/oscuro con paletas, color_estado y aplicar (TDD)"
```
> Este plan (si aún no existe) se incluye en el commit de Task 1, como en features previas.

---

### Task 2: `config_store.gd` (campo `tema`) + `preferencias.gd`/`Preferencias.tscn` (selector)

**Files:**
- Modify: `scripts/config_store.gd`
- Modify: `scripts/preferencias.gd`
- Modify: `scenes/Preferencias.tscn`
- Test: `tests/test_config_store.gd`
- Test: `tests/test_preferencias.gd`

**Interfaces:**
- Consumes: `TemaStore.normalizar` (Task 1) para sanear el valor.
- Produces: `config_store.cargar().tema`, `config_store.guardar(..., tema)`, señal `aplicado(..., tema: String)`, `%Tema` OptionButton. Consumido por la Task 3.

- [ ] **Step 1: Añadir checks (rojo) en `tests/test_config_store.gd`**

Localiza dónde se comprueba `cargar()` con defaults y `guardar()` (fichero `scripts/config_store.gd` testado en `tests/test_config_store.gd`, base `user://__test_config__`). Añade:

```gdscript
	# Tema (#19)
	var sin_tema := ConfigStoreScript.new("user://__test_config__")
	_check(sin_tema.cargar().get("tema", "") == "oscuro", "cargar sin archivo devuelve tema oscuro")
	sin_tema.guardar(2, 5.0, false, 0, "claro")
	_check(sin_tema.cargar().get("tema", "") == "claro", "guardar persiste el tema claro")
	sin_tema.guardar(2, 5.0, false, 0, "raro")
	_check(sin_tema.cargar().get("tema", "") == "oscuro", "guardar con tema inválido cae a oscuro")
	DirAccess.remove_absolute("user://__test_config__/config.json")
```

Ajusta las constantes/métodos al patrón real del fichero (el test existente ya crea el store con base `user://__test_config__`; usa el mismo objeto o crea uno nuevo igual).

- [ ] **Step 2: Añadir checks (rojo) en `tests/test_preferencias.gd`**

En la conexión del `aplicado` (línea 18) amplía la lambda y los checks:

```gdscript
	ventana.aplicado.connect(func(p: int, t: float, a: bool, i: int, tm: String) -> void: _aplicado = [p, t, a, i, tm])
	ventana.abrir(5, 20.0, false, 15, "oscuro")
	await process_frame
	...
	_check(ventana.get_node("%Tema").get_selected_id() == "oscuro", "abrir precarga el tema")
	...
	ventana.abrir(5, 20.0, true, 30, "claro")
	...
	ventana.get_node("%Tema").select(0)
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_aplicado != null and _aplicado[4] == "claro", "guardar emite el tema elegido")
```

- [ ] **Step 3: Ejecutar y verificar que falla**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_preferencias.gd
```
Expected: `check FALLIDO — ... tema oscuro` (config) y SCRIPT ERROR por `%Tema` inválido / lambda con 5 params (preferencias).

- [ ] **Step 4: Implementar `config_store.gd`**

Tras `INTERVALOS_VALIDOS`:
```gdscript
const TEMA_DEFAULT := "oscuro"
const TEMAS_VALIDOS := ["claro", "oscuro"]
```

En `cargar()` (el dict de retorno) y `guardar()` añade `tema`:
```gdscript
		"tema": _tema_ok(v.get("tema", TEMA_DEFAULT)),
```
```gdscript
func guardar(paralelismo: int, timeout: float, auto_abrir := AUTO_ABRIR_DEFAULT, intervalo := INTERVALO_DEFAULT, tema := TEMA_DEFAULT) -> bool:
	var dato := {
		...
		"tema": _tema_ok(tema),
	}
```

Añade `_tema_ok`:
```gdscript
func _tema_ok(v: Variant) -> String:
	var modo := str(v)
	return modo if TEMAS_VALIDOS.has(modo) else TEMA_DEFAULT
```

- [ ] **Step 5: Implementar `preferencias.gd` + `Preferencias.tscn`**

`scripts/preferencias.gd`:
```gdscript
signal aplicado(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int, tema: String)

@onready var tema_opcion: OptionButton = %Tema

func abrir(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0, tema := "oscuro") -> void:
	...
	_seleccionar_tema(tema)
	popup_centered()

func _seleccionar_tema(tema: String) -> void:
	for i in tema_opcion.get_item_count():
		if tema_opcion.get_item_id(i) == tema:
			tema_opcion.select(i)
			return
	tema_opcion.select(0)

func _on_guardar() -> void:
	aplicado.emit(
		...,
		str(tema_opcion.get_selected_id())
	)
	hide()
```

`scenes/Preferencias.tscn` — antes del nodo `Error` añade la fila Tema:
```text
[node name="EtiquetaTema" type="Label" parent="Margen/Columna"]
layout_mode = 2
text = "Tema"

[node name="Tema" type="OptionButton" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
item_count = 2
popup/item_0/text = "Oscuro"
popup/item_0/id = "oscuro"
popup/item_1/text = "Claro"
popup/item_1/id = "claro"
```

- [ ] **Step 6: Ejecutar y verificar que pasa**

Run ambos tests del Step 3.
Expected: `TESTS OK` en ambos.

- [ ] **Step 7: Commit**

```bash
git -C "K:\gestor-de-enlaces" add scripts/config_store.gd scripts/preferencias.gd scenes/Preferencias.tscn tests/test_config_store.gd tests/test_preferencias.gd
git -C "K:\gestor-de-enlaces" commit -m "feat(tema): config_store.tema persistido y selector %Tema en Preferencias"
```

---

### Task 3: Integración en `main.gd` (aplicar en `_ready` y `_aplicar_preferencias`) + `list_item.gd` (colores por paleta)

**Files:**
- Modify: `scripts/main.gd`
- Modify: `scripts/list_item.gd`
- Test: `tests/test_main_barra.gd`
- Test: `tests/test_list_item.gd` (si valida colores — revisar; si no, solo integración)

**Interfaces:**
- Consumes: `TemaStore` (Tasks 1-2); `config_store.cargar().tema`; señal `preferencias.aplicado(..., tema)`.
- Produces: tema aplicado en `_ready`, `_aplicar_preferencias(..., tema)` actualizado, items pintados con `color_estado`. Verificado en esta task.

- [ ] **Step 1: Implementar `scripts/main.gd`**

1. Preload tras `InformeStoreScript`:
```gdscript
const TemaStoreScript := preload("res://scripts/tema_store.gd")
```

2. En `_ready()` — tras `var cfg: Dictionary = _config_store.cargar()` (línea 89) y antes de `_refrescar_vista()` (línea 102):
```gdscript
	TemaStoreScript.aplicar(String(cfg.get("tema", "oscuro")), self)
```

3. Actualizar la firma de `_aplicar_preferencias` y el guardado:
```gdscript
func _aplicar_preferencias(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0, tema := "oscuro") -> void:
	_paralelismo = paralelismo
	_timeout = timeout
	_auto_abrir = auto_abrir
	_intervalo_auto = intervalo
	TemaStoreScript.aplicar(tema, self)
	if not _config_store.guardar(paralelismo, timeout, auto_abrir, intervalo, tema):
		progreso.text = "No se pudo guardar la configuración."
	_refrescar_vista()
	_rearmar_auto_escaneo()
	if _auto_abrir and _puede_auto_escanear():
		_comprobar_visibles()
```
> Nota: `_refrescar_vista()` se añade para que los items se regeneren con la paleta activa. Si el test previo de preferencias espera que aplicar no refresque la lista, revisa la interacción (los checks de la Task 3 lo cubren).

4. Actualizar la llamada de apertura en `_on_utilidades_id` (línea 242):
```gdscript
		preferencias.abrir(_paralelismo, _timeout, _auto_abrir, _intervalo_auto, String(_config_store.cargar().get("tema", "oscuro")))
```

- [ ] **Step 2: Implementar `scripts/list_item.gd`**

Preload tras `GestorCatalogoScript`:
```gdscript
const TemaStoreScript := preload("res://scripts/tema_store.gd")
```

En `setup()` (indicador sin comprobar y colores de texto):
```gdscript
	_pintar_estado("Sin comprobar", TemaStoreScript.color_estado(null))
```

En `aplicar_estado()`:
```gdscript
		_pintar_estado(texto, TemaStoreScript.color_estado(true))
	...
		_pintar_estado(texto, TemaStoreScript.color_estado(false))
	...
		_pintar_estado("Sin comprobar", TemaStoreScript.color_estado(null))
```

- [ ] **Step 3: Añadir checks de integración en `tests/test_main_barra.gd`**

Añadir tras los checks de `_formato_informe` (bloque Informe #11) o donde quede limpio:

```gdscript
	# Tema (#19)
	main_script._config_store.guardar(3, 10.0, false, 0, "oscuro")
	main_script._aplicar_preferencias(3, 10.0, false, 0, "claro")
	_check(main_script._config_store.cargar().get("tema", "") == "claro", "preferencias guardan el tema claro")
	_check(TemaStoreScript.color_estado(true) == Color(0.1, 0.55, 0.25, 1), "aplicar claro deja la paleta clara activa")
	main_script._aplicar_preferencias(3, 10.0, false, 0, "oscuro")
	_check(main_script._config_store.cargar().get("tema", "") == "oscuro", "preferencias guardan el tema oscuro")
```

Preload arriba:
```gdscript
const TemaStoreScript := preload("res://scripts/tema_store.gd")
```

> Al final del test (o donde ya se borra el config de pruebas) restaura el estado para no dejar el tema "claro" persistido que afecte a otros suites. El propio `_aplicar_preferencias(..., "oscuro")` lo resuelve si es el último check del bloque.

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: `TESTS OK`. Si el test cuelga (como en #11), el motivo será un error de script en el flujo `_aplicar_preferencias` — corrige la firma/no `puede_auto_escanear` antes de continuar.

- [ ] **Step 5: Smoke de arranque y commit**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --quit-after 5 2>&1 | Select-String -Pattern "SCRIPT ERROR|Parse Error"
```
Expected: sin errores.
Commit:
```bash
git -C "K:\gestor-de-enlaces" add scripts/main.gd scripts/list_item.gd tests/test_main_barra.gd
git -C "K:\gestor-de-enlaces" commit -m "feat(tema): aplicacion en _ready y preferencias; list_item pinta con paleta"
```

---

### Task 4: Batería completa, push y cierre de la issue

**Files:** ninguno (solo verificación y git).

- [ ] **Step 1: Batería completa**

Run:
```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh' 2>&1 | Select-Object -Last 25
```
Expected: `BATERÍA OK: 20 suites pasaron.`

- [ ] **Step 2: Revisar estado y push**

Run:
```bash
git -C "K:\gestor-de-enlaces" status --porcelain
git -C "K:\gestor-de-enlaces" log --oneline origin/main..HEAD
```
Confirma que solo hay cambios esperados (los untracked ajenos `Assets/icon/*.import`, `data/data2.json`, `docs/superpowers/plans/*.md` de features previas, `scripts/historial.gd.uid` se ignoran).
Push:
```bash
git -C "K:\gestor-de-enlaces" push origin main
```

- [ ] **Step 3: Cerrar la issue**

```bash
gh issue close 19 --comment "Implementado: tema claro/oscuro configurable persistido en Preferencias, aplicado a toda la app al arrancar y al guardar. Bateria local 20/20 OK."
```

> Verificar el cierre con `gh issue list --repo scorpio21/gestor-de-enlaces --state open --limit 10` y anotar las que quedan (#6, #17, #27, #30).