extends RefCounted


const INFO_NOMBRES := [
	["enlaces.json", "enlaces.json"],
	["estados.json", "estados.json"],
	["borrados.json", "borrados.json"],
	["config.json", "config.json"],
]

const LOG_NOMBRES := [
	["app.log", "logs/app.log"],
	["scan.log", "logs/scan.log"],
]


static func exportar(zip_ruta: String, base := "user://", version := "0.1.0", entradas := 0) -> Dictionary:
	var zip := ZIPPacker.new()
	if zip.open(zip_ruta) != OK:
		return {"ok": false, "errores": 1, "total": 0}
	var errores := 0
	var total := 0
	for par in INFO_NOMBRES:
		if _copia_si_existe(zip, base + "/" + par[1], par[0]):
			total += 1
	for par in LOG_NOMBRES:
		if _copia_si_existe(zip, base + "/" + par[1], par[0]):
			total += 1
	var info := "App=GestorAO\nVersion=%s\nGodot=%s\nOS=%s\nFecha=%s\nEntradas=%d\n" % [
		version,
		Engine.get_version_info().get("string", "desconocido"),
		OS.get_name(),
		Time.get_datetime_string_from_system(),
		entradas,
	]
	if _escribe(zip, "info.txt", info.to_utf8_buffer()):
		total += 1
	else:
		errores += 1
	zip.close()
	return {"ok": errores == 0, "errores": errores, "total": total}


static func _copia_si_existe(zip: ZIPPacker, origen: String, nombre: String) -> bool:
	if not FileAccess.file_exists(origen):
		return false
	var f := FileAccess.open(origen, FileAccess.READ)
	if f == null:
		return false
	return _escribe(zip, nombre, f.get_buffer(f.get_length()))


static func _escribe(zip: ZIPPacker, nombre: String, data: PackedByteArray) -> bool:
	if zip.start_file(nombre) != OK:
		return false
	zip.write_file(data)
	zip.close_file()
	return true


func _init() -> void:
	pass