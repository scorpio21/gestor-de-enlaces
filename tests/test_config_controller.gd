extends SceneTree

const ConfigControllerScript := preload("res://scripts/config_controller.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const BASE := "user://__test_config_ctrl__"

var _fallos := 0


func _initialize() -> void:
	_limpiar_base()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	_claves()
	var store = ConfigStoreScript.new(BASE)
	var ctrl = ConfigControllerScript.new()
	_fusionar(ctrl)
	_guardar(ctrl, store)
	_limpiar_base()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _claves() -> void:
	var store = ConfigStoreScript.new(BASE)
	var nombres: Array = []
	for metodo in store.get_method_list():
		if str(metodo.get("name", "")) == "guardar":
			for arg in metodo.get("args", []):
				nombres.append(str(arg.get("name", "")))
			break
	_check(nombres.size() == ConfigControllerScript.CLAVES.size(), "CLAVES tiene tantos elementos como argumentos tiene guardar(): %d vs %d" % [ConfigControllerScript.CLAVES.size(), nombres.size()])
	_check(nombres == ConfigControllerScript.CLAVES, "el orden de CLAVES es el de los argumentos de guardar(): %s vs %s" % [str(ConfigControllerScript.CLAVES), str(nombres)])
	_check(ConfigControllerScript.CLAVES.has("aceptar_certificados"), "CLAVES incluye los tres campos anadidos en #56")
	_check(ConfigControllerScript.CLAVES.has("instantaneas_dias") and str(ConfigControllerScript.CLAVES[-1]) == "instantaneas_dias", "CLAVES anade instantaneas_dias al final (#60)")


func _fusionar(ctrl) -> void:
	var base := {"paralelismo": 5, "tema": "oscuro", "idioma": "es", "aceptar_certificados": true, "instantaneas_dias": 90, "extra": "no tocar"}
	var fusionado: Dictionary = ctrl.fusionar(base, {"tema": "claro", "busqueda": "srv", "instantaneas_dias": 30, "inventada": 1})
	_check(fusionado.get("tema") == "claro", "fusionar sustituye la clave indicada")
	_check(fusionado.get("busqueda") == "srv", "fusionar anade una clave que no estaba")
	_check(fusionado.get("paralelismo") == 5, "fusionar conserva lo que no se toca")
	_check(fusionado.get("aceptar_certificados") == true, "fusionar conserva los campos que anadio #56")
	_check(int(fusionado.get("instantaneas_dias", 0)) == 30, "fusionar cambia la retencion de instantaneas (#60)")
	_check(fusionado.get("extra") == "no tocar", "fusionar deja intactas las claves que no son de la config")
	_check(not fusionado.has("inventada"), "fusionar ignora una clave que no existe en la config (#62)")
	_check(base.get("tema") == "oscuro", "fusionar no modifica el diccionario base")
	_check(ctrl.fusionar(base, {}).size() == base.size(), "fusionar con cambios vacios devuelve el mismo tamaño")


func _guardar(ctrl, store) -> void:
	_check(ctrl.guardar(store, {}), "guardar sin cambios no falla")

	store.guardar(3, 10.0, true, 0, "oscuro", "", "", 1, "es", 0, 0, "", "", "", 0, "and", "lista", true, true, false, 90)
	_check(ctrl.guardar(store, {"busqueda": "glaciar"}), "se puede cambiar un filtro sin perder la retencion (#60)")
	_check(int(store.cargar().get("instantaneas_dias", 0)) == 90, "persistir un filtro ya no borra instantaneas_dias (#60)")
	_check(ctrl.guardar(store, {"instantaneas_dias": 5}), "se puede cambiar la retencion de instantaneas (#60)")
	_check(int(store.cargar().get("instantaneas_dias", 0)) == 30, "una retencion ridicula sube al minimo de 30 dias (#60)")

	store.guardar(3, 10.0, true, 0, "oscuro", "", "", 1, "es", 0, 0, "", "", "", 0, "and", "lista", true, true, false)
	_check(ctrl.guardar(store, {"orden_columna": "fecha", "orden_direccion": -1}), "guardar devuelve lo que devuelve el store")
	var guardado: Dictionary = store.cargar()
	_check(guardado.get("orden_columna") == "fecha" and int(guardado.get("orden_direccion", 0)) == -1, "el criterio de orden se guarda")
	_check(guardado.get("tema") == "oscuro" and guardado.get("paralelismo") == 3, "los campos no tocados sobreviven al guardado (#62)")

	store.guardar(3, 10.0, true, 0, "oscuro", "", "", 1, "es", 0, 0, "", "", "", 0, "and", "lista", true, true, true)
	_check(ctrl.guardar(store, {"busqueda": "glaciar"}), "se puede cambiar solo un filtro")
	_check(store.cargar().get("aceptar_certificados") == true, "persistir un filtro ya no borra aceptar_certificados (#62)")

	store.guardar(3, 10.0, true, 0, "oscuro", "", "", 1, "es", 0, 0, "", "glaciar", "", 0, "and", "lista", false, false, true)
	ctrl.guardar(store, {"filtro_dias": 30})
	var tras_dias: Dictionary = store.cargar()
	_check(int(tras_dias.get("filtro_dias", 0)) == 30, "el filtro por dias se guarda")
	_check(tras_dias.get("reintentar_transitorios") == false, "persistir un filtro ya no repone reintentar_transitorios a true (#62)")
	_check(tras_dias.get("aceptar_certificados") == true, "persistir un filtro ya no borra aceptar_certificados (#62)")
	_check(tras_dias.get("busqueda") == "glaciar", "persistir un filtro conserva el filtro anterior (#62)")

	_check(ctrl.guardar(store, {"idioma": "xx"}) == false, "un idioma invalido hace fallar el guardado y no pisa el archivo")
	_check(store.cargar().get("idioma") == "es", "tras un guardado fallido la config sigue como estaba")

	store.guardar(3, 10.0, true, 0, "oscuro", "0.1.9", "nombre", 1, "es", 0, 0, "", "", "", 0, "and", "lista", true, true, false)
	ctrl.guardar(store, {"ultima_version_vista": "0.2.0"})
	var tras_version: Dictionary = store.cargar()
	_check(tras_version.get("ultima_version_vista") == "0.2.0", "persistir la version vista guarda la version")
	_check(tras_version.get("orden_columna") == "nombre", "persistir la version vista conserva el criterio (#17)")

	_check(ctrl.guardar(null, {"tema": "claro"}) == false, "sin store, guardar devuelve false en vez de reventar")

	var otro = ConfigStoreScript.new(BASE + "/otro")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE + "/otro"))
	_check(ctrl.guardar(otro, {"tema": "claro"}), "el store se usa como argumento, no se cachea (#62)")
	_check(otro.cargar().get("tema") == "claro", "el cambio de store afecta de verdad al guardado (#62)")
	_check(store.cargar().get("tema") == "oscuro", "el store viejo queda intacto")
	_check(ctrl.guardar(store, {"tema": "oscuro"}), "guardar sigue funcionando tras un store nulo")
	_check(store.cargar().get("tema") == "oscuro", "el tema se guarda en la ruta normal")


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _limpiar_base() -> void:
	for ruta in ["config.json", "otro/config.json"]:
		if FileAccess.file_exists("%s/%s" % [BASE, ruta]):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [BASE, ruta]))
	if DirAccess.dir_exists_absolute(BASE + "/otro"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BASE + "/otro"))
	if DirAccess.dir_exists_absolute(BASE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BASE))
