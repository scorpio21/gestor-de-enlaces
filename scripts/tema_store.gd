class_name TemaStore
extends RefCounted

const TemaSistemaScript := preload("res://scripts/tema_sistema.gd")

const TEMA_DEFAULT := "oscuro"
const TEMAS_VALIDOS := ["claro", "oscuro"]

const _PALETA_OSCURO := {
	"fondo_claro": Color(0.95, 0.95, 0.95, 1),
	"texto_suave": Color(0.75, 0.75, 0.75, 1),
	"texto_tenue": Color(0.7, 0.7, 0.7, 1),
	"error": Color(0.95, 0.4, 0.4, 1),
	"valido": Color(0.35, 0.85, 0.45, 1),
	"caido": Color(0.95, 0.35, 0.35, 1),
	"sin_comprobar": Color(0.55, 0.55, 0.55, 1),
}

const _PALETA_CLARO := {
	"fondo_claro": Color(0.95, 0.95, 0.95, 1),
	"texto_suave": Color(0.3, 0.3, 0.3, 1),
	"texto_tenue": Color(0.35, 0.35, 0.35, 1),
	"error": Color(0.8, 0.15, 0.15, 1),
	"valido": Color(0.1, 0.55, 0.25, 1),
	"caido": Color(0.8, 0.1, 0.1, 1),
	"sin_comprobar": Color(0.45, 0.45, 0.45, 1),
}

static var _actual := TEMA_DEFAULT
static var _fondos: Dictionary = {}


static func paleta() -> Dictionary:
	return _PALETA_CLARO if _actual == "claro" else _PALETA_OSCURO


static func color_estado(ok: Variant) -> Color:
	if ok == true:
		return Color(paleta().get("valido"))
	if ok == false:
		return Color(paleta().get("caido"))
	return Color(paleta().get("sin_comprobar"))


static func normalizar(v: Variant) -> String:
	var modo := str(v)
	return modo if TEMAS_VALIDOS.has(modo) else TEMA_DEFAULT


static func aplicar(modo: String, root: Node) -> void:
	var resuelto := modo
	if resuelto == "auto":
		resuelto = TemaSistemaScript.resolver("auto", TemaSistemaScript.soportado(), TemaSistemaScript.oscuro_detectado())
	_actual = normalizar(resuelto)
	var tema := _construir_tema()
	if root is Control:
		(root as Control).theme = tema
	for nodo in _recorrer(root):
		if nodo is ColorRect and nodo.name == "Fondo":
			var id_nodo: int = nodo.get_instance_id()
			if not _fondos.has(id_nodo):
				_fondos[id_nodo] = Color(nodo.color)
			nodo.color = Color(_PALETA_CLARO.get("fondo_claro")) if _actual == "claro" \
				else Color(_fondos[id_nodo])
		elif nodo is Label:
			var clave: String = _clave_texto(nodo)
			if clave != "":
				nodo.add_theme_color_override("font_color", _color_de(clave))
		elif nodo is Window and _tiene_fondo(nodo):
			(nodo as Window).theme = tema


static func _tiene_fondo(nodo: Node) -> bool:
	return nodo.find_child("Fondo", true, false) is ColorRect


