extends SceneTree

const AlmacenUno := preload("res://scripts/almacen_uno.gd")
const AlmacenScript := preload("res://scripts/almacen.gd")
const AlmacenController := preload("res://scripts/almacen_controller.gd")
const GestorDatos := preload("res://scripts/gestor_datos.gd")

const BASE := "user://__test_almacen_uno__"
const FICHERO := "gestorao.json"

var _fallos := 0


func _initialize() -> void:
	_limpiar()
	DirAccess.make_dir_recursive_absolute(BASE)
	_check(modo_y_soporte(), "modo() dice unico y el controller lo acepta (#63)")
	_check(rutas_lista_un_solo_fichero(), "rutas() lista un solo fichero de datos (#63)")
	_check(secciones_de_un_fichero(), "todo cabe en un unico JSON: las ocho secciones (#63)")
	_check(entradas_ida_y_vuelta(), "entradas() y guardar_entradas() hacen ida y vuelta (#63)")
	_check(entradas_conservan_esquema(), "entradas() respeta schema_version (#63)")
	_check(estados_con_historial(), "estados() conserva el historial de cada URL (#63)")
	_check(borrados_ida_y_vuelta(), "borrados() hacen ida y vuelta (#63)")
	_check(estados_y_borrados_en_una_escritura(), "estados y borrados se guardan de una vez (#63)")
	_check(cola_ida_y_vuelta(), "cola() conserva urls y fecha (#63)")
	_check(limpiar_cola_no_borra_el_resto(), "limpiar_cola() vacia la cola sin tocar el resto (#63)")
	_check(config_opaca(), "config() devuelve el diccionario tal cual (#63)")
	_check(instantaneas_ida_y_vuelta(), "instantaneas() es una lista de filas (#63)")
	_check(presets_y_cambios(), "presets() y cambios() también (#63)")
	_check(atomicidad_con_bak(), "escribir deja .bak y no deja .tmp (#63)")
	_check(escrituras_cuenta(), "el contador de escrituras sube (#63)")
	_check(abrir_relee_lo_guardado(), "abrir() de nuevo lee lo que habia (#63)")
	_check(fichero_roto_no_rompe(), "un gestoror.json corrupto se lee como vacio (#63)")
	_check(esquema_futuro_no_se_pisa(), "un fichero de una version posterior no se sobreescribe (#63)")
	_limpiar()
	_check(credenciales_desconocidas_se_ignoran(), "una seccion que no se conoce no rompe nada (#63)")
	_limpiar()
	_check(copia_devuelve_todo(), "la copia de seguridad devuelve estados y borrados, no solo el catalogo (#63)")
	_limpiar()
	_check(sin_copia_no_hay_error(), "sin copia previa no hay error, solo que no hay copia (#63)")
	_check(capturas_ida_y_vuelta(), "guardar_captura() copia el byte a byte (#63)")
	_check(borra_captura(), "borrar_captura() borra y no falla si no esta (#63)")
	_check(capturas_ignora_temporales(), "capturas() ignora .import, .tmp y .bak (#63)")
	_check(tamano_total_cuenta(), "tamano_total() suma ficheros y carpetas (#63)")
	_check(abrir_crea_carpeta(), "abrir() crea la base si no existe (#63)")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(ok: bool, texto: String) -> void:
	if ok:
		print("  OK: %s" % texto)
		return
	_fallos += 1
	print("  FALLO: %s" % texto)


func _limpiar() -> void:
	for sufijo in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s%s" % [BASE, FICHERO, sufijo]))
	_borrar_arbol("%s/Assets" % BASE)


func _borrar_arbol(ruta: String) -> void:
	var abs := ProjectSettings.globalize_path(ruta)
	if not DirAccess.dir_exists_absolute(abs):
		return
	var dir := DirAccess.open(abs)
	if dir == null:
		return
	for sub in dir.get_directories():
		_borrar_arbol("%s/%s" % [ruta, sub])
	for f in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [ruta, f]))
	DirAccess.remove_absolute(abs)


func _nuevo() -> RefCounted:
	var a := AlmacenUno.new(BASE)
	a.abrir()
	return a


func _bruto() -> Variant:
	return AlmacenScript.leer_json("%s/%s" % [BASE, FICHERO])


func _secciones() -> Dictionary:
	var dato: Variant = _bruto()
	if typeof(dato) != TYPE_DICTIONARY:
		return {}
	var dentro: Variant = dato.get("secciones", {})
	return dentro if typeof(dentro) == TYPE_DICTIONARY else {}


