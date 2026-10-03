extends SceneTree

const InstantaneaStore := preload("res://scripts/instantanea_store.gd")
const DashboardStore := preload("res://scripts/dashboard_store.gd")
const BASE := "user://__test_instantanea__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	limpiar_base()
	_guardar_y_reemplazar()
	_detalle_de_la_foto()
	_retention()
	_catalogo_vacio()
	_basura()
	_normalizar()
	_ayuda()
	limpiar_base()
	_cerrar()


func _entradas() -> Array:
	return [
		{"nombre": "A", "url": "https://a.test/1", "cat": "cliente"},
		{"nombre": "B", "url": "https://b.test/2", "cat": "cliente"},
		{"nombre": "C", "url": "https://c.test/3", "cat": "otro"},
		{"nombre": "D", "url": "https://d.test/4"},
	]


func _estados() -> Dictionary:
	return {
		"a.test/1": {"valido": true},
		"b.test/2": {"valido": false},
	}


func _guardar_y_reemplazar() -> void:
	var store := InstantaneaStore.new(BASE)
	_check(store.cargar().is_empty(), "sin fichero, cargar devuelve una lista vacía (#60)")
	_check(store.ruta() == BASE + "/instantaneas.json", "la instantánea vive en instantaneas.json (#60)")

	var res: Dictionary = store.guardar(_entradas(), _estados())
	_check(res.get("ok", false) and res.get("guardada", false), "guardar() escribe la instantánea de hoy (#60)")
	_check(str(res.get("fecha", "")) == DashboardStore.clave_de_dia(int(Time.get_unix_time_from_system())), "la instantánea se fecha con el día de hoy (#60)")
	var lista: Array = store.cargar()
	_check(lista.size() == 1, "tras un escaneo hay una sola foto del catálogo (#60)")

	var res2: Dictionary = store.guardar(_entradas(), _estados())
	var lista2: Array = store.cargar()
	_check(lista2.size() == 1, "comprobar dos veces el mismo día no acumula filas (#60)")
	_check(res2.get("reemplazo", false), "la segunda comprobación del día se marca como reemplazo (#60)")
	_check(store.escrituras == 2, "cada comprobación escribe una vez (#60): %d" % store.escrituras)

	var otro := InstantaneaStore.new(BASE)
	_check(otro.cargar().size() == 1, "otra instancia del store lee la misma foto (#60)")
	_check(otro.guardar(_entradas(), _estados()).get("fecha", "") == str(res2.get("fecha", "")), "el día es el mismo para cualquier instancia (#60)")


func _detalle_de_la_foto() -> void:
	var fila := InstantaneaStore.fila_de(_entradas(), _estados(), "2026-09-01")
	_check(int(fila.get("total", 0)) == 4, "la foto cuenta los enlaces del catálogo (#60)")
	_check(int(fila.get("validos", 0)) == 1, "la foto cuenta los válidos (#60)")
	_check(int(fila.get("caidos", 0)) == 1, "la foto cuenta los caídos (#60)")
	_check(int(fila.get("sin_comprobar", 0)) == 2, "la foto cuenta los sin comprobar, el `null` de #54 incluido (#60)")

	var con_red: Dictionary = {"a.test/1": {"valido": null}, "b.test/2": {"valido": false}, "c.test/3": {"valido": true}}
	var con_red_fila := InstantaneaStore.fila_de(_entradas(), con_red, "2026-09-01")
	_check(int(con_red_fila.get("sin_comprobar", 0)) == 2, "un fallo de red cuenta como sin comprobar, no como válido (#60)")
	_check(int(con_red_fila.get("validos", 0)) == 1, "un fallo de red no cuenta como válido en la foto (#60)")


