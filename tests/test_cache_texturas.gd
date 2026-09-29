extends SceneTree

const CacheTexturasScript := preload("res://scripts/cache_texturas.gd")
const BASE := "user://__test_cache_texturas__"
const ORIGEN := "res://Assets/png/no-disponible.png"
const RUTA_Copia := BASE + "/copia.png"

var _fallos := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	_cache_texturas(ORIGEN)
	_copiar(ORIGEN, RUTA_Copia)
	_cache_texturas(RUTA_Copia)
	_invalida_por_contenido()
	_cache_borrada()
	_tope_cache()
	_ruta_vacia()
	CacheTexturasScript.limpiar()
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
		quit(1)


func _cache_texturas(ruta: String) -> void:
	CacheTexturasScript.limpiar()
	var textura := CacheTexturasScript.textura(ruta)
	_check(textura != null and textura.get_width() > 0, "carga la textura de %s" % ruta.get_file())
	_check(CacheTexturasScript.textura(ruta) == textura, "la segunda llamada devuelve la misma textura (caché)")
	_check(CacheTexturasScript.tamano() == 1, "la caché guarda una sola entrada")
	_check(CacheTexturasScript.textura(ORIGEN) != null, "una ruta distinta se carga aparte")
	_check(CacheTexturasScript.textura(RUTA_Copia) == CacheTexturasScript.textura(RUTA_Copia), "una ruta propia también se cachea")


func _invalida_por_contenido() -> void:
	_copiar(ORIGEN, RUTA_Copia)
	CacheTexturasScript.limpiar()
	var primera := CacheTexturasScript.textura(RUTA_Copia)
	_check(primera != null, "la copia se carga")
	var imagen := Image.load_from_file(ORIGEN)
	imagen.resize(24, 24)
	imagen.save_png(ProjectSettings.globalize_path(RUTA_Copia))
	var segunda := CacheTexturasScript.textura(RUTA_Copia)
	_check(segunda != null, "tras cambiar el fichero sigue habiendo textura")
	_check(segunda.get_width() == 24, "el cambio de tamaño+mtime invalida la entrada: %d" % segunda.get_width())


func _cache_borrada() -> void:
	_copiar(ORIGEN, RUTA_Copia)
	CacheTexturasScript.limpiar()
	var textura := CacheTexturasScript.textura(RUTA_Copia)
	_check(textura != null, "la copia se carga antes de borrarla")
	DirAccess.remove_absolute(RUTA_Copia)
	_check(CacheTexturasScript.textura(RUTA_Copia) == null, "una ruta borrada devuelve null")
	_check(CacheTexturasScript.tamano() == 0, "la entrada de la ruta borrada se elimina")


func _tope_cache() -> void:
	CacheTexturasScript.limpiar()
	var bytes := FileAccess.get_file_as_bytes(ORIGEN)
	for i in range(CacheTexturasScript.LIMITE + 10):
		var ruta := BASE + "/img%d.png" % i
		var salida := FileAccess.open(ruta, FileAccess.WRITE)
		salida.store_buffer(bytes)
		salida.close()
		CacheTexturasScript.textura(ruta)
		DirAccess.remove_absolute(ruta)
	_check(
		CacheTexturasScript.tamano() == CacheTexturasScript.LIMITE,
		"la caché se queda en el tope de %d entradas: %d" % [CacheTexturasScript.LIMITE, CacheTexturasScript.tamano()]
	)


func _ruta_vacia() -> void:
	CacheTexturasScript.limpiar()
	_check(CacheTexturasScript.textura("") == null, "una ruta vacía devuelve null")
	_check(CacheTexturasScript.textura(BASE + "/no-existe.png") == null, "una ruta inexistente devuelve null")
	_check(CacheTexturasScript.tamano() == 0, "las rutas inválidas no ensucian la caché")


func _copiar(desde: String, hasta: String) -> bool:
	var salida := FileAccess.open(hasta, FileAccess.WRITE)
	if salida == null:
		return false
	salida.store_buffer(FileAccess.get_file_as_bytes(desde))
	salida.close()
	return true


func _limpiar() -> void:
	for i in range(CacheTexturasScript.LIMITE + 20):
		DirAccess.remove_absolute(BASE + "/img%d.png" % i)
	DirAccess.remove_absolute(RUTA_Copia)
	DirAccess.remove_absolute(BASE)


func _check(ok: bool, texto: String) -> void:
	if ok:
		print("  OK: %s" % texto)
	else:
		print("  FALLO: %s" % texto)
		_fallos += 1
