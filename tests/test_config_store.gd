extends SceneTree

const ConfigStore := preload("res://scripts/config_store.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
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
	_check(idioma_default_sin_fichero(), "sin fichero devuelve idioma vacío")
	_check(idioma_persistido(), "guardar() persiste el idioma")
	_check(idioma_invalido_rechaza(), "idioma no válido rechaza el guardado")
	_check(idioma_manualmente_invalido_normaliza(), "idioma inválido en fichero se normaliza a vacío")
	_check(filtros_default_sin_fichero(), "sin fichero filtros por defecto (Todos/Todas/vacío)")
	_check(filtros_persistidos(), "guardar() persiste estado, categoría y búsqueda")
	_check(filtro_estado_invalido_normaliza(), "filtro de estado fuera de rango se clampea")
	_check(filtro_categoria_invalida_normaliza(), "filtro de categoría fuera de rango se clampea")
	_check(filtro_etiqueta_default_sin_fichero(), "sin fichero filtro de etiqueta vacío")
	_check(filtro_etiqueta_persistida(), "guardar() persiste el filtro de etiqueta")
	_check(filtro_etiqueta_no_string_normaliza(), "filtro de etiqueta no-string cae a vacía")
	_check(busqueda_no_string_normaliza(), "búsqueda no-string cae a vacía")
	_check(filtro_codigo_default_sin_fichero(), "sin fichero filtro de código vacío")
	_check(filtros_avanzados_persistidos(), "guardar() persiste código, días y modo de búsqueda")
	_check(filtro_dias_invalido_normaliza(), "días fuera de rango se clampea")
	_check(busqueda_modo_invalido_normaliza(), "modo de búsqueda inválido vuelve a and")
	_check(vista_default_sin_fichero(), "sin fichero la vista es lista")
	_check(vista_persistida(), "guardar() persiste la vista de grilla")
	_check(vista_invalida_normaliza(), "vista inválida vuelve a lista")
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


func idioma_default_sin_fichero() -> bool:
	return ConfigStore.new(BASE).cargar().get("idioma", "#") == ""


func idioma_persistido() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "en"):
		return false
	return store.cargar().get("idioma", "#") == "en"


func idioma_invalido_rechaza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es")
	return not store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "fr") \
		and store.cargar().get("idioma", "#") == "es"


func idioma_manualmente_invalido_normaliza() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"idioma": "xx"}')
	return ConfigStore.new(BASE).cargar().get("idioma", "#") == ""


func filtros_default_sin_fichero() -> bool:
	var c := ConfigStore.new(BASE).cargar()
	return c.get("filtro_estado", -1) == 0 and c.get("filtro_categoria", -1) == 0 and c.get("busqueda", "#") == ""


func filtros_persistidos() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "", "fecha", 1, "es", 2, 3, "glaciar", "srv"):
		return false
	var c := store.cargar()
	return c.get("filtro_estado", -1) == 2 and c.get("filtro_categoria", -1) == 3 \
		and c.get("filtro_etiqueta", "#") == "glaciar" and c.get("busqueda", "#") == "srv"


func filtro_estado_invalido_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 99, 0, "")
	var alto: bool = store.cargar().get("filtro_estado", -1) == 3
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", -7, 0, "")
	return alto and store.cargar().get("filtro_estado", -1) == 0


func filtro_categoria_invalida_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, 99, "")
	var alto: bool = store.cargar().get("filtro_categoria", -1) == GestorCatalogoScript.CATEGORIAS.size()
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, -3, "")
	return alto and store.cargar().get("filtro_categoria", -1) == 0


func filtro_etiqueta_default_sin_fichero() -> bool:
	return ConfigStore.new(BASE).cargar().get("filtro_etiqueta", "#") == ""


func filtro_etiqueta_persistida() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, 0, "glaciar", ""):
		return false
	return store.cargar().get("filtro_etiqueta", "#") == "glaciar"


func filtro_etiqueta_no_string_normaliza() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"filtro_etiqueta": 42}')
	return ConfigStore.new(BASE).cargar().get("filtro_etiqueta", "#") == ""


func busqueda_no_string_normaliza() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"busqueda": 42}')
	return ConfigStore.new(BASE).cargar().get("busqueda", "#") == ""


func filtro_codigo_default_sin_fichero() -> bool:
	return ConfigStore.new(BASE).cargar().get("filtro_codigo", "#") == ""


func filtros_avanzados_persistidos() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, 0, "", "", "404", 30, "or"):
		return false
	var c := store.cargar()
	return c.get("filtro_codigo", "#") == "404" and c.get("filtro_dias", -1) == 30 \
		and c.get("busqueda_modo", "#") == "or"


func filtro_dias_invalido_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, 0, "", "", "", 99999, "and")
	var alto: bool = store.cargar().get("filtro_dias", -1) == 3650
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, 0, "", "", "", -5, "and")
	return alto and store.cargar().get("filtro_dias", -1) == 0


func busqueda_modo_invalido_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, 0, "", "", "", 0, "xor")
	return store.cargar().get("busqueda_modo", "#") == "and"


func vista_default_sin_fichero() -> bool:
	return ConfigStore.new(BASE).cargar().get("vista", "#") == "lista"


func vista_persistida() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, 0, "", "", "", 0, "and", "grilla"):
		return false
	return store.cargar().get("vista", "#") == "grilla"


func vista_invalida_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "", 1, "es", 0, 0, "", "", "", 0, "and", "mosaico")
	return store.cargar().get("vista", "#") == "lista"


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE + "/config.json")
