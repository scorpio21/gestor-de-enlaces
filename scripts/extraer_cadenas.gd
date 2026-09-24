extends SceneTree

const PATRON_ESCENA := r'(?:^|\s|/)(?:text|title|placeholder_text|tooltip_text|dialog_text|ok_button_text|cancel_button_text)\s*=\s*"([^"]+)"'
const PATRON_SCRIPT_UI := r'\.(?:text|title|dialog_text|ok_button_text|cancel_button_text)\s*=\s*"([^"]+)"'
const PATRON_TR := r'\btr\("([^"]*)"'
const PATRON_MENU := r'(?:add_item|add_icon_item)\([^"\n]*"([^"]+)"'
const ESCENAS := ["res://scenes/Main.tscn", "res://scenes/Preferencias.tscn", "res://scenes/AgregarEnlace.tscn", "res://scenes/ListItem.tscn", "res://scenes/Historial.tscn"]
const SCRIPTS_UI := ["res://scripts/main.gd", "res://scripts/preferencias.gd", "res://scripts/agregar_enlace.gd", "res://scripts/list_item.gd", "res://scripts/historial.gd"]
const EXTRA_VISIBLES := ["Válido", "Caído", "Sin comprobar", "Otro", "Cliente", "Servidor", "Códigos fuente", "Parche"]

static func ui_strings() -> Array[String]:
	var por_analizar := {}
	for ruta in ESCENAS:
		_volcar(FileAccess.get_file_as_string(ruta), RegEx.create_from_string(PATRON_ESCENA), por_analizar)
	for ruta in SCRIPTS_UI:
		_volcar(FileAccess.get_file_as_string(ruta), RegEx.create_from_string(PATRON_SCRIPT_UI), por_analizar)
		_volcar(FileAccess.get_file_as_string(ruta), RegEx.create_from_string(PATRON_TR), por_analizar)
		_volcar(FileAccess.get_file_as_string(ruta), RegEx.create_from_string(PATRON_MENU), por_analizar)
	for cadena in EXTRA_VISIBLES:
		por_analizar[cadena] = true
	var resultado: Array[String] = []
	for clave in por_analizar.keys():
		resultado.append(clave)
	return resultado

static func _volcar(src: String, regex: RegEx, destino: Dictionary) -> void:
	for m in regex.search_all(src):
		var txt := m.get_string(1).strip_edges()
		if txt.is_empty():
			continue
		if txt.begins_with("https"):
			continue
		if txt.begins_with("v0"):
			continue
		if txt == "v":
			continue
		if txt == "Open a File":
			continue
		if txt.length() > 200:
			continue
		destino[txt] = true

func _initialize() -> void:
	var claves: Array[String] = []
	for clave in ui_strings():
		claves.append(clave)
	claves.sort()
	for clave in claves:
		print(clave)
	quit(0)