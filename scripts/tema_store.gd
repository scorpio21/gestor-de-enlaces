class_name TemaStore
extends RefCounted

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
	_actual = normalizar(modo)
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