func _retention() -> void:
	var store := InstantaneaStore.new(BASE)
	var hoy := DashboardStore.clave_de_dia(int(Time.get_unix_time_from_system()))
	_escribir_filas(store, [
		_hace(500), _hace(400), _hace(200), _hace(100), _hace(30), _hace(2), hoy,
	])
	_check(store.cargar().size() == 7, "las siete filas historicas se leen (#60)")

	var res: Dictionary = store.purgar(365)
	_check(res.get("borradas") == 2, "purgar(365) descarta lo que pasa de 364 dias (#60): %s" % str(res.get("borradas")))
	_check(int(res.get("quedan", 0)) == 5, "purgar(365) informa de cuantas filas quedan (#60)")
	_check(store.cargar().size() == 5, "la purga se escribe en disco (#60)")

	var res2: Dictionary = store.purgar(365)
	_check(res2.get("borradas") == 0, "purgar dos veces no borra de mas (#60)")

	var minima: int = InstantaneaStore.limite_ok(1)
	_check(minima == InstantaneaStore.LIMITE_MIN, "un limite ridiculo sube al minimo (#60): %d" % minima)
	var maxima: int = InstantaneaStore.limite_ok(99999)
	_check(maxima == InstantaneaStore.LIMITE_MAX, "un limite enorme baja al maximo (#60): %d" % maxima)
	_check(InstantaneaStore.limite_ok("muchos") == InstantaneaStore.LIMITE_DEFAULT, "un limite que no es numero usa el de por defecto (#60)")
	_check(InstantaneaStore.limite_ok(90) == 90, "un limite sensato se respeta (#60)")

	var recortado := store.purgar(InstantaneaStore.LIMITE_MIN)
	_check(int(recortado.get("borradas", 0)) == 3, "con el limite minimo solo quedan los ultimos 30 dias (#60): %s" % str(recortado.get("borradas")))
	_check(store.cargar().size() == 2, "purgar al minimo deja la foto de hoy y la de anteayer (#60)")

	_borde()


func _borde() -> void:
	var store := InstantaneaStore.new(BASE)
	_escribir_filas(store, [_hace(31), _hace(30), _hace(29), _hace(0)])
	var res: Dictionary = store.purgar(31)
	_check(int(res.get("borradas", 0)) == 1, "con limite 31 se cae justo la fila de hace 31 dias (#60): %s" % str(res.get("borradas")))
	var fechas: Array = []
	for fila in store.cargar():
		fechas.append(str(fila.get("fecha", "")))
	_check(not fechas.has(_hace(31)), "la fila que rebasa el limite se borra (#60)")
	_check(fechas.has(_hace(30)), "la fila del ultimo dia del limite se conserva (#60)")
	_check(store.purgar(3650).get("borradas") == 0, "un limite enorme no borra nada (#60)")
	_check(int(store.purgar(6).get("borradas", 0)) == 1, "purgar(6) se comporta como purgar(30) y no como purgar(6) (#60)")
	_check(store.cargar().size() == 2, "el minimo de 30 dias protege las fotos recientes (#60)")


func _catalogo_vacio() -> void:
	var store := InstantaneaStore.new(BASE)
	var antes: int = store.escrituras
	var res: Dictionary = store.guardar([], {})
	_check(res.get("guardada") == false, "un catalogo vacio no se fotografia (#60)")
	_check(store.escrituras == antes, "un catalogo vacio ni siquiera toca el fichero (#60)")
	_check(res.get("ok", false), "un catalogo vacio no es un error (#60)")


func _basura() -> void:
	var store := InstantaneaStore.new(BASE)
	FileAccess.open(BASE + "/instantaneas.json", FileAccess.WRITE).store_string("esto no es json")
	_check(store.cargar().is_empty(), "un fichero corrupto se lee como vacio (#60)")

	FileAccess.open(BASE + "/instantaneas.json", FileAccess.WRITE).store_string(JSON.stringify({
		"fecha": "ayer", "total": 3, "validos": 1, "caidos": 1, "sin_comprobar": 1,
	}))
	_check(store.cargar().is_empty(), "un objeto con una fecha invalida se descarta (#60)")

	FileAccess.open(BASE + "/instantaneas.json", FileAccess.WRITE).store_string(JSON.stringify([
		"basura", 7, {"fecha": "2026-13-45"}, {"fecha": DashboardStore.clave_de_dia(int(Time.get_unix_time_from_system())), "total": 4, "validos": 3, "caidos": 1},
	]))
	var lista: Array = store.cargar()
	_check(lista.size() == 1, "de una lista mezclada solo se queda la fila con fecha valida (#60)")
	_check(int(lista[0].get("total", 0)) == 4, "la fila valida conserva sus numeros (#60)")

	FileAccess.open(BASE + "/instantaneas.json", FileAccess.WRITE).store_string(JSON.stringify([
		{"fecha": "2026-09-02", "total": 4, "validos": 2, "caidos": 1},
		{"fecha": "2026-09-02", "total": 4, "validos": 3, "caidos": 1},
	]))
	_check(store.cargar().size() == 1, "dos filas del mismo dia se colapsan en una (#60)")


