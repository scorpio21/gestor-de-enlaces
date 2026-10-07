extends RefCounted

const LIMITE := 200

static var _cache := {}
static var _orden: Array = []


static func textura(ruta: String) -> Texture2D:
	if ruta.is_empty():
		return null
	var firma := _firma(ruta)
	if firma.is_empty():
		_cache.erase(ruta)
		_orden.erase(ruta)
		return null
	var previa: Variant = _cache.get(ruta)
	if typeof(previa) == TYPE_DICTIONARY and str(previa.get("firma", "")) == firma:
		return previa.get("textura")
	var imagen := Image.load_from_file(ruta)
	if imagen == null or imagen.is_empty():
		_cache.erase(ruta)
		_orden.erase(ruta)
		return null
	var textura := ImageTexture.create_from_image(imagen)
	_cache[ruta] = {"firma": firma, "textura": textura}
	_orden.append(ruta)
	while _orden.size() > LIMITE:
		_cache.erase(_orden.pop_front())
	return textura


static func tamano() -> int:
	return _cache.size()


static func limpiar() -> void:
	_cache.clear()
	_orden.clear()


static func _firma(ruta: String) -> String:
	if not FileAccess.file_exists(ruta):
		return ""
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return ""
	var longitud := archivo.get_length()
	archivo.close()
	return "%d|%d" % [longitud, int(FileAccess.get_modified_time(ruta))]
