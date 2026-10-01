extends SceneTree

const CambiosControllerScript := preload("res://scripts/cambios_controller.gd")
const Ayuda := preload("res://tests/ayuda.gd")
const BASE := "user://__test_cambios_ctl__"

var _fallos := 0
var _ctrl = CambiosControllerScript.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	_ctrl.ruta = "%s/pendientes.json" % BASE
	_marca_de_tipo()
	_registro_y_marcas()
	_nombres_de_entradas()
	_pendientes_en_disco()
	_cobertura()
	_ruta_ilegible()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _cambio(clave: String, tipo: String) -> Dictionary:
	return {"clave": clave, "tipo": tipo}


func _marca_de_tipo() -> void:
	var ctrl = CambiosControllerScript.new()
	ctrl.registrar([_cambio("a.test", "nuevo_caido"), _cambio("b.test", "recuperado")])
	_check(ctrl.marca_de("a.test") == "caido", "un nuevo caido se marca en rojo")
	_check(ctrl.marca_de("b.test") == "valido", "un recuperado se marca en verde")
	_check(ctrl.marca_de("c.test") == "", "una clave sin cambio no se marca")

	ctrl.registrar([_cambio("a.test", "reubicado")])
	_check(ctrl.marca_de("a.test") == "aviso", "un reubicado se marca en ambar")
	_check(ctrl.marca_de("b.test") == "", "un registro nuevo borra las marcas viejas")

	ctrl.registrar([_cambio("a.test", "sin_cambios")])
	_check(ctrl.marca_de("a.test") == "", "sin_cambios no deja marca")

	ctrl.registrar(["basura", 7, {}])
	_check(ctrl.marca_de("") == "", "registrar tolera basura sin reventar")
	_check(ctrl.claves().is_empty(), "la basura no genera marcas")


func _registro_y_marcas() -> void:
	var ctrl = CambiosControllerScript.new()
	_check(not ctrl.vistos(), "nada se ha visto todavia")
	_check(ctrl.pendientes_al_salir().is_empty(), "sin registro no hay nada que recordar")

	var cambios := ctrl.nuevo_delta(
		{"a.test": {"valido": true, "mensaje": "OK", "codigo": 200}},
		{"a.test": {"valido": false, "mensaje": "Connection refused", "codigo": 0, "fecha": 5}}
	)
	_check(cambios.size() == 1, "nuevo_delta detecta el cambio")
	_check(ctrl.marca_de("a.test") == "caido", "nuevo_delta deja la marca puesta")
	_check(ctrl.pendientes_al_salir().size() == 1, "lo pendiente sale de las marcas")
	_check(str(ctrl.pendientes_al_salir()[0].get("clave", "")) == "a.test", "lo pendiente lleva la clave")

	ctrl.marcar_vistos()
	_check(ctrl.vistos(), "marcar_vistos lo anota")
	_check(ctrl.pendientes_al_salir().size() == 1, "lo pendiente se conserva hasta salir")


func _nombres_de_entradas() -> void:
	var ctrl = CambiosControllerScript.new()
	var nombres: Dictionary = ctrl.nombres_de([
		{"url": "https://A.test/Uno", "nombre": "Servidor Principal"},
		{"url": "http://b.test", "nombre": "Segundo"},
		"basura",
	])
	_check(nombres.size() == 2, "clave_unica normaliza esquema, mayusculas y puerto por defecto")
	_check(str(nombres.get("a.test/Uno", "")) == "Servidor Principal", "cada clave guarda su nombre")
	_check(str(nombres.get("b.test", "")) == "Segundo", "y el segundo enlace tambien")
	_check(not nombres.has("https://A.test/Uno"), "la clave no lleva esquema")
	_check(ctrl.nombres_de([]).is_empty(), "sin entradas no hay nombres")
	_check(ctrl.nombres_de(["basura", 7]).is_empty(), "entradas que no son diccionarios se ignoran")


func _pendientes_en_disco() -> void:
	_ctrl.borrar_pendientes()
	_check(_ctrl.leer_pendientes().is_empty(), "sin fichero no hay pendientes")
	_check(_ctrl.guardar_pendientes([]), "guardar una lista vacia es correcto")
	_check(_ctrl.leer_pendientes().is_empty(), "una lista vacia guardada se lee vacia")

	var cambios := [_cambio("a.test", "nuevo_caido"), _cambio("b.test", "recuperado")]
	_check(_ctrl.guardar_pendientes(cambios), "guardar pendientes escribe")
	var leidos: Array = _ctrl.leer_pendientes()
	_check(leidos.size() == 2, "los pendientes vuelven del disco")
	_check(str(leidos[0].get("clave", "")) == "a.test", "el pendiente conserva su clave")
	_check(_ctrl.guardar_pendientes([1, 2]), "guardar numeros tambien funciona")
	_check(_ctrl.leer_pendientes().size() == 2, "y se leen")

	var archivo := FileAccess.open(_ctrl.ruta, FileAccess.WRITE)
	archivo.store_string("esto no es un array")
	archivo.close()
	_check(_ctrl.leer_pendientes().is_empty(), "un fichero corrupto no rompe la app")
	_check(_ctrl.borrar_pendientes(), "borrar pendientes elimina el fichero")
	_check(_ctrl.borrar_pendientes(), "borrar sin fichero no falla")


func _ruta_ilegible() -> void:
	var ctrl = CambiosControllerScript.new()
	ctrl.ruta = "%s/no-existe-dir/pendientes.json" % BASE
	_check(not ctrl.guardar_pendientes([1]), "guardar en una ruta imposible avisa")
	_check(ctrl.leer_pendientes().is_empty(), "leer de una ruta imposible devuelve nada")
	_check(ctrl.borrar_pendientes(), "borrar de una ruta imposible no falla")


func _cobertura() -> void:
	var ctrl = CambiosControllerScript.new()
	_check(ctrl.cobertura_de({}) == 0, "sin estados no hay cobertura")
	var estados := {"a.test": {"valido": true, "historial": [{"fecha": 800}, {"fecha": 300}]}}
	_check(ctrl.cobertura_de(estados) == 300, "la cobertura es la fecha mas antigua")


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)