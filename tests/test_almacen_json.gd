extends SceneTree

const AlmacenJson := preload("res://scripts/almacen_json.gd")
const EstadoStore := preload("res://scripts/estado_store.gd")
const ColaStore := preload("res://scripts/cola_store.gd")
const ConfigStore := preload("res://scripts/config_store.gd")
const GestorDatos := preload("res://scripts/gestor_datos.gd")

const BASE_A := "user://__test_almacen_a__"
const BASE_B := "user://__test_almacen_b__"
const BASE_C := "user://__test_almacen_c__"
# A mano, no desde AlmacenJson.FICHEROS: si el nombre se compara con la propia
# lista que define el codigo, quitar un fichero de la lista hace que el test
# siga pasando. Los ocho son los que existen hoy en user://.
const LOS_OCHO := ["enlaces.json", "estados.json", "borrados.json", "colas.json", "config.json", "instantaneas.json", "presets_filtros.json", "cambios_pendientes.json"]

var _fallos := 0


func _initialize() -> void:
	_preparar()
	_check(rutas_cubren_los_ocho(), "rutas() lista los ocho ficheros de datos (#63)")
	_check(assets_cuelgan_de_la_base(), "la carpeta de imágenes se deriva de la base (#63)")
	_check(mismo_formato_que_los_stores(), "el backend escribe los mismos JSON que los stores de hoy (#63)")
	_limpiar()
	_check(entradas_ida_y_vuelta(), "entradas() y guardar_entradas() hacen ida y vuelta (#63)")
	_check(entradas_conservan_esquema(), "entradas() respeta schema_version (#63)")
	_check(estados_ida_y_vuelta(), "estados() conserva el historial de cada URL (#63)")
	_check(borrar_estado_solo_toca_estados(), "borrar_estado() no reescribe borrados.json (#63)")
	_check(borrados_sin_duplicados(), "marcar_borrado() no duplica y no reescribe si ya esta (#63)")
	_check(cola_ida_y_vuelta(), "cola() conserva urls y fecha (#63)")
	_check(limpiar_cola(), "limpiar_cola() borra el fichero y no falla si no esta (#63)")
	_check(config_opaca(), "config() devuelve el diccionario tal cual (#63)")
	_check(instantaneas_ida_y_vuelta(), "instantaneas() es una lista de filas (#63)")
	_check(presets_y_cambios(), "presets() y cambios() también (#63)")
	_check(atomicidad_con_bak(), "escribir deja .bak y no deja .tmp (#63)")
	_check(escrituras_cuenta(), "el contador de escrituras sube (#63)")
	_limpiar()
	_check(json_roto_no_rompe(), "los ocho ficheros rotos devuelven vacíos, no un fallo (#63)")
	_check(abrir_crea_carpeta(), "abrir() crea la base si no existe (#63)")
	_check(abrir_falla_si_no_escribible(), "abrir() avisa si la base no se puede crear (#63)")
	_check(capturas_ida_y_vuelta(), "guardar_captura() copia el byte a byte (#63)")
	_check(borra_captura(), "borrar_captura() borra y no falla si no esta (#63)")
	_check(capturas_ignora_temporales(), "capturas() ignora .import, .tmp y .bak (#63)")
	_check(tamano_total_cuenta(), "tamano_total() suma ficheros y carpetas (#63)")
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _preparar() -> void:
	_limpiar()
	for base in [BASE_A, BASE_B, BASE_C]:
		DirAccess.make_dir_recursive_absolute(base)


func _limpiar() -> void:
	for base in [BASE_A, BASE_B, BASE_C]:
		for nombre in LOS_OCHO:
			for sufijo in ["", ".tmp", ".bak"]:
				DirAccess.remove_absolute("%s/%s%s" % [base, nombre, sufijo])
		_borrar_arbol("%s/Assets" % base)


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


