extends AlmacenScript

const AlmacenScript := preload("res://scripts/almacen.gd")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const RutasScript := preload("res://scripts/rutas.gd")

const NOMBRE := "gestorao.db"

# Una tabla por seccion, con una fila por cosa y la carga util en JSON. Las
# columnas sueltas (url, nombre) no son la fuente de verdad, solo existen para
# poder consultar por SQL sin recorrerlo todo a mano.
const TABLAS := [
	"CREATE TABLE IF NOT EXISTS meta (clave TEXT PRIMARY KEY NOT NULL, valor TEXT NOT NULL)",
	"CREATE TABLE IF NOT EXISTS entradas (id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT, json TEXT NOT NULL)",
	"CREATE TABLE IF NOT EXISTS estados (clave TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)",
	"CREATE TABLE IF NOT EXISTS borrados (id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT NOT NULL UNIQUE)",
	"CREATE TABLE IF NOT EXISTS cola (id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT NOT NULL)",
	"CREATE TABLE IF NOT EXISTS config (clave TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)",
	"CREATE TABLE IF NOT EXISTS instantaneas (id INTEGER PRIMARY KEY AUTOINCREMENT, json TEXT NOT NULL)",
	"CREATE TABLE IF NOT EXISTS presets (clave TEXT PRIMARY KEY NOT NULL, json TEXT NOT NULL)",
	"CREATE TABLE IF NOT EXISTS cambios (id INTEGER PRIMARY KEY AUTOINCREMENT, json TEXT NOT NULL)",
	"CREATE INDEX IF NOT EXISTS idx_entradas_url ON entradas (url)",
]

var _db = null
var _futuro := false
var _hay := false


func _init(ruta := "user://gestorao.db", base_datos := "user://") -> void:
	ruta_bd = ruta
	base = base_datos


func modo() -> String:
	return MODO_BASE_DATOS


func assets() -> String:
	return RutasScript.assets_escritura(base)


func ruta_de_nombre(_nombre: String) -> String:
	return ruta_bd


func abrir() -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base)) != OK:
		return false
	var carpeta_bd := ruta_bd.get_base_dir()
	if not carpeta_bd.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta_bd))
	var db = SQLite.new()
	db.path = ruta_bd
	# Sin esto el complemento imprime "Opened database successfully" en cada
	# apertura y en cada error; el error_message sigue estando para leerlo.
	db.verbosity_level = 0
	if not db.open_db():
		return false
	_db = db
	if not _crear_tablas():
		# Un fichero que no es una base de datos valida: se devuelve false para
		# que el arranque caiga a ficheros y avise, sin tocarlo.
		_db = null
		db.close_db()
		return false
	# El esquema se escribe solo si falta: si lo dejo, una base abierta por una
	# version posterior se respeta y _leer_meta la marca _futuro.
	_db.query_with_named_bindings("INSERT OR IGNORE INTO meta (clave, valor) VALUES (:c, :v)", {"c": "esquema", "v": str(ESQUEMA_ACTUAL)})
	_leer_meta()
	abierto = true
	return true


func cerrar() -> void:
	if _db != null:
		_db.close_db()
	_db = null
	abierto = false


func bloqueado() -> bool:
	return _futuro


func entradas() -> Array:
	if int(_meta("entradas_esquema", str(GestorDatosScript.SCHEMA_ACTUAL))) != GestorDatosScript.SCHEMA_ACTUAL:
		return []
	return _lista("SELECT json FROM entradas ORDER BY id")


func guardar_entradas(lista: Array) -> bool:
	return _transaccion(func() -> bool:
		if not _db.query("DELETE FROM entradas"):
			return false
		for e in lista:
			var url := ""
			if typeof(e) == TYPE_DICTIONARY:
				url = str((e as Dictionary).get("url", ""))
			if not _db.query_with_named_bindings("INSERT INTO entradas (url, json) VALUES (:u, :j)", {"u": url, "j": JSON.stringify(e)}):
				return false
		return _poner_meta("entradas_esquema", str(GestorDatosScript.SCHEMA_ACTUAL))
	)


func estados() -> Dictionary:
	return _diccionario("SELECT clave, json FROM estados")


func estado(clave: String) -> Dictionary:
	var filas := _sel("SELECT json FROM estados WHERE clave = :c", {"c": clave})
	if filas.is_empty():
		return {}
	var e: Variant = JSON.parse_string(str((filas[0] as Dictionary).get("json", "")))
	return e if typeof(e) == TYPE_DICTIONARY else {}


func guardar_estado(clave: String, datos: Dictionary) -> bool:
	return _transaccion(func() -> bool:
		return _poner_estado(clave, datos)
	)


