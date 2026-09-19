extends SceneTree

const ColaStore := preload("res://scripts/cola_store.gd")
const BASE := "user://__test_cola__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	limpiar_base()
	var store := ColaStore.new(BASE)

	var vacio: Dictionary = store.cargar()
	_check((vacio.get("urls", []) as Array).is_empty(), "cargar sin fichero devuelve urls vacío")
	_check(int(vacio.get("fecha", -1)) == 0, "cargar sin fichero devuelve fecha 0")

	_check(store.guardar(["a", "b"]), "guardar devuelve true")
	var con_datos: Dictionary = store.cargar()
	_check((con_datos.get("urls", []) as Array) == ["a", "b"] and int(con_datos.get("fecha", 0)) > 0, "cargar recupera las urls y una fecha > 0")

	_check(store.guardar([]), "guardar([]) devuelve true")
	var vaciado: Dictionary = store.cargar()
	_check((vaciado.get("urls", []) as Array).is_empty() and int(vaciado.get("fecha", 0)) > 0, "guardar([]) conserva el intento con fecha")

	_check(store.limpiar(), "limpiar devuelve true")
	var limpio: Dictionary = store.cargar()
	_check((limpio.get("urls", []) as Array).is_empty() and int(limpio.get("fecha", 0)) == 0, "tras limpiar, cargar vuelve a estar vacío")

	var a := ColaStore.new(BASE)
	_check(a.guardar(["x"]), "store A guarda")
	var b := ColaStore.new(BASE)
	_check((b.cargar().get("urls", []) as Array) == ["x"], "store B (nueva instancia) recupera lo guardado por A")

	DirAccess.remove_absolute(BASE + "/colas.json")
	_cerrar()


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func limpiar_base() -> void:
	if FileAccess.file_exists(BASE + "/colas.json"):
		DirAccess.remove_absolute(BASE + "/colas.json")
	if DirAccess.dir_exists_absolute(BASE):
		DirAccess.remove_absolute(BASE)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)