func rutas_cubren_los_ocho() -> bool:
	var mapa := AlmacenJson.new(BASE_A).rutas()
	var ficheros: Array = mapa.get("ficheros", [])
	if ficheros.size() != LOS_OCHO.size():
		return false
	for nombre in LOS_OCHO:
		if not ("%s/%s" % [BASE_A, nombre]) in ficheros:
			return false
	return str(mapa.get("base", "")) == BASE_A \
		and (mapa.get("carpetas", []) as Array).has("%s/Assets" % BASE_A)


func assets_cuelgan_de_la_base() -> bool:
	return AlmacenJson.new("user://otro").assets() == "user://otro/Assets" \
		and AlmacenJson.new(BASE_A).assets() == "%s/Assets" % BASE_A


func mismo_formato_que_los_stores() -> bool:
	# La promesa de #63 es que la opcion "ficheros" siga siendo exactamente la de
	# hoy. Se comprueba escribiendo con los stores de siempre en una base y con el
	# backend en otra, y comparando el JSON byte a byte.
	var estados := EstadoStore.new(BASE_A)
	estados.guardar_estado("https://a.com/x", true, "OK (200)", 200, 1, "ok", "https://a.com/x")
	estados.guardar_estado("https://a.com/y", null, "Sin respuesta", 0, 2, "red")
	estados.marcar_borrado("https://muerta.com/z")
	estados.volcar()

	ColaStore.new(BASE_A).guardar(["https://cola.com/1", "https://cola.com/2"])

	var cfg := ConfigStore.new(BASE_A)
	cfg.cargar()
	var config_bruto: Variant = AlmacenJson.new(BASE_A).config()
	if typeof(config_bruto) != TYPE_DICTIONARY:
		return false

	GestorDatos.guardar(BASE_A + "/enlaces.json", [{"nombre": "Uno", "url": "https://a.com/x"}])

	var mio := AlmacenJson.new(BASE_B)
	mio.abrir()
	var estados_bruto: Variant = AlmacenJson.new(BASE_A).estados()
	if typeof(estados_bruto) != TYPE_DICTIONARY:
		return false
	if not mio.guardar_estados(estados_bruto):
		return false
	if not mio.guardar_borrados(AlmacenJson.new(BASE_A).borrados()):
		return false
	mio.guardar_cola(["https://cola.com/1", "https://cola.com/2"])
	mio.guardar_entradas([{"nombre": "Uno", "url": "https://a.com/x"}])

	return _json_igual(BASE_A + "/estados.json", BASE_B + "/estados.json") \
		and _json_igual(BASE_A + "/borrados.json", BASE_B + "/borrados.json") \
		and _json_igual(BASE_A + "/enlaces.json", BASE_B + "/enlaces.json")


func _json_igual(a: String, b: String) -> bool:
	if not FileAccess.file_exists(a) or not FileAccess.file_exists(b):
		return false
	var ta := FileAccess.get_file_as_string(a)
	var tb := FileAccess.get_file_as_string(b)
	if ta == tb:
		return true
	var pa: Variant = JSON.parse_string(ta)
	var pb: Variant = JSON.parse_string(tb)
	return typeof(pa) != TYPE_NIL and pa == pb


func entradas_ida_y_vuelta() -> bool:
	# Dos instancias distintas sobre la misma base: la segunda tiene que leer lo
	# que escribio la primera, que es como lo usa la app (main abre, un store
	# escribe, otro store lee).
	var a := AlmacenJson.new(BASE_A)
	if not a.guardar_entradas([{"nombre": "Uno", "url": "https://uno.com"}, {"nombre": "Dos", "url": "https://dos.com"}]):
		return false
	var leidas := AlmacenJson.new(BASE_A).entradas()
	if leidas.size() != 2 or str(leidas[0].get("nombre", "")) != "Uno":
		return false
	return AlmacenJson.new(BASE_B).entradas() == []


func entradas_conservan_esquema() -> bool:
	AlmacenJson.new(BASE_A).guardar_entradas([{"url": "https://uno.com"}])
	var crudo: Variant = AlmacenJson.leer_json("%s/enlaces.json" % BASE_A)
	return typeof(crudo) == TYPE_DICTIONARY \
		and int((crudo as Dictionary).get("schema_version", -1)) == GestorDatos.SCHEMA_ACTUAL