func _normalizar() -> void:
	var fila := InstantaneaStore.normalizar({"fecha": "2026-09-01", "total": 10, "validos": 99, "caidos": -3, "sin_comprobar": 50})
	_check(int(fila.get("validos", 0)) == 10, "normalizar recorta los validos al total (#60)")
	_check(int(fila.get("caidos", 0)) == 0, "normalizar recorta un negativo a cero (#60)")
	_check(int(fila.get("sin_comprobar", 0)) == 0, "normalizar no deja sin comprobar mas de los que sobran (#60)")
	_check(InstantaneaStore.normalizar("nada").is_empty(), "normalizar devuelve vacio si no es un diccionario (#60)")
	_check(InstantaneaStore.normalizar({"total": 3}).is_empty(), "normalizar devuelve vacio si no hay fecha (#60)")

	_check(InstantaneaStore.fecha_valida("2026-09-01"), "una fecha bien formada es valida (#60)")
	_check(not InstantaneaStore.fecha_valida("2026-9-1"), "una fecha sin ceros no vale (#60)")
	_check(not InstantaneaStore.fecha_valida("2026-13-01"), "un mes imposible no vale (#60)")
	_check(not InstantaneaStore.fecha_valida("2026-09-32"), "un dia imposible no vale (#60)")
	_check(InstantaneaStore.fecha_valida("2026-02-29"), "un 29 de febrero se acepta (#60)")
	_check(InstantaneaStore.fecha_a_unix("basura") == 0, "una fecha invalida no se convierte a unix (#60)")
	_check(InstantaneaStore.fecha_a_unix("2026-09-01") > InstantaneaStore.fecha_a_unix("2026-08-31"), "las fechas se ordenan tambien en unix (#60)")
	_check(InstantaneaStore.fecha_a_unix("2026-09-01") - InstantaneaStore.fecha_a_unix("2026-08-31") == 86400, "un dia son 86400 segundos (#60)")


func _ayuda() -> void:
	_check(InstantaneaStore.normalizar({"fecha": "2026-09-01", "total": 0}).get("fecha", "") == "2026-09-01", "normalizar respeta una fecha buena (#60)")
	var store := InstantaneaStore.new("user://sin_carpeta_instantaneas/")
	var res: Dictionary = store.guardar(_entradas(), _estados())
	_check(res.get("ok", false), "guardar crea la carpeta si falta (#60)")
	_check(store.cargar().size() == 1, "lo guardado en una carpeta nueva se lee (#60)")
	_check(store.limpiar(), "limpiar devuelve true (#60)")
	_check(store.cargar().is_empty(), "tras limpiar no queda ninguna foto (#60)")
	_check(store.limpiar(), "limpiar sin fichero devuelve true en vez de fallar (#60)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sin_carpeta_instantaneas"))


func _escribir_filas(store, claves: Array) -> void:
	var filas: Array = []
	for clave in claves:
		filas.append({"fecha": clave, "total": 10, "validos": 7, "caidos": 2, "sin_comprobar": 1})
	FileAccess.open(store.ruta(), FileAccess.WRITE).store_string(JSON.stringify(filas, "\t"))


func _hace(dias: int) -> String:
	return DashboardStore.clave_de_dia(int(Time.get_unix_time_from_system()) - dias * 86400)


func limpiar_base() -> void:
	if DirAccess.dir_exists_absolute(BASE):
		_dir_borrar(BASE)
	DirAccess.make_dir_recursive_absolute(BASE)


func _dir_borrar(ruta: String) -> void:
	var dir := DirAccess.open(ruta)
	if dir == null:
		return
	dir.list_dir_begin()
	var nombre := dir.get_next()
	while nombre != "":
		if dir.current_is_dir():
			_dir_borrar(ruta + "/" + nombre)
		else:
			DirAccess.remove_absolute(ruta + "/" + nombre)
		nombre = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ruta)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("OK   %s" % etiqueta)
	else:
		_fallos += 1
		print("ERROR: FALLO: %s" % etiqueta)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)
