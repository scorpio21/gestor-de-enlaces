extends RefCounted

const ASSETS_RES := "res://Assets"
const ASSETS_USER := "user://Assets"
const CATALOGO_RES := "res://data/data.json"
const PLACEHOLDER := ASSETS_RES + "/png/no-disponible.png"
const SUBCARPETAS := ["png", "jpg"]


static func assets_escritura(config_base := "user://") -> String:
	return "%sAssets" % _con_barra(config_base)


static func es_escribible(ruta: String) -> bool:
	if ruta.begins_with("user://"):
		return true
	var prueba := "%s.escribible" % ruta
	var f := FileAccess.open(prueba, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prueba))
	return true


static func resolver(ruta: String, base_usuario := ASSETS_USER) -> String:
	if ruta.is_empty():
		return ""
	var rel := relativa(ruta)
	if rel.is_empty():
		return ruta if FileAccess.file_exists(ruta) else ""
	for base in [base_usuario, ASSETS_RES]:
		var candidata := "%s/%s" % [base, rel]
		if FileAccess.file_exists(candidata):
			return candidata
	return ""


static func relativa(ruta: String) -> String:
	for base in [ASSETS_RES, ASSETS_USER]:
		var prefijo := "%s/" % base
		if ruta.begins_with(prefijo):
			return ruta.substr(prefijo.length())
	return ""


static func en_base(ruta: String, base: String) -> bool:
	for sub in SUBCARPETAS:
		if ruta.begins_with("%s/%s/" % [base, sub]):
			return true
	return false


static func _con_barra(base: String) -> String:
	return base if base.ends_with("/") else base + "/"
