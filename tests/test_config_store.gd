extends SceneTree

const ConfigStore := preload("res://scripts/config_store.gd")
const BASE := "user://__test_config__"

var _fallos := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	_limpiar()
	_check(cargar_vacio(), "sin fichero devuelve defaults")
	_check(guardar_y_recuperar(), "guardar() persiste y cargar() lo recupera")
	_check(config_rota_no_rompe(), "JSON roto devuelve defaults")
	_check(clamp_fuera_de_rango(), "valores fuera de rango se clampean")
	_check(tipos_incorrectos(), "tipos incorrectos devuelven defaults")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func cargar_vacio() -> bool:
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0)


func guardar_y_recuperar() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(5, 20.0):
		return false
	var c := store.cargar()
	return c.get("paralelismo") == 5 and is_equal_approx(c.get("timeout", -1.0), 20.0)


func config_rota_no_rompe() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string("{no es json")
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0)


func clamp_fuera_de_rango() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"paralelismo": 99, "timeout": 0.5}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 8 and is_equal_approx(c.get("timeout", -1.0), 3.0)


func tipos_incorrectos() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"paralelismo": "muchos", "timeout": "lento"}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE + "/config.json")
