extends RefCounted

const SCHEMA_ACTUAL := 1


static func version_de(ruta: String) -> int:
	var parseado: Variant = _parsear(ruta)
	if typeof(parseado) == TYPE_ARRAY:
		return 0
	if typeof(parseado) == TYPE_DICTIONARY:
		return int(parseado.get("schema_version", -1))
	return -1


static func cargar(ruta: String) -> Array:
	var parseado: Variant = _parsear(ruta)
	if typeof(parseado) == TYPE_ARRAY:
		guardar(ruta, parseado)
		return parseado
	if typeof(parseado) == TYPE_DICTIONARY:
		if int(parseado.get("schema_version", -1)) != SCHEMA_ACTUAL:
			return []
		var enlaces: Variant = parseado.get("enlaces", [])
		if typeof(enlaces) != TYPE_ARRAY:
			return []
		return enlaces
	return []


static func guardar(ruta: String, enlaces: Array) -> bool:
	var texto := JSON.stringify({"schema_version": SCHEMA_ACTUAL, "enlaces": enlaces}, "\t")
	var abs := ProjectSettings.globalize_path(ruta)
	var abs_tmp := ProjectSettings.globalize_path(ruta + ".tmp")
	var abs_bak := ProjectSettings.globalize_path(ruta + ".bak")
	var archivo := FileAccess.open(ruta + ".tmp", FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(texto)
	archivo.close()
	if FileAccess.file_exists(ruta):
		if FileAccess.file_exists(ruta + ".bak"):
			DirAccess.remove_absolute(abs_bak)
		if DirAccess.rename_absolute(abs, abs_bak) != OK:
			DirAccess.remove_absolute(abs_tmp)
			return false
	if DirAccess.rename_absolute(abs_tmp, abs) != OK:
		DirAccess.remove_absolute(abs_tmp)
		return false
	return true


static func hay_copia(ruta: String) -> bool:
	return FileAccess.file_exists(ruta + ".bak")


static func restaurar_copia(ruta: String) -> bool:
	if not hay_copia(ruta):
		return false
	var parseado: Variant = _parsear(ruta + ".bak")
	if typeof(parseado) == TYPE_ARRAY:
		return guardar(ruta, parseado)
	if typeof(parseado) == TYPE_DICTIONARY and int(parseado.get("schema_version", -1)) == SCHEMA_ACTUAL:
		return guardar(ruta, parseado.get("enlaces", []))
	return false


static func _parsear(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return null
	return JSON.parse_string(archivo.get_as_text())