extends SceneTree

const Rutas := preload("res://scripts/rutas.gd")
const MainScript := preload("res://scripts/main.gd")
const Ayuda := preload("res://tests/ayuda.gd")
const BASE := "user://__test_rutas__"
const ASSETS := BASE + "/Assets"
const VACIA := BASE + "/vacia"

var _fallos := 0


func _initialize() -> void:
	_a_constantes()
	_b_relativa()
	_c_resolver()
	_d_en_base()
	_e_escribible()
	_f_main()
	_cerrar()


func _a_constantes() -> void:
	_check(Rutas.ASSETS_RES == "res://Assets" and Rutas.ASSETS_USER == "user://Assets", "las bases de lectura y escritura de capturas están separadas (#50)")
	_check(Rutas.CATALOGO_RES == "res://data/data.json", "el catálogo base se lee de res://data")
	_check(Rutas.PLACEHOLDER == "res://Assets/png/no-disponible.png", "el marcador de posición vive en el paquete")
	_check(Rutas.assets_escritura("user://") == "user://Assets", "la base de escritura sale de la base de configuración")
	_check(Rutas.assets_escritura("user://__x__") == "user://__x__/Assets", "la base de escritura normaliza la barra final")
	_check(Rutas.assets_escritura("user://__x__/") == "user://__x__/Assets", "una base con barra final no se duplica")


func _b_relativa() -> void:
	_check(Rutas.relativa("res://Assets/png/a.png") == "png/a.png", "relativa extrae la subcarpeta de una captura del paquete")
	_check(Rutas.relativa("user://Assets/jpg/a.jpg") == "jpg/a.jpg", "relativa extrae la subcarpeta de una captura propia")
	_check(Rutas.relativa("res://data/data.json") == "", "relativa ignora el catálogo base")
	_check(Rutas.relativa("user://__otro__/Assets/png/a.png") == "", "relativa ignora bases que no son las de la app")
	_check(Rutas.relativa("") == "", "relativa de una ruta vacía no revienta")


func _c_resolver() -> void:
	var mia := _crear_png("%s/png/no-disponible.png" % ASSETS)
	var ajena := _crear_png("%s/png/ajena.png" % VACIA)
	_check(Rutas.resolver("res://Assets/png/no-disponible.png", ASSETS) == mia, "con copia propia, resolver prefiere user:// a res:// (#50)")
	_check(Rutas.resolver("res://Assets/png/no-disponible.png", VACIA) == "res://Assets/png/no-disponible.png", "sin copia propia, resolver cae a la captura del paquete")
	_check(Rutas.resolver(ajena) == ajena, "una captura fuera de las bases se resuelve tal cual")
	_check(Rutas.resolver("res://Assets/png/__no_existe__.png", ASSETS) == "", "una captura que no está en ninguna base no resuelve")
	_check(Rutas.resolver("%s/__no_existe__.png" % ASSETS) == "", "una captura propia inexistente no resuelve")
	_check(Rutas.resolver("") == "", "resolver con ruta vacía devuelve vacío")


func _d_en_base() -> void:
	_check(Rutas.en_base("user://Assets/png/a.png", Rutas.ASSETS_USER), "una captura de la base de escritura es propia")
	_check(Rutas.en_base("user://Assets/jpg/a.jpg", Rutas.ASSETS_USER), "una captura jpg de la base de escritura es propia")
	_check(not Rutas.en_base("res://Assets/png/no-disponible.png", Rutas.ASSETS_USER), "una captura del paquete nunca es propia (#50)")
	_check(not Rutas.en_base("user://Assets/otra/a.png", Rutas.ASSETS_USER), "una carpeta que no es png ni jpg no cuenta")
	_check(not Rutas.en_base("", Rutas.ASSETS_USER), "una ruta vacía no es propia")
	_check(Rutas.en_base("%s/png/a.png" % ASSETS, ASSETS), "la comprobación respeta la base de escritura aislada")


func _e_escribible() -> void:
	_check(Rutas.es_escribible("user://__test_rutas__/x.json"), "user:// siempre es escribible")
	_check(not Rutas.es_escribible("res://__test_rutas_ausente__/x.json"), "una carpeta que no existe no es escribible")
	_check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://__test_rutas_ausente__")), "la comprobación no crea la carpeta que sonda")
	_check(Rutas.es_escribible(Rutas.CATALOGO_RES), "en desarrollo res://data sí admite escritura")
	_check(not FileAccess.file_exists(Rutas.CATALOGO_RES + ".escribible"), "la comprobación no deja el fichero sonda (#50)")


func _f_main() -> void:
	var main := MainScript.new()
	_check(main.DATA_RES == Rutas.CATALOGO_RES, "Main lee el catálogo base de res://data (#50)")
	_check(main.ASSETS_BASE == Rutas.ASSETS_USER, "Main escribe las capturas en user://Assets (#50)")
	main.free()


func _crear_png(ruta: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta.get_base_dir()))
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	if img.save_png(ProjectSettings.globalize_path(ruta)) != OK:
		return ""
	return ruta


func _cerrar() -> void:
	Ayuda.borrar_arbol(BASE)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