static func _construir_tema() -> Theme:
	var oscuro := _actual != "claro"
	var t := Theme.new()
	var texto := Color(0.3, 0.3, 0.3) if not oscuro else Color(0.75, 0.75, 0.75, 1)
	var texto_activo := Color(0.12, 0.12, 0.12, 1) if not oscuro else Color(0.9, 0.9, 0.9, 1)
	var texto_apagado := Color(0.55, 0.55, 0.55, 1) if not oscuro else Color(0.45, 0.45, 0.45, 1)
	var borde := Color(0.72, 0.72, 0.72, 1) if not oscuro else Color(0.32, 0.32, 0.32, 1)
	var foco := Color(0.15, 0.45, 1.0, 1) if not oscuro else Color(0.45, 0.65, 1.0, 1)
	var fondo_boton := Color(0.84, 0.84, 0.84, 1) if not oscuro else Color(0.18, 0.18, 0.18, 1)
	var hover_boton := Color(0.93, 0.93, 0.93, 1) if not oscuro else Color(0.24, 0.24, 0.24, 1)
	var press_boton := Color(0.77, 0.77, 0.77, 1) if not oscuro else Color(0.13, 0.13, 0.13, 1)
	var fondo_input := Color(0.88, 0.88, 0.88, 1) if not oscuro else Color(0.15, 0.15, 0.15, 1)
	var fondo_panel := Color(0.92, 0.92, 0.92, 1) if not oscuro else Color(0.1, 0.1, 0.1, 0.6)
	var fondo_ventana := Color(0.95, 0.95, 0.95, 1) if not oscuro else Color(0.1, 0.1, 0.1, 1)
	var fondo_barra := Color(0.35, 0.6, 1.0, 1) if not oscuro else Color(0.5, 0.7, 1.0, 1)

	t.set_color("font_color", "Label", texto)
	t.set_color("font_color", "Button", texto)
	t.set_color("font_hover_color", "Button", texto_activo)
	t.set_color("font_pressed_color", "Button", texto)
	t.set_color("font_focus_color", "Button", texto)
	t.set_color("font_disabled_color", "Button", texto_apagado)
	t.set_color("font_color", "OptionButton", texto)
	t.set_color("font_hover_color", "OptionButton", texto_activo)
	t.set_color("font_color", "CheckBox", texto)
	t.set_color("font_hover_color", "CheckBox", texto_activo)
	t.set_color("font_color", "LineEdit", texto)
	t.set_color("font_placeholder_color", "LineEdit", texto_apagado)
	t.set_color("caret_color", "LineEdit", texto)
	t.set_color("selection_color", "LineEdit", Color(foco, 0.4))
	t.set_color("font_color", "SpinBox", texto)
	t.set_color("font_color", "TextEdit", texto)
	t.set_color("font_placeholder_color", "TextEdit", texto_apagado)
	t.set_color("caret_color", "TextEdit", texto)
	t.set_color("selection_color", "TextEdit", Color(foco, 0.4))
	t.set_color("font_color", "ProgressBar", texto)
	t.set_color("font_color", "MenuBar", texto)
	t.set_color("font_hover_color", "MenuBar", texto_activo)
	t.set_color("font_pressed_color", "MenuBar", texto_activo)
	t.set_color("font_color", "PopupMenu", texto)
	t.set_color("font_hover_color", "PopupMenu", texto_activo)
	t.set_color("font_separator_color", "PopupMenu", borde)
	t.set_color("font_disabled_color", "PopupMenu", texto_apagado)
	t.set_color("font_color", "AcceptDialog", texto)
	t.set_color("font_color", "ConfirmationDialog", texto)
	t.set_color("font_color", "FileDialog", texto)

	t.set_stylebox("normal", "Button", _caja(fondo_boton, borde, 4))
	t.set_stylebox("hover", "Button", _caja(hover_boton, borde, 4))
	t.set_stylebox("pressed", "Button", _caja(press_boton, borde, 4))
	t.set_stylebox("disabled", "Button", _caja(Color(fondo_boton, 0.6), Color(borde, 0.6), 4))
	t.set_stylebox("focus", "Button", _caja(Color(1, 1, 1, 0), foco, 4))
	t.set_stylebox("normal", "LineEdit", _caja(fondo_input, borde, 3))
	t.set_stylebox("focus", "LineEdit", _caja(fondo_input, foco, 3))
	t.set_stylebox("normal", "TextEdit", _caja(fondo_input, borde, 3))
	t.set_stylebox("focus", "TextEdit", _caja(fondo_input, foco, 3))
	t.set_stylebox("panel", "PanelContainer", _caja(fondo_panel, Color(1, 1, 1, 0), 0))
	t.set_stylebox("panel", "ScrollContainer", _caja(Color(1, 1, 1, 0), Color(1, 1, 1, 0), 0))
	t.set_stylebox("panel", "MenuBar", _caja(fondo_ventana, Color(1, 1, 1, 0), 0))
	t.set_stylebox("panel", "Window", _caja(fondo_ventana, Color(1, 1, 1, 0), 0))
	t.set_stylebox("panel", "AcceptDialog", _caja(fondo_ventana, borde, 0))
	t.set_stylebox("panel", "ConfirmationDialog", _caja(fondo_ventana, borde, 0))
	t.set_stylebox("panel", "FileDialog", _caja(fondo_ventana, borde, 0))
	t.set_stylebox("panel", "PopupMenu", _caja(fondo_ventana, borde, 0))
	t.set_stylebox("separator", "PopupMenu", _caja(borde, Color(1, 1, 1, 0), 0))
	t.set_stylebox("background", "ProgressBar", _caja(fondo_input, Color(1, 1, 1, 0), 0))
	t.set_stylebox("fill", "ProgressBar", _caja(fondo_barra, Color(1, 1, 1, 0), 0))
	return t


static func _caja(fondo: Color, borde: Color, radio: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	if borde.a > 0.0:
		sb.set_border_width_all(1)
		sb.border_color = borde
	sb.set_corner_radius_all(radio)
	return sb


static func _color_de(clave: String) -> Color:
	return Color(paleta().get(clave))


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