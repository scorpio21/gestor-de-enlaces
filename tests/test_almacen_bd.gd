extends SceneTree

# El backend de base de datos (#65): un solo fichero .db por SQLite. Se prueba lo
# mismo que en el backend de un único fichero (ida y vuelta de las ocho
# secciones, el .bak, el esquema futuro) más lo que solo tiene sentido aquí: que
# la migración desde los JSON de siempre mueva todo y que vuelva.

const AlmacenBd := preload("res://scripts/almacen_bd.gd")
const AlmacenJson := preload("res://scripts/almacen_json.gd")
const AlmacenScript := preload("res://scripts/almacen.gd")
const AlmacenController := preload("res://scripts/almacen_controller.gd")
const GestorDatos := preload("res://scripts/gestor_datos.gd")
const ConfigStore := preload("res://scripts/config_store.gd")
const EstadoStore := preload("res://scripts/estado_store.gd")
const ColaStore := preload("res://scripts/cola_store.gd")
const InstantaneaStore := preload("res://scripts/instantanea_store.gd")
const PresetsStore := preload("res://scripts/presets_store.gd")
const CambiosController := preload("res://scripts/cambios_controller.gd")

const BASE := "user://__test_almacen_bd__"
const DB := "user://__test_almacen_bd__/gestorao.db"

var _fallos := 0


func _initialize() -> void:
	_limpiar()
	DirAccess.make_dir_recursive_absolute(BASE)
	_check(modo_y_soporte(), "modo() dice base_datos y el controller lo fabrica (#65)")
	_check(rutas_lista_un_fichero(), "rutas() lista un solo .db (#65)")
	_check(entradas_ida_y_vuelta(), "entradas() y guardar_entradas() hacen ida y vuelta (#65)")
	_check(entradas_conservan_esquema(), "entradas() respeta schema_version (#65)")
	_check(estados_con_historial(), "estados() conserva el historial de cada URL (#65)")
	_check(borrados_ida_y_vuelta(), "borrados() hacen ida y vuelta y no duplican (#65)")
	_check(estados_y_borrados_en_una_escritura(), "estados y borrados se guardan en una transacción (#65)")
	_check(cola_ida_y_vuelta(), "cola() conserva las urls (#65)")
	_check(limpiar_cola_no_borra_el_resto(), "limpiar_cola() vacía la cola sin tocar el resto (#65)")
	_check(config_opaca(), "config() devuelve el diccionario tal cual (#65)")
	_check(instantaneas_ida_y_vuelta(), "instantaneas() es una lista de filas (#65)")
	_check(presets_y_cambios(), "presets() y cambios() también (#65)")
	_check(atomicidad_con_bak(), "escribir deja .bak con la versión anterior, no .tmp (#65)")
	_check(escrituras_cuenta(), "el contador de escrituras sube (#65)")
	_check(abrir_relee_lo_guardado(), "abrir() de nuevo lee lo que había (#65)")
	_check(fichero_roto_no_rompe(), "un .db que no es una base de datos se rechaza sin tocarlo (#65)")
	_check(esquema_futuro_no_se_pisa(), "una base de una versión posterior no se sobreescribe (#65)")
	_check(copia_devuelve_todo(), "la copia de seguridad devuelve estados, borrados y config (#65)")
	_check(sin_copia_no_hay_error(), "sin copia previa no hay error, solo que no hay copia (#65)")
	_check(capturas_ida_y_vuelta(), "guardar_captura() copia el byte a byte (#65)")
	_check(borra_captura(), "borrar_captura() borra y no falla si no está (#65)")
	_check(capturas_ignora_temporales(), "capturas() ignora .import, .tmp y .bak (#65)")
	_check(tamano_total_cuenta(), "tamano_total() suma el .db y las capturas (#65)")
	_check(abrir_crea_carpeta(), "abrir() crea la carpeta de la base si no existe (#65)")
	_check(json_a_bd_migra_todo(), "migrar de los JSON de siempre a la base mueve las ocho secciones (#65)")
	_check(bd_a_json_vuelve(), "migrar de la base a JSON es reversible (#65)")
	_check(store_config_escribe_por_bd(), "config_store escribe en la base de datos (#65)")
	_check(store_estados_escribe_por_bd(), "estado_store vuelca en la base de datos (#65)")
	_check(stores_por_bd(), "los seis stores leen y escriben por la base, y la cola conserva su fecha (#65)")
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