func guardar_estados(todos: Dictionary) -> bool:
	return _transaccion(func() -> bool:
		return _escribir_estados(todos)
	)


func guardar_estados_y_borrados(estados: Dictionary, borrados: Array) -> bool:
	# Las dos cosas en una transaccion: un corte a mitad no puede dejar la
	# entrada borrada con su estado, o al reves (#63).
	return _transaccion(func() -> bool:
		if not _escribir_estados(estados):
			return false
		if not _db.query("DELETE FROM borrados"):
			return false
		for url in borrados:
			if not _insertar_borrado(str(url)):
				return false
		return true
	)


func historial(clave: String) -> Array:
	var h: Variant = estado(clave).get("historial", [])
	return h if typeof(h) == TYPE_ARRAY else []


func borrar_estado(clave: String) -> bool:
	var todos := estados()
	if not todos.has(clave):
		return true
	return _transaccion(func() -> bool:
		return _db.query_with_named_bindings("DELETE FROM estados WHERE clave = :c", {"c": clave})
	)


func borrados() -> Array:
	var lista := []
	for fila in _sel("SELECT url FROM borrados ORDER BY id"):
		lista.append(str((fila as Dictionary).get("url", "")))
	return lista


func guardar_borrados(lista: Array) -> bool:
	return _transaccion(func() -> bool:
		if not _db.query("DELETE FROM borrados"):
			return false
		for url in lista:
			if not _insertar_borrado(str(url)):
				return false
		return true
	)


func marcar_borrado(url: String) -> bool:
	return _transaccion(func() -> bool:
		return _insertar_borrado(url)
	)


func cola() -> Array:
	var lista := []
	for fila in _sel("SELECT url FROM cola ORDER BY id"):
		lista.append(str((fila as Dictionary).get("url", "")))
	return lista


func guardar_cola(urls: Array) -> bool:
	return _transaccion(func() -> bool:
		if not _db.query("DELETE FROM cola"):
			return false
		for url in urls:
			if not _db.query_with_named_bindings("INSERT INTO cola (url) VALUES (:u)", {"u": str(url)}):
				return false
		return _poner_meta("cola_fecha", str(int(Time.get_unix_time_from_system())))
	)


func limpiar_cola() -> bool:
	return _transaccion(func() -> bool:
		if not _db.query("DELETE FROM cola"):
			return false
		return _poner_meta("cola_fecha", "0")
	)


func config() -> Dictionary:
	return _diccionario("SELECT clave, json FROM config")


func guardar_config(datos: Dictionary) -> bool:
	return _transaccion(func() -> bool:
		return _escribir_diccionario("config", datos)
	)


func instantaneas() -> Array:
	return _lista("SELECT json FROM instantaneas ORDER BY id")


func guardar_instantaneas(filas: Array) -> bool:
	return _transaccion(func() -> bool:
		return _escribir_lista("instantaneas", filas)
	)


func presets() -> Dictionary:
	return _diccionario("SELECT clave, json FROM presets")


func guardar_presets(datos: Dictionary) -> bool:
	return _transaccion(func() -> bool:
		return _escribir_diccionario("presets", datos)
	)


func cambios() -> Array:
	return _lista("SELECT json FROM cambios ORDER BY id")


func guardar_cambios(lista: Array) -> bool:
	return _transaccion(func() -> bool:
		return _escribir_lista("cambios", lista)
	)


func capturas() -> Dictionary:
	var mapa := {}
	for sub in RutasScript.SUBCARPETAS:
		var carpeta := "%s/%s" % [assets(), sub]
		var abs := ProjectSettings.globalize_path(carpeta)
		if not DirAccess.dir_exists_absolute(abs):
			continue
		var dir := DirAccess.open(abs)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".import") or f.ends_with(".tmp") or f.ends_with(".bak"):
				continue
			mapa["%s/%s" % [sub, f]] = "%s/%s" % [carpeta, f]
	return mapa


func guardar_captura(nombre: String, origen: String) -> Dictionary:
	if nombre.is_empty():
		return {"ok": false, "error": "La captura no tiene nombre."}
	var destino := "%s/%s" % [assets(), nombre]
	if destino == origen:
		return {"ok": true, "destino": destino, "error": ""}
	if not FileAccess.file_exists(origen):
		return {"ok": false, "error": "No se encontro el origen."}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino.get_base_dir())) != OK:
		return {"ok": false, "error": "No se pudo crear la carpeta de imagenes."}
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(origen), ProjectSettings.globalize_path(destino)) != OK:
		return {"ok": false, "error": "No se pudo copiar la imagen."}
	return {"ok": true, "destino": destino, "error": ""}


func borrar_captura(nombre: String) -> bool:
	var ruta := "%s/%s" % [assets(), nombre]
	if not FileAccess.file_exists(ruta):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta)) == OK


