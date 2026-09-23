extends SceneTree

const ConfigStore := preload("res://scripts/config_store.gd")
const BASE := "user://__test_config__"

var _fallos := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	_limpiar()
	_check(cargar_vacio(), "sin fichero devuelve defaults")
	_check(config_rota_no_rompe(), "JSON roto devuelve defaults")
	_check(clamp_fuera_de_rango(), "valores fuera de rango se clampean")
	_check(tipos_incorrectos(), "tipos incorrectos devuelven defaults")
	_check(guardar_y_recuperar(), "guardar() persiste y cargar() lo recupera")
	_check(guardar_y_recuperar_auto(), "guardar() persiste auto_abrir e intervalo")
	_check(intervalo_invalido_normaliza(), "intervalo no válido se normaliza a 0")
	_check(auto_invalido_default(), "auto_abrir no booleano vuelve al default true")
	_check(guardar_defaults_auto(), "guardar() sin auto_abrir/intervalo persiste los defaults")
	_check(tema_default_sin_fichero(), "sin fichero devuelve tema oscuro")
	_check(tema_persistido(), "guardar() persiste el tema claro")
	_check(tema_invalido_normaliza(), "tema no válido se normaliza a oscuro")
	_check(ultima_default_sin_fichero(), "sin fichero ultima_version_vista vacía")
	_check(ultima_persistida(), "guardar persiste ultima_version_vista")
	_check(ultima_no_string_normaliza(), "ultima_version_vista no-string cae a vacía")
	_check(orden_default_sin_fichero(), "sin fichero orden_columna vacía y dirección 1")
	_check(orden_persistido(), "guardar() persiste columna y dirección")
	_check(orden_invalida_normaliza(), "columna no válida se normaliza a vacía")
	_check(orden_direccion_invalida_normaliza(), "dirección no válida se normaliza a 1")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func cargar_vacio() -> bool:
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func guardar_y_recuperar() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(5, 20.0):
		return false
	var c := store.cargar()
	return c.get("paralelismo") == 5 and is_equal_approx(c.get("timeout", -1.0), 20.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func guardar_y_recuperar_auto() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(5, 20.0, false, 60):
		return false
	var c := store.cargar()
	return c.get("auto_abrir") == false and c.get("intervalo") == 60


func config_rota_no_rompe() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string("{no es json")
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func clamp_fuera_de_rango() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"paralelismo": 99, "timeout": 0.5}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 8 and is_equal_approx(c.get("timeout", -1.0), 3.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func tipos_incorrectos() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"paralelismo": "muchos", "timeout": "lento"}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func intervalo_invalido_normaliza() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"auto_abrir": true, "intervalo": 7}')
	return ConfigStore.new(BASE).cargar().get("intervalo") == 0


func auto_invalido_default() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"auto_abrir": "si", "intervalo": 30}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("auto_abrir") == true and c.get("intervalo") == 30


func guardar_defaults_auto() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0)
	var c := store.cargar()
	return c.get("auto_abrir") == true and c.get("intervalo") == 0


func tema_default_sin_fichero() -> bool:
	return ConfigStore.new(BASE).cargar().get("tema", "") == "oscuro"


func tema_persistido() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "claro"):
		return false
	return store.cargar().get("tema", "") == "claro"


func tema_invalido_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "chocolate")
	return store.cargar().get("tema", "") == "oscuro"


func ultima_default_sin_fichero() -> bool:
	return ConfigStore.new(BASE).cargar().get("ultima_version_vista", "#") == ""


func ultima_persistida() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "2.0"):
		return false
	return store.cargar().get("ultima_version_vista", "#") == "2.0"


func ultima_no_string_normaliza() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"ultima_version_vista": 42}')
	return ConfigStore.new(BASE).cargar().get("ultima_version_vista", "#") == ""


func orden_default_sin_fichero() -> bool:
	var c := ConfigStore.new(BASE).cargar()
	return c.get("orden_columna", "#") == "" and c.get("orden_direccion", 0) == 1


func orden_persistido() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "", "fecha", -1):
		return false
	var c := store.cargar()
	return c.get("orden_columna", "#") == "fecha" and c.get("orden_direccion", 0) == -1


func orden_invalida_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "tamanyo", 1)
	return store.cargar().get("orden_columna", "#") == ""


func orden_direccion_invalida_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "fecha", 42)
	return store.cargar().get("orden_direccion", 0) == 1


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE + "/config.json")