func _fresco() -> RefCounted:
	_borrar_db()
	DirAccess.make_dir_recursive_absolute(BASE)
	var a := AlmacenBd.new(DB, BASE)
	a.abrir()
	return a


func _nuevo() -> RefCounted:
	var a := AlmacenBd.new(DB, BASE)
	a.abrir()
	return a


func _borrar_db() -> void:
	for sufijo in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DB + sufijo))


func _limpiar() -> void:
	_borrar_arbol(BASE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://__test_almacen_bd_origen__.png"))


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


func _fresca_base(nombre: String) -> String:
	var base := "%s/%s" % [BASE, nombre]
	_borrar_arbol(base)
	DirAccess.make_dir_recursive_absolute(base)
	return base


func modo_y_soporte() -> bool:
	var a := AlmacenBd.new(DB, BASE)
	var con_ruta = AlmacenController.crear({"modo": "base_datos", "base": BASE, "ruta_bd": "user://otra.db"})
	return a.modo() == AlmacenScript.MODO_BASE_DATOS \
		and AlmacenController.soporta(AlmacenScript.MODO_BASE_DATOS) \
		and AlmacenController.crear({"modo": "base_datos", "base": BASE}) != null \
		and con_ruta != null and str(con_ruta.ruta_bd) == "user://otra.db" \
		and AlmacenController.crear_en("base_datos", BASE).ruta_bd == "%s/gestorao.db" % BASE


func rutas_lista_un_fichero() -> bool:
	var mapa := AlmacenBd.new(DB, BASE).rutas()
	var ficheros: Array = mapa.get("ficheros", [])
	if ficheros.size() != 1:
		return false
	return str(ficheros[0]) == DB and str(mapa.get("modo", "")) == AlmacenScript.MODO_BASE_DATOS \
		and (mapa.get("carpetas", []) as Array).has("%s/Assets" % BASE)


func entradas_ida_y_vuelta() -> bool:
	var a := _fresco()
	var lista := [{"nombre": "Uno", "url": "https://a.com/x", "img": "png/a.png"}, {"nombre": "Dos", "url": "https://b.com/y"}]
	a.guardar_entradas(lista)
	var otra := _nuevo()
	var ok: bool = otra.entradas() == lista
	otra.cerrar()
	return ok


func entradas_conservan_esquema() -> bool:
	var a := _fresco()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	# Un editor que escriba el catálogo con otro schema_version: la base se lee
	# vacía, igual que gestor_datos rechaza un enlaces.json de otra versión.
	a._db.query_with_named_bindings("UPDATE meta SET valor = :v WHERE clave = 'entradas_esquema'", {"v": str(GestorDatos.SCHEMA_ACTUAL + 1)})
	return a.entradas().is_empty()


func estados_con_historial() -> bool:
	var a := _fresco()
	a.guardar_estado("https://a.com/x", {"valido": true, "mensaje": "OK (200)", "codigo": 200, "historial": [{"fecha": 1}, {"fecha": 2}]})
	var otra := _nuevo()
	var e: Dictionary = otra.estado("https://a.com/x")
	var ok: bool = int(e.get("codigo", 0)) == 200 and (e.get("historial", []) as Array).size() == 2 \
		and otra.historial("https://a.com/x").size() == 2 \
		and otra.historial("https://nada.test").is_empty() \
		and otra.estado("https://nada.test").is_empty()
	otra.cerrar()
	return ok


func borrados_ida_y_vuelta() -> bool:
	var a := _fresco()
	a.marcar_borrado("https://muerta.com/z")
	a.marcar_borrado("https://muerta.com/z")
	a.marcar_borrado("https://muerta.com/z")
	var otra := _nuevo()
	var ok: bool = otra.borrados() == ["https://muerta.com/z"] \
		and a.borrar_estado("https://nada.test") \
		and a.estados().get("https://nada.test", "sigue") == "sigue"
	otra.cerrar()
	return ok


func estados_y_borrados_en_una_escritura() -> bool:
	var a := _fresco()
	var antes: int = a.escrituras
	if not a.guardar_estados_y_borrados({"https://a.com/x": {"codigo": 200}}, ["https://muerta.com/z"]):
		return false
	if a.escrituras != antes + 1:
		return false
	var otra := _nuevo()
	var ok: bool = otra.estados().has("https://a.com/x") and otra.borrados() == ["https://muerta.com/z"]
	otra.cerrar()
	return ok


func cola_ida_y_vuelta() -> bool:
	var a := _fresco()
	a.guardar_cola(["https://cola.com/1", "https://cola.com/2"])
	var otra := _nuevo()
	var ok: bool = otra.cola() == ["https://cola.com/1", "https://cola.com/2"]
	otra.cerrar()
	return ok


func limpiar_cola_no_borra_el_resto() -> bool:
	var a := _fresco()
	a.guardar_cola(["https://cola.com/1"])
	a.guardar_config({"paralelismo": 5})
	a.limpiar_cola()
	var otra := _nuevo()
	var ok: bool = otra.cola().is_empty() and int(otra.config().get("paralelismo", 0)) == 5
	otra.cerrar()
	return ok


func config_opaca() -> bool:
	var a := _fresco()
	a.guardar_config({"tema": "oscuro", "paralelismo": 4, "auto_abrir": false, "lista": [1, 2, 3]})
	var otra := _nuevo()
	var leida: Dictionary = otra.config()
	# Conversiones y no igualdad exacta: JSON devuelve los números como float,
	# igual que en el backend de un único fichero; el que normaliza es config_store.
	var ok: bool = str(leida.get("tema", "")) == "oscuro" and int(leida.get("paralelismo", 0)) == 4 \
		and bool(leida.get("auto_abrir", true)) == false and (leida.get("lista", []) as Array).size() == 3
	otra.cerrar()
	return ok


func instantaneas_ida_y_vuelta() -> bool:
	var a := _fresco()
	a.guardar_instantaneas([{"fecha": "2026-01-02", "total": 3, "validos": 2, "caidos": 1}])
	var otra := _nuevo()
	var ok: bool = otra.instantaneas().size() == 1 and int(otra.instantaneas()[0].get("total", 0)) == 3
	otra.cerrar()
	return ok


func presets_y_cambios() -> bool:
	var a := _fresco()
	a.guardar_presets({"mio": {"filtro_dias": 7}})
	a.guardar_cambios([{"clave": "https://a.com/x", "tipo": "caido"}])
	var otra := _nuevo()
	var ok: bool = int(otra.presets().get("mio", {}).get("filtro_dias", 0)) == 7 and otra.cambios().size() == 1
	otra.cerrar()
	return ok


func atomicidad_con_bak() -> bool:
	var a := _fresco()
	a.guardar_config({"paralelismo": 2})
	# La primera escritura no tiene versión previa que guardar; a partir de la
	# segunda, el .bak es exactamente lo que había antes.
	a.guardar_config({"paralelismo": 3})
	if not FileAccess.file_exists(DB + ".bak") or FileAccess.file_exists(DB + ".tmp"):
		return false
	a.guardar_config({"paralelismo": 4})
	return a.restaurar_copia() and int(a.config().get("paralelismo", 0)) == 3


func escrituras_cuenta() -> bool:
	var a := _fresco()
	var antes: int = a.escrituras
	a.guardar_config({"paralelismo": 6})
	a.guardar_config({"paralelismo": 7})
	return a.escrituras == antes + 2


func abrir_relee_lo_guardado() -> bool:
	var a := _fresco()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	a.guardar_cambios([{"clave": "k", "tipo": "t"}])
	a.cerrar()
	var otra := AlmacenBd.new(DB, BASE)
	if not otra.abrir():
		return false
	var ok: bool = otra.entradas().size() == 1 and otra.cambios().size() == 1
	otra.cerrar()
	return ok


func fichero_roto_no_rompe() -> bool:
	var roto := "%s/roto.db" % BASE
	var f := FileAccess.open(roto, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("esto no es una base de datos sqlite")
	f.close()
	var a := AlmacenBd.new(roto, BASE)
	var abierto := a.abrir()
	var sigue_ahi := FileAccess.file_exists(roto)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(roto))
	return not abierto and sigue_ahi


func esquema_futuro_no_se_pisa() -> bool:
	var a := _fresco()
	a.guardar_entradas([{"nombre": "Mio", "url": "https://m.com/x"}])
	a._db.query_with_named_bindings("UPDATE meta SET valor = :v WHERE clave = 'esquema'", {"v": str(AlmacenScript.ESQUEMA_ACTUAL + 5)})
	a.cerrar()
	var otra := AlmacenBd.new(DB, BASE)
	if not otra.abrir() or not otra.bloqueado():
		return false
	# Se puede leer, pero no escribir: pisar sería perder lo de la versión nueva.
	var rechaza := not otra.guardar_entradas([{"nombre": "Otra", "url": "https://o.com/x"}])
	var ok: bool = rechaza and otra.entradas().size() == 1
	otra.cerrar()
	return ok


func copia_devuelve_todo() -> bool:
	var a := _fresco()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	a.guardar_estados_y_borrados({"https://a.com/x": {"codigo": 200}}, ["https://muerta.com/z"])
	a.guardar_config({"paralelismo": 9})
	a.guardar_config({"paralelismo": 10})
	var b := _nuevo()
	if b.entradas().size() != 1:
		b.cerrar()
		return false
	# El .bak es la base entera, no solo el catálogo: restaurarlo devuelve
	# estados, borrados y configuración de antes.
	var ok: bool = b.hay_copia() and b.restaurar_copia() and int(b.config().get("paralelismo", 0)) == 9 \
		and b.estados().has("https://a.com/x") and b.borrados() == ["https://muerta.com/z"]
	b.cerrar()
	return ok


func sin_copia_no_hay_error() -> bool:
	_limpiar()
	DirAccess.make_dir_recursive_absolute(BASE)
	var a := _nuevo()
	var ok: bool = not a.hay_copia() and not a.restaurar_copia()
	a.cerrar()
	return ok


func capturas_ida_y_vuelta() -> bool:
	DirAccess.make_dir_recursive_absolute("%s/Assets/png" % BASE)
	FileAccess.open("user://__test_almacen_bd_origen__.png", FileAccess.WRITE).store_string("bytes de mentira")
	var a := _nuevo()
	var res: Dictionary = a.guardar_captura("png/mia.png", "user://__test_almacen_bd_origen__.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://__test_almacen_bd_origen__.png"))
	if not res.get("ok", false) or FileAccess.get_file_as_string("%s/Assets/png/mia.png" % BASE) != "bytes de mentira":
		return false
	var mapa: Dictionary = a.capturas()
	a.cerrar()
	return mapa.get("png/mia.png", "") == "%s/Assets/png/mia.png" % BASE