func modo_y_soporte() -> bool:
	var a := _nuevo()
	return a.modo() == AlmacenScript.MODO_UNICO \
		and AlmacenController.soporta(AlmacenScript.MODO_UNICO) \
		and AlmacenController.soporta(AlmacenScript.MODO_FICHEROS) \
		and not AlmacenController.soporta(AlmacenScript.MODO_BASE_DATOS) \
		and AlmacenController.crear({"modo": "unico", "base": BASE}) != null \
		and AlmacenController.crear({"modo": "base_datos", "base": BASE}) == null


func rutas_lista_un_solo_fichero() -> bool:
	var mapa := AlmacenUno.new(BASE).rutas()
	var ficheros: Array = mapa.get("ficheros", [])
	if ficheros.size() != 1:
		return false
	return str(ficheros[0]) == "%s/%s" % [BASE, FICHERO] \
		and (mapa.get("carpetas", []) as Array).has("%s/Assets" % BASE)


func secciones_de_un_fichero() -> bool:
	var a := _nuevo()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	a.guardar_estados({"https://a.com/x": {"valido": true, "codigo": 200}})
	a.marcar_borrado("https://muerta.com/z")
	a.guardar_cola(["https://cola.com/1"])
	a.guardar_config({"paralelismo": 5})
	a.guardar_instantaneas([{"fecha": "2026-01-02", "total": 3}])
	a.guardar_presets({"mio": {"filtro_dias": 7}})
	a.guardar_cambios([{"clave": "https://a.com/x", "tipo": "caido"}])
	var secciones := _secciones()
	# A mano y no desde SECCIONES_FICHERO: si el nombre se compara con la lista que
	# define el codigo, quitar una seccion de la lista hace que el test siga
	# pasando sin avisar.
	for clave in ["entradas", "estados", "borrados", "cola", "config", "instantaneas", "presets", "cambios"]:
		if not secciones.has(clave):
			return false
	return secciones.size() == 8 \
		and not FileAccess.file_exists("%s/enlaces.json" % BASE) \
		and not FileAccess.file_exists("%s/estados.json" % BASE)


func entradas_ida_y_vuelta() -> bool:
	var a := _nuevo()
	var lista := [{"nombre": "Uno", "url": "https://a.com/x", "img": "png/a.png"}, {"nombre": "Dos", "url": "https://b.com/y"}]
	a.guardar_entradas(lista)
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	return otras.entradas() == lista


func entradas_conservan_esquema() -> bool:
	# El schema_version va dentro de la seccion, como en enlaces.json, porque
	# gestor_datos es el que decide si puede leer lo que hay ahi.
	var a := _nuevo()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	var secciones := _secciones()
	var dentro: Variant = secciones.get("entradas", {})
	if int(dentro.get("schema_version", -1)) != GestorDatos.SCHEMA_ACTUAL:
		return false
	dentro["schema_version"] = GestorDatos.SCHEMA_ACTUAL + 1
	secciones["entradas"] = dentro
	AlmacenScript.escribir_json("%s/%s" % [BASE, FICHERO], {"esquema": AlmacenScript.ESQUEMA_ACTUAL, "secciones": secciones})
	var otro := AlmacenUno.new(BASE)
	otro.abrir()
	return otro.entradas().is_empty()


func estados_con_historial() -> bool:
	var a := _nuevo()
	a.guardar_estado("https://a.com/x", {"valido": true, "mensaje": "OK (200)", "codigo": 200, "historial": [{"fecha": 1}, {"fecha": 2}]})
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	var e := otras.estado("https://a.com/x")
	return e.get("codigo", 0) == 200 and (e.get("historial", []) as Array).size() == 2 \
		and otras.historial("https://a.com/x").size() == 2 \
		and otras.historial("https://nada.test").is_empty() \
		and otras.estado("https://nada.test").is_empty()


func borrados_ida_y_vuelta() -> bool:
	var a := _nuevo()
	a.marcar_borrado("https://muerta.com/z")
	a.marcar_borrado("https://muerta.com/z")
	a.marcar_borrado("https://muerta.com/z")
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	return otras.borrados() == ["https://muerta.com/z"] \
		and a.borrar_estado("https://nada.test") \
		and a.estados().get("https://nada.test", "sigue") == "sigue"


func estados_y_borrados_en_una_escritura() -> bool:
	# La promesa del backend: un solo fichero, un solo guardado. Si esto hiciera
	# dos escrituras, un corte a mitad dejaria el estado sin la marca de borrado (o
	# al reves), que es lo unico que un backend de un solo fichero puede arreglar y
	# el de ocho ficheros no puede.
	var a := _nuevo()
	var antes: int = a.escrituras
	a.guardar_estados_y_borrados({"https://a.com/x": {"codigo": 200}}, ["https://muerta.com/z"])
	if a.escrituras != antes + 1:
		return false
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	return otras.estados().has("https://a.com/x") and otras.borrados() == ["https://muerta.com/z"]