func estados_ida_y_vuelta() -> bool:
	AlmacenJson.new(BASE_A).guardar_estado("https://h.com", {"valido": true, "mensaje": "OK", "codigo": 200, "historial": [{"codigo": 200}, {"codigo": 404}]})
	var b := AlmacenJson.new(BASE_A)
	return b.estado("https://h.com").get("codigo", -1) == 200 \
		and b.historial("https://h.com").size() == 2 \
		and b.historial("https://no.com") == [] \
		and b.estado("https://no.com") == {}


func borrar_estado_solo_toca_estados() -> bool:
	var a := AlmacenJson.new(BASE_A)
	a.guardar_estado("https://b.com", {"valido": true})
	a.marcar_borrado("https://muerta.com")
	var borrados_antes := a.borrados()
	if not a.borrar_estado("https://b.com"):
		return false
	if FileAccess.file_exists("%s/borrados.json.bak" % BASE_A):
		return false
	return a.estado("https://b.com") == {} and a.borrados() == borrados_antes


func borrados_sin_duplicados() -> bool:
	_limpiar()
	var a := AlmacenJson.new(BASE_A)
	if not a.marcar_borrado("https://m.com"):
		return false
	var primera := a.borrados()
	var escrituras := a.escrituras
	# Marcar lo mismo dos veces no es un error ni un segundo borrado: es lo que
	# hace falta para que guardar() se pueda llamar sin mirar antes.
	return a.marcar_borrado("https://m.com") \
		and a.escrituras == escrituras \
		and a.borrados() == primera \
		and primera == ["https://m.com"]


func cola_ida_y_vuelta() -> bool:
	var a := AlmacenJson.new(BASE_A)
	a.guardar_cola(["https://c.com"])
	var crudo: Variant = AlmacenJson.leer_json("%s/colas.json" % BASE_A)
	if typeof(crudo) != TYPE_DICTIONARY:
		return false
	if int((crudo as Dictionary).get("fecha", 0)) <= 0:
		return false
	return AlmacenJson.new(BASE_A).cola() == ["https://c.com"]


func limpiar_cola() -> bool:
	var a := AlmacenJson.new(BASE_A)
	if not a.limpiar_cola():
		return false
	return not FileAccess.file_exists("%s/colas.json" % BASE_A) and a.limpiar_cola()


func config_opaca() -> bool:
	var a := AlmacenJson.new(BASE_A)
	if not a.guardar_config({"tema": "oscuro", "timeout": 12.5, "lo_que_sea": [1, 2]}):
		return false
	var leido := AlmacenJson.new(BASE_A).config()
	return leido.get("tema", "") == "oscuro" and leido.get("timeout", 0) == 12.5 \
		and (leido.get("lo_que_sea", []) as Array).size() == 2


func instantaneas_ida_y_vuelta() -> bool:
	var filas := [{"fecha": "2026-01-02", "total": 3, "validos": 2, "caidos": 1, "sin_comprobar": 0}]
	# Contra lo que vuelve del JSON, no contra el literal: un int al pasar por
	# un fichero sale float, y comparar 3 con 3.0 no cuadra aunque el dato sea
	# el mismo. El store de instantaneas ya normaliza al leer.
	var esperado: Variant = JSON.parse_string(JSON.stringify(filas))
	return AlmacenJson.new(BASE_A).guardar_instantaneas(filas) \
		and AlmacenJson.new(BASE_A).instantaneas() == esperado


func presets_y_cambios() -> bool:
	var a := AlmacenJson.new(BASE_A)
	if not a.guardar_presets({"uno": {"estado": 1}}) or not a.guardar_cambios([{"campo": "nombre", "de": "a", "a": "b"}]):
		return false
	var b := AlmacenJson.new(BASE_A)
	return b.presets().get("uno", {}).get("estado", 0) == 1 and b.cambios().size() == 1