func borra_captura() -> bool:
	var a := _nuevo()
	FileAccess.open("%s/Assets/png/mia.png" % BASE, FileAccess.WRITE).store_string("x")
	var ok: bool = a.borrar_captura("png/mia.png") and a.borrar_captura("png/mia.png") \
		and a.borrar_captura("png/nunca.jpg") \
		and not FileAccess.file_exists("%s/Assets/png/mia.png" % BASE)
	a.cerrar()
	return ok


func capturas_ignora_temporales() -> bool:
	for nombre in ["buena.png", "mala.png.import", "corta.png.tmp", "corta.png.bak"]:
		FileAccess.open("%s/Assets/png/%s" % [BASE, nombre], FileAccess.WRITE).store_string("x")
	var a := _nuevo()
	var mapa: Dictionary = a.capturas()
	a.cerrar()
	return mapa.has("png/buena.png") and mapa.size() == 1


func tamano_total_cuenta() -> bool:
	var a := _fresco()
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])
	var total: int = a.tamano_total()
	return total > 0 and total >= AlmacenScript.tamano_de_ruta(DB)


func abrir_crea_carpeta() -> bool:
	var base := "%s/nueva" % BASE
	_borrar_arbol(base)
	var a := AlmacenBd.new("%s/gestorao.db" % base, base)
	if not a.abrir():
		return false
	a.guardar_config({"paralelismo": 1})
	var ok: bool = FileAccess.file_exists("%s/gestorao.db" % base)
	a.cerrar()
	_borrar_arbol(base)
	return ok


