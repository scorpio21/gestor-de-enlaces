extends RefCounted

var _base := "user://"
var _max_bytes := 512 * 1024
var _app: FileAccess = null
var _scan: FileAccess = null


func _init(base := "user://", max_bytes := 512 * 1024) -> void:
	_base = base
	_max_bytes = max_bytes
	DirAccess.make_dir_recursive_absolute(_base + "/logs")
	_app = _abrir("app")
	_scan = _abrir("scan")


func app(tipo: String, msg: String) -> void:
	if _app == null:
		return
	if _app.get_length() >= _max_bytes:
		_rotar(_app, "app")
		_app = _abrir("app")
		if _app == null:
			return
	_app.store_string("[APP][%s] %s %s\n" % [tipo, Time.get_datetime_string_from_system(), msg])


func scan(url: String, resultado: String, detalle := "") -> void:
	if _scan == null:
		return
	if _scan.get_length() >= _max_bytes:
		_rotar(_scan, "scan")
		_scan = _abrir("scan")
		if _scan == null:
			return
	_scan.store_string("[SCAN] %s %s %s %s\n" % [Time.get_datetime_string_from_system(), url, resultado, detalle.strip_edges()])


func flush() -> void:
	if _app != null:
		_app.flush()
	if _scan != null:
		_scan.flush()


func _abrir(especie: String) -> FileAccess:
	var ruta := _base + "/logs/" + especie + ".log"
	if not FileAccess.file_exists(ruta):
		var creado := FileAccess.open(ruta, FileAccess.WRITE)
		if creado == null:
			return null
		creado.close()
	var f := FileAccess.open(ruta, FileAccess.READ_WRITE)
	if f == null:
		return null
	f.seek_end()
	return f


func _rotar(f: FileAccess, especie: String) -> void:
	f.close()
	DirAccess.remove_absolute(_base + "/logs/" + especie + ".log.1")
	DirAccess.rename_absolute(_base + "/logs/" + especie + ".log", _base + "/logs/" + especie + ".log.1")