func cola_ida_y_vuelta() -> bool:
	var a := _nuevo()
	a.guardar_cola(["https://cola.com/1", "https://cola.com/2"])
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	return otras.cola() == ["https://cola.com/1", "https://cola.com/2"] \
		and int(_secciones().get("cola", {}).get("fecha", 0)) > 0


func limpiar_cola_no_borra_el_resto() -> bool:
	var a := _nuevo()
	a.guardar_cola(["https://cola.com/1"])
	a.guardar_config({"paralelismo": 5})
	a.limpiar_cola()
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	# Vaciar la cola no puede borrar el fichero entero: aqui tambien viven el
	# catalogo y los ajustes.
	return otras.cola().is_empty() and otras.config().get("paralelismo", 0) == 5 \
		and FileAccess.file_exists("%s/%s" % [BASE, FICHERO])


func config_opaca() -> bool:
	var a := _nuevo()
	a.guardar_config({"tema": "oscuro", "paralelismo": 4})
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	var leida := otras.config()
	# Comparo con conversiones y no con igualdad exacta de diccionario: JSON
	# devuelve los números como float, y el que normaliza eso al cargar es
	# config_store, igual que con el backend de ocho ficheros.
	return str(leida.get("tema", "")) == "oscuro" and int(leida.get("paralelismo", 0)) == 4


func instantaneas_ida_y_vuelta() -> bool:
	var a := _nuevo()
	a.guardar_instantaneas([{"fecha": "2026-01-02", "total": 3, "validos": 2, "caidos": 1}])
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	return otras.instantaneas().size() == 1 \
		and int(otras.instantaneas()[0].get("total", 0)) == 3


func presets_y_cambios() -> bool:
	var a := _nuevo()
	a.guardar_presets({"mio": {"filtro_dias": 7}})
	a.guardar_cambios([{"clave": "https://a.com/x", "tipo": "caido"}])
	var otras := AlmacenUno.new(BASE)
	otras.abrir()
	return int(otras.presets().get("mio", {}).get("filtro_dias", 0)) == 7 \
		and otras.cambios().size() == 1


func atomicidad_con_bak() -> bool:
	var a := _nuevo()
	a.guardar_config({"paralelismo": 2})
	a.guardar_config({"paralelismo": 3})
	return FileAccess.file_exists("%s/%s.bak" % [BASE, FICHERO]) \
		and not FileAccess.file_exists("%s/%s.tmp" % [BASE, FICHERO]) \
		and int(AlmacenScript.leer_json("%s/%s.bak" % [BASE, FICHERO]).get("secciones", {}).get("config", {}).get("paralelismo", 0)) == 2


func escrituras_cuenta() -> bool:
	var a := _nuevo()
	var antes: int = a.escrituras
	a.guardar_config({"paralelismo": 6})
	return a.escrituras == antes + 1


func abrir_relee_lo_guardado() -> bool:
	var a := _nuevo()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	a.guardar_cambios([{"clave": "k", "tipo": "t"}])
	var otra := AlmacenUno.new(BASE)
	if not otra.abrir():
		return false
	return otra.entradas().size() == 1 and otra.cambios().size() == 1


func fichero_roto_no_rompe() -> bool:
	FileAccess.open("%s/%s" % [BASE, FICHERO], FileAccess.WRITE).store_string("{no es json")
	var a := AlmacenUno.new(BASE)
	if not a.abrir():
		return false
	return a.entradas().is_empty() and a.estados().is_empty() and a.cola().is_empty() \
		and a.config().is_empty() and a.instantaneas().is_empty() and a.presets().is_empty() \
		and a.borrados().is_empty() and a.cambios().is_empty() \
		and a.guardar_estado("https://a.com/x", {"codigo": 200})


func esquema_futuro_no_se_pisa() -> bool:
	# Un gestoror mas nuevo abrio el fichero. Esta version no lo entiende, pero
	# menos mal puede dejarlo como estaba: pisarlo seria perder el catalogo de
	# quien lo uso. Ni siquiera un guardado propio debe pasarse por encima.
	var futuro := {"esquema": AlmacenScript.ESQUEMA_ACTUAL + 5, "secciones": {"entradas": {"schema_version": 1, "entradas": [{"nombre": "Futuro", "url": "https://f.com/z"}]}}}
	AlmacenScript.escribir_json("%s/%s" % [BASE, FICHERO], futuro)
	var a := AlmacenUno.new(BASE)
	a.abrir()
	if not a.entradas().is_empty() or not a.bloqueado() or a.guardar_entradas([{"nombre": "Mio", "url": "https://m.com/x"}]):
		return false
	var leido: Variant = AlmacenScript.leer_json("%s/%s" % [BASE, FICHERO])
	if typeof(leido) != TYPE_DICTIONARY or int(leido.get("esquema", 0)) != AlmacenScript.ESQUEMA_ACTUAL + 5:
		return false
	var entradas_futuras: Variant = (leido.get("secciones", {}) as Dictionary).get("entradas", {})
	return (entradas_futuras.get("entradas", []) as Array).size() == 1