func json_a_bd_migra_todo() -> bool:
	var origen_base := _fresca_base("origen_json")
	var destino_base := _fresca_base("destino_bd")
	var origen := AlmacenJson.new(origen_base)
	origen.abrir()
	origen.guardar_entradas([{"nombre": "A", "url": "https://a.com"}, {"nombre": "B", "url": "https://b.com"}])
	origen.guardar_estados({"https://a.com": {"valido": true, "historial": [{"fecha": 1}, {"fecha": 2}]}, "https://b.com": {"valido": false, "historial": [{"fecha": 1}]}})
	origen.marcar_borrado("https://muerta.com")
	origen.guardar_cola(["https://a.com"])
	origen.guardar_config({"paralelismo": 7})
	origen.guardar_instantaneas([{"fecha": "2026-01-01", "total": 2}])
	origen.guardar_presets({"mio": {"x": 1}})
	origen.guardar_cambios([{"url": "https://a.com"}])
	var destino := AlmacenBd.new("%s/gestorao.db" % destino_base, destino_base)
	destino.abrir()
	var res: Dictionary = origen.migra_a(destino)
	if not res.get("ok", false):
		return false
	destino.cerrar()
	# El origen no se toca y el destino tiene las ocho secciones.
	var vuelta := AlmacenJson.new(origen_base)
	vuelta.abrir()
	var b := AlmacenBd.new("%s/gestorao.db" % destino_base, destino_base)
	if not b.abrir():
		return false
	var ok: bool = vuelta.entradas().size() == 2 \
		and b.entradas().size() == 2 and b.estados().size() == 2 and b.historial("https://a.com").size() == 2 \
		and b.borrados() == ["https://muerta.com"] and b.cola() == ["https://a.com"] \
		and int(b.config().get("paralelismo", 0)) == 7 and b.instantaneas().size() == 1 \
		and b.presets().size() == 1 and b.cambios().size() == 1
	b.cerrar()
	_borrar_arbol(origen_base)
	_borrar_arbol(destino_base)
	return ok