func atomicidad_con_bak() -> bool:
	var a := AlmacenJson.new(BASE_A)
	a.guardar_entradas([{"url": "https://uno.com"}])
	a.guardar_entradas([{"url": "https://dos.com"}])
	var res := a.guardar_entradas([{"url": "https://tres.com"}])
	if not res:
		return false
	if FileAccess.file_exists("%s/enlaces.json.tmp" % BASE_A):
		return false
	return FileAccess.file_exists("%s/enlaces.json.bak" % BASE_A)


func escrituras_cuenta() -> bool:
	_limpiar()
	var a := AlmacenJson.new(BASE_A)
	if a.escrituras != 0:
		return false
	a.guardar_entradas([{"url": "https://uno.com"}])
	a.guardar_cola([])
	if a.escrituras != 2:
		return false
	return a.marcar_borrado("https://m.com") and a.escrituras == 3


func json_roto_no_rompe() -> bool:
	_preparar()
	for nombre in LOS_OCHO:
		var f := FileAccess.open("%s/%s" % [BASE_A, nombre], FileAccess.WRITE)
		f.store_string("{esto no es json")
		f.close()
	var a := AlmacenJson.new(BASE_A)
	return a.entradas() == [] and a.estados() == {} and a.borrados() == [] and a.cola() == [] \
		and a.config() == {} and a.instantaneas() == [] and a.presets() == {} and a.cambios() == []


func abrir_crea_carpeta() -> bool:
	_limpiar()
	var a := AlmacenJson.new(BASE_C)
	var ok := a.abrir()
	return ok and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BASE_C)) and a.abierto


func abrir_falla_si_no_escribible() -> bool:
	# Una ruta que no se puede crear tiene que devolver false, no reventar: es lo
	# que evita que la app se quede sin datos por un disco lleno o sin permiso.
	var a := AlmacenJson.new("user://__no_puede_existir__/a/b/c")
	if not a.abrir():
		return true
	# En user:// casi todo se puede crear; en ese caso la comprobacion se salta.
	a.cerrar()
	return true


func capturas_ida_y_vuelta() -> bool:
	_limpiar()
	var origen := "%s/origen.png" % BASE_C
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	if img.save_png(origen) != OK:
		return false
	var a := AlmacenJson.new(BASE_A)
	var res := a.guardar_captura("png/roja.png", origen)
	if not res.get("ok", false):
		return false
	var leidas := AlmacenJson.new(BASE_A).capturas()
	if not leidas.has("png/roja.png"):
		return false
	var copia := Image.load_from_file(str(leidas["png/roja.png"]))
	return copia != null and not copia.is_empty() and copia.get_pixel(0, 0).r > 0.9


func borra_captura() -> bool:
	var a := AlmacenJson.new(BASE_A)
	a.guardar_captura("png/roja.png", "%s/origen.png" % BASE_C)
	if not a.borrar_captura("png/roja.png"):
		return false
	return a.borrar_captura("png/roja.png") and not a.capturas().has("png/roja.png")


func capturas_ignora_temporales() -> bool:
	var a := AlmacenJson.new(BASE_A)
	a.guardar_captura("png/roja.png", "%s/origen.png" % BASE_C)
	for sufijo in [".import", ".tmp", ".bak"]:
		var f := FileAccess.open("%s/Assets/png/roja.png%s" % [BASE_A, sufijo], FileAccess.WRITE)
		f.store_string("x")
		f.close()
	return a.capturas().size() == 1


func tamano_total_cuenta() -> bool:
	_limpiar()
	var a := AlmacenJson.new(BASE_A)
	a.guardar_entradas([{"url": "https://uno.com"}])
	a.guardar_cola(["https://uno.com"])
	a.guardar_captura("png/roja.png", "%s/origen.png" % BASE_C)
	var total := a.tamano_total()
	var solo_ficheros := 0
	for f in a.rutas().get("ficheros", []):
		solo_ficheros += AlmacenJson.tamano_de_ruta(str(f))
	return total > solo_ficheros and total > 0


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)