func credenciales_desconocidas_se_ignoran() -> bool:
	# Si el fichero trae secciones que esta version no conoce (un gestoror mas
	# nuevo, o alguien editandolo a mano), se leen igual y no se rompen al
	# guardar lo nuestro.
	AlmacenScript.escribir_json("%s/%s" % [BASE, FICHERO], {"esquema": AlmacenScript.ESQUEMA_ACTUAL, "secciones": {"inventada": {"lo que sea": 1}, "cola": {"urls": ["https://c.com/1"]}}})
	var a := AlmacenUno.new(BASE)
	a.abrir()
	if a.cola() != ["https://c.com/1"] or a.seccion("inventada").get("lo que sea", 0) != 1:
		return false
	if not a.guardar_config({"paralelismo": 3}):
		return false
	var secciones := _secciones()
	return secciones.has("inventada") and secciones.has("config")


func copia_devuelve_todo() -> bool:
	var a := _nuevo()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	a.guardar_estados_y_borrados({"https://a.com/x": {"codigo": 200}}, ["https://muerta.com/z"])
	a.guardar_config({"paralelismo": 9})
	a.guardar_config({"paralelismo": 10})
	var b := _nuevo()
	if b.entradas().size() != 1:
		return false
	# Tras dos escrituras hay .bak con lo anterior. Restaurarlo debe devolver el
	# estado entero, no solo el catalogo como en gestor_datos.
	return b.hay_copia() and b.restaurar_copia() and int(b.config().get("paralelismo", 0)) == 9 \
		and b.estados().has("https://a.com/x") and b.borrados() == ["https://muerta.com/z"]


func sin_copia_no_hay_error() -> bool:
	_limpiar()
	var a := _nuevo()
	return not a.hay_copia() and not a.restaurar_copia()


func capturas_ida_y_vuelta() -> bool:
	DirAccess.make_dir_recursive_absolute("%s/Assets/png" % BASE)
	FileAccess.open("user://__test_almacen_uno_origen__.png", FileAccess.WRITE).store_string("bytes de mentira")
	var a := _nuevo()
	var res: Dictionary = a.guardar_captura("png/mia.png", "user://__test_almacen_uno_origen__.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://__test_almacen_uno_origen__.png"))
	if not res.get("ok", false) or FileAccess.get_file_as_string("%s/Assets/png/mia.png" % BASE) != "bytes de mentira":
		return false
	var mapa: Dictionary = a.capturas()
	return mapa.get("png/mia.png", "") == "%s/Assets/png/mia.png" % BASE \
		and not a.guardar_captura("", "user://__test_almacen_uno_origen__.png").get("ok", true) \
		and not a.guardar_captura("png/x.png", "user://no_existe__.png").get("ok", true)


func borra_captura() -> bool:
	var a := _nuevo()
	FileAccess.open("%s/Assets/png/mia.png" % BASE, FileAccess.WRITE).store_string("x")
	# Borrar lo que ya no está no es un fallo: como en el backend de ocho
	# ficheros, se queda en true y no revienta.
	return a.borrar_captura("png/mia.png") and a.borrar_captura("png/mia.png") \
		and a.borrar_captura("png/nunca.jpg") \
		and not FileAccess.file_exists("%s/Assets/png/mia.png" % BASE)


func capturas_ignora_temporales() -> bool:
	for nombre in ["buena.png", "mala.png.import", "corta.png.tmp", "corta.png.bak"]:
		FileAccess.open("%s/Assets/png/%s" % [BASE, nombre], FileAccess.WRITE).store_string("x")
	var mapa: Dictionary = _nuevo().capturas()
	return mapa.has("png/buena.png") and mapa.size() == 1


func tamano_total_cuenta() -> bool:
	var a := _nuevo()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	var total: int = a.tamano_total()
	return total > 0 and total >= AlmacenScript.tamano_de_ruta("%s/%s" % [BASE, FICHERO])


func abrir_crea_carpeta() -> bool:
	var base := "%s/nueva" % BASE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base))
	var a := AlmacenUno.new(base)
	if not a.abrir():
		return false
	a.guardar_config({"paralelismo": 1})
	var ok := FileAccess.file_exists("%s/%s" % [base, FICHERO])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base))
	return ok