func bd_a_json_vuelve() -> bool:
	var bd_base := _fresca_base("vuelta_bd")
	var json_base := _fresca_base("vuelta_json")
	var bd := AlmacenBd.new("%s/gestorao.db" % bd_base, bd_base)
	bd.abrir()
	bd.guardar_entradas([{"url": "https://a.com"}, {"url": "https://b.com"}])
	bd.guardar_estados_y_borrados({"https://a.com": {"valido": true}}, ["https://muerta.com"])
	bd.guardar_config({"paralelismo": 3})
	var destino := AlmacenJson.new(json_base)
	destino.abrir()
	var res: Dictionary = bd.migra_a(destino)
	if not res.get("ok", false):
		return false
	bd.cerrar()
	var vuelta := AlmacenJson.new(json_base)
	vuelta.abrir()
	var ok: bool = vuelta.entradas().size() == 2 and vuelta.estados().size() == 1 \
		and vuelta.borrados() == ["https://muerta.com"] and int(vuelta.config().get("paralelismo", 0)) == 3
	_borrar_arbol(bd_base)
	_borrar_arbol(json_base)
	return ok


func store_config_escribe_por_bd() -> bool:
	var base := _fresca_base("store_config")
	var a := AlmacenBd.new("%s/gestorao.db" % base, base)
	a.abrir()
	var store := ConfigStore.new(base, a)
	if not store.guardar(4, 11.0):
		return false
	if FileAccess.file_exists("%s/config.json" % base):
		return false
	var b := AlmacenBd.new("%s/gestorao.db" % base, base)
	b.abrir()
	var ok: bool = int(b.config().get("paralelismo", 0)) == 4
	b.cerrar()
	_borrar_arbol(base)
	return ok


