extends RefCounted

const RutasScript := preload("res://scripts/rutas.gd")
const EstadoStoreScript := preload("res://scripts/estado_store.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const ColaStoreScript := preload("res://scripts/cola_store.gd")
const PresetsStoreScript := preload("res://scripts/presets_store.gd")
const InstantaneaStoreScript := preload("res://scripts/instantanea_store.gd")

const MARCA := "GestorAO smoke OK"
const ARGUMENTO := "--smoke"
const SONDA := "user://__smoke__.txt"
const ESCENAS := [
	"res://scenes/Main.tscn",
	"res://scenes/Dashboard.tscn",
	"res://scenes/Preferencias.tscn",
	"res://scenes/AgregarEnlace.tscn",
	"res://scenes/Historial.tscn",
	"res://scenes/Cambios.tscn",
	"res://scenes/ListItem.tscn",
	"res://scenes/GridItem.tscn",
	"res://scenes/FilaTabla.tscn",
	"res://scenes/TarjetaKpi.tscn",
]
# Solo recursos que la app carga en ejecucion. icon.ico e icon.icns se quedan</path>
# fuera a proposito: no son recursos de Godot, los incrusta el exportador en el
# ejecutable y ResourceLoader no tiene loader para ellos.
const RECURSOS := [
	"res://Assets/icon/icon.svg",
	"res://Assets/icon/icon_256.png",
	"res://Assets/icon/flag_es.svg",
	"res://Assets/icon/flag_gb.svg",
	"res://Assets/banderas/es.svg",
	"res://Assets/banderas/gb.svg",
]
const STORES := [
	["estado", EstadoStoreScript],
	["config", ConfigStoreScript],
	["cola", ColaStoreScript],
	["presets", PresetsStoreScript],
	["instantaneas", InstantaneaStoreScript],
]


static func pedido(argumentos: PackedStringArray = PackedStringArray()) -> bool:
	var lista := argumentos if not argumentos.is_empty() else OS.get_cmdline_user_args()
	return lista.has(ARGUMENTO)


static func arrancar_desde_consola(arbol: SceneTree) -> bool:
	if not pedido():
		return false
	var res := ejecutar()
	for linea in res.get("lineas", []):
		print(linea)
	var ok := bool(res.get("ok", false))
	if ok:
		print(MARCA)
	if arbol != null:
		arbol.quit(0 if ok else 1)
	return true


static func ejecutar(escenas: Array = ESCENAS, recursos: Array = RECURSOS, stores: Array = STORES, sonda: String = SONDA) -> Dictionary:
	var fallos: Array = []
	fallos.append_array(_sonda_escritura(sonda))
	fallos.append_array(_recursos(recursos))
	fallos.append_array(_escenas(escenas))
	fallos.append_array(_stores(stores))
	var lineas: Array = []
	for fallo in fallos:
		lineas.append("SMOKE FALLO: %s" % fallo)
	lineas.append("SMOKE: %d comprobacion(es) fallida(s)" % fallos.size())
	return {"ok": fallos.is_empty(), "fallos": fallos, "lineas": lineas}


static func _sonda_escritura(sonda: String) -> Array:
	# No se crea la carpeta a proposito: si user:// fuese de solo lectura, o
	# apuntase dentro del pck, esta es la comprobacion que lo dice.
	var f := FileAccess.open(sonda, FileAccess.WRITE)
	if f == null:
		return ["no se puede escribir en user:// (%s)" % sonda]
	f.store_string(MARCA)
	f.close()
	var leido := FileAccess.get_file_as_string(sonda)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sonda))
	if leido != MARCA:
		return ["lo escrito en user:// no se lee igual"]
	return []


static func _recursos(recursos: Array) -> Array:
	var fallos: Array = []
	for ruta in recursos:
		# Ojo: FileAccess.file_exists() miente dentro de un pck. Un recurso
		# importado se guarda como res://Assets/....png.remap mas su .ctex, no con
		# el nombre original, asi que el fichero no existe aunque la textura si.
		# Lo que importa es si la app puede usarla, y eso lo responde load().
		if ResourceLoader.load(ruta) == null:
			fallos.append("falta el recurso %s" % ruta)
	if ResourceLoader.load(RutasScript.PLACEHOLDER) == null:
		fallos.append("falta la captura de reserva %s" % RutasScript.PLACEHOLDER)
	return fallos


static func _escenas(escenas: Array) -> Array:
	var fallos: Array = []
	for ruta in escenas:
		if not ResourceLoader.exists(ruta):
			fallos.append("falta la escena %s" % ruta)
			continue
		var packed: PackedScene = load(ruta)
		if packed == null:
			fallos.append("la escena %s no carga" % ruta)
			continue
		if not packed.can_instantiate():
			fallos.append("la escena %s no se puede instanciar" % ruta)
			continue
		var nodo := packed.instantiate()
		if nodo == null:
			fallos.append("la escena %s no instancia" % ruta)
			continue
		nodo.free()
	return fallos


static func _stores(stores: Array) -> Array:
	var fallos: Array = []
	for entrada in stores:
		var nombre := str(entrada[0])
		var script = entrada[1] if entrada.size() > 1 else null
		# Sin este instanceof, llamar new() sobre algo que no es un script revienta
		# con un error de runtime que se lleva por delante el informe entero.
		if not (script is Script):
			fallos.append("el store %s no es un script" % nombre)
			continue
		var store = script.new("user://__smoke_%s__/" % nombre)
		if store == null or not store.has_method("cargar"):
			fallos.append("el store %s no carga" % nombre)
			continue
		var dato: Variant = store.cargar()
		if typeof(dato) != TYPE_DICTIONARY and typeof(dato) != TYPE_ARRAY:
			fallos.append("el store %s devuelve %s en vez de datos" % [nombre, type_string(typeof(dato))])
	return fallos