func hay_copia() -> bool:
	return FileAccess.file_exists(_ruta_bak())


func restaurar_copia() -> bool:
	if _db == null or not hay_copia():
		return false
	if not _db.restore_from(_ruta_bak()):
		return false
	_leer_meta()
	return true


func rutas() -> Dictionary:
	return {
		"modo": modo(),
		"base": base,
		"ficheros": [ruta_bd],
		"carpetas": [base, assets()],
	}


func _crear_tablas() -> bool:
	for sentencia in TABLAS:
		if not _db.query(sentencia):
			return false
	return true


func _leer_meta() -> void:
	# El esquema vive en la propia base: una abierta por una version posterior
	# se marca _futuro y rechaza toda escritura, como el fichero unico (#63).
	_futuro = int(_meta("esquema", str(ESQUEMA_ACTUAL))) > ESQUEMA_ACTUAL
	_hay = false
	for tabla in ["entradas", "estados", "borrados", "cola", "config", "instantaneas", "presets", "cambios"]:
		var filas := _sel("SELECT COUNT(*) AS n FROM %s" % tabla)
		if not filas.is_empty() and int((filas[0] as Dictionary).get("n", 0)) > 0:
			_hay = true
			break


func _transaccion(bloque: Callable) -> bool:
	if _db == null or _futuro:
		return false
	_respaldar()
	if not _db.query("BEGIN"):
		return false
	if not bool(bloque.call()):
		_db.query("ROLLBACK")
		return false
	if not _db.query("COMMIT"):
		_db.query("ROLLBACK")
		return false
	escrituras += 1
	_hay = true
	return true


func _respaldar() -> void:
	# El .bak se toma justo antes de escribir y solo si ya habia algo que
	# perder: es la version previa, igual que el .bak de los otros backends.
	if not _hay:
		return
	var bak := _ruta_bak()
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))
	_db.backup_to(bak)


func _escribir_estados(todos: Dictionary) -> bool:
	if not _db.query("DELETE FROM estados"):
		return false
	for clave in todos.keys():
		if not _poner_estado(str(clave), todos[clave]):
			return false
	return true


func _poner_estado(clave: String, datos: Dictionary) -> bool:
	return _db.query_with_named_bindings("INSERT OR REPLACE INTO estados (clave, json) VALUES (:c, :j)", {"c": clave, "j": JSON.stringify(datos)})


func _insertar_borrado(url: String) -> bool:
	return _db.query_with_named_bindings("INSERT OR IGNORE INTO borrados (url) VALUES (:u)", {"u": url})


func _escribir_lista(tabla: String, lista: Array) -> bool:
	if not _db.query("DELETE FROM %s" % tabla):
		return false
	for e in lista:
		if not _db.query_with_named_bindings("INSERT INTO %s (json) VALUES (:j)" % tabla, {"j": JSON.stringify(e)}):
			return false
	return true


func _escribir_diccionario(tabla: String, datos: Dictionary) -> bool:
	if not _db.query("DELETE FROM %s" % tabla):
		return false
	for clave in datos.keys():
		if not _db.query_with_named_bindings("INSERT INTO %s (clave, json) VALUES (:c, :j)" % tabla, {"c": str(clave), "j": JSON.stringify(datos[clave])}):
			return false
	return true


func _lista(sql: String) -> Array:
	var lista := []
	for fila in _sel(sql):
		lista.append(JSON.parse_string(str((fila as Dictionary).get("json", ""))))
	return lista


func _diccionario(sql: String) -> Dictionary:
	var d := {}
	for fila in _sel(sql):
		var f := fila as Dictionary
		d[str(f.get("clave", ""))] = JSON.parse_string(str(f.get("json", "")))
	return d


func _meta(clave: String, por_defecto: String) -> String:
	var filas := _sel("SELECT valor FROM meta WHERE clave = :c", {"c": clave})
	if filas.is_empty():
		return por_defecto
	return str((filas[0] as Dictionary).get("valor", por_defecto))


func _poner_meta(clave: String, valor: String) -> bool:
	return _db.query_with_named_bindings("INSERT OR REPLACE INTO meta (clave, valor) VALUES (:c, :v)", {"c": clave, "v": valor})


func _ruta_bak() -> String:
	return ruta_bd + ".bak"


func _sel(sql: String, params: Dictionary = {}) -> Array:
	if _db == null:
		return []
	var ok: bool
	if params.is_empty():
		ok = _db.query(sql)
	else:
		ok = _db.query_with_named_bindings(sql, params)
	if not ok:
		return []
	var res: Variant = _db.query_result
	return res if typeof(res) == TYPE_ARRAY else []