func store_estados_escribe_por_bd() -> bool:
	var base := _fresca_base("store_estados")
	var a := AlmacenBd.new("%s/gestorao.db" % base, base)
	a.abrir()
	var store := EstadoStore.new(base, a)
	if not store.guardar_estado("https://a.com", true, "OK (200)", 200, 1, "", "") or not store.volcar():
		return false
	if FileAccess.file_exists("%s/estados.json" % base):
		return false
	var b := AlmacenBd.new("%s/gestorao.db" % base, base)
	b.abrir()
	var ok: bool = b.estados().has("https://a.com")
	b.cerrar()
	_borrar_arbol(base)
	return ok


func stores_por_bd() -> bool:
	# El fallo de #65 que se coló: la cola lee su seccion cruda (con la fecha al
	# lado de las urls) y el backend de base de datos no la tenía. Aquí pasan los
	# seis stores por el backend, no solo los dos que ya se probaban.
	var base := _fresca_base("stores")
	var a := AlmacenBd.new("%s/gestorao.db" % base, base)
	if not a.abrir():
		return false
	var cola := ColaStore.new(base, a)
	if not cola.guardar(["https://a.com/", "https://b.com/"]):
		return false
	var leida: Dictionary = cola.cargar()
	if (leida.get("urls", []) as Array) != ["https://a.com/", "https://b.com/"] or int(leida.get("fecha", 0)) <= 0:
		return false
	if not cola.limpiar():
		return false
	var vacia: Dictionary = cola.cargar()
	if not (vacia.get("urls", []) as Array).is_empty() or int(vacia.get("fecha", 0)) != 0:
		return false
	if not ConfigStore.new(base, a).guardar(5, 12.0):
		return false
	var estado := EstadoStore.new(base, a)
	if not estado.guardar_estado("https://a.com/", true, "OK (200)", 200):
		return false
	if not estado.marcar_borrado("https://muerta.com/"):
		return false
	if not PresetsStore.new(base, a).guardar({"mio": {"filtro_dias": 3}}):
		return false
	var res: Dictionary = InstantaneaStore.new(base, a).guardar(
		[{"url": "https://a.com/", "nombre": "A", "cat": "", "tags": []}],
		{"https://a.com/": {"valido": true}}
	)
	if not res.get("ok", false):
		return false
	var cambios := CambiosController.new()
	cambios.ruta = "%s/cambios_pendientes.json" % base
	cambios.almacen = a
	if not cambios.guardar_pendientes([{"campo": "nombre", "de": "a", "a": "b"}]):
		return false
	for nombre in ["config.json", "colas.json", "estados.json", "borrados.json", "presets_filtros.json", "instantaneas.json", "cambios_pendientes.json"]:
		if FileAccess.file_exists("%s/%s" % [base, nombre]):
			return false
	var b := AlmacenBd.new("%s/gestorao.db" % base, base)
	if not b.abrir():
		return false
	var datos: Dictionary = EstadoStore.new(base, b).cargar()
	var cambios2 := CambiosController.new()
	cambios2.ruta = "%s/cambios_pendientes.json" % base
	cambios2.almacen = b
	var ok: bool = int(ConfigStore.new(base, b).cargar().get("paralelismo", 0)) == 5 \
		and int((datos.get("estados", {}) as Dictionary).get("https://a.com/", {}).get("codigo", 0)) == 200 \
		and (datos.get("borrados", []) as Array) == ["https://muerta.com/"] \
		and int(PresetsStore.new(base, b).cargar().get("mio", {}).get("filtro_dias", 0)) == 3 \
		and InstantaneaStore.new(base, b).cargar().size() == 1 \
		and cambios2.leer_pendientes().size() == 1
	b.cerrar()
	_borrar_arbol(base)
	return ok
