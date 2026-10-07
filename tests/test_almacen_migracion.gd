extends SceneTree

const AlmacenJson := preload("res://scripts/almacen_json.gd")
const AlmacenUno := preload("res://scripts/almacen_uno.gd")
const AlmacenController := preload("res://scripts/almacen_controller.gd")

const BASE_A := "user://__test_migra_a__"
const BASE_B := "user://__test_migra_b__"
const FICHERO := "gestorao.json"

var _fallos := 0


# Backend que se come la ultima entrada al importar. Sirve para lo unico que de
# verdad importa de una migracion: que si algo se pierde, se diga, en vez de
# dejar una copia "migrada" que parece buena y esta incompleta.
class AlmacenQuePierdeEntradas:
	extends "res://scripts/almacen_json.gd"

	func guardar_entradas(lista: Array) -> bool:
		if lista.size() <= 1:
			return super.guardar_entradas(lista)
		return super.guardar_entradas(lista.slice(0, lista.size() - 1))


func _initialize() -> void:
	_check(migra_todo(), "una migración mueve las ocho secciones y las capturas (#63)")
	_check(recuentos_coinciden(), "los recuentos del origen y del destino coinciden (#63)")
	_check(no_toca_el_origen(), "el origen se queda exactamente igual (#63)")
	_check(destino_lleno_rechazado(), "no se migra encima de un destino con datos (#63)")
	_check(sin_destino_no_pasa(), "migra_a(null) falla sin escribir nada (#63)")
	_check(origen_vacio(), "migrar desde vacío no es un error (#63)")
	_check(capturas_viajan(), "las capturas se copian de verdad, no se referencian (#63)")
	_check(historial_viaja(), "el historial de estados llega entero (#63)")
	_check(si_se_pierde_algo_se_avisa(), "una migración que pierde datos se marca como fallida (#63)")
	_check(migra_de_es_inversa(), "migra_de() es migra_a() al revés (#63)")
	_check(ficheros_a_unico(), "de ocho ficheros a uno solo: todo acaba en gestorao.json (#63)")
	_check(unico_a_ficheros(), "de uno solo a ocho: los ficheros vuelven y el origen sigue igual (#63)")
	_check(el_controlador_abre(), "el controlador abre el backend que dice la config (#63)")
	_check(el_controlador_abre_base_datos(), "con backend de base de datos el controlador abre el .db (#65)")
	_check(el_controlador_info(), "info() enseña rutas, tamaños y recuentos (#63)")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _preparar() -> void:
	_limpiar()
	for base in [BASE_A, BASE_B]:
		DirAccess.make_dir_recursive_absolute(base)
	_origine()


func _limpiar() -> void:
	for base in [BASE_A, BASE_B]:
		for nombre in AlmacenJson.FICHEROS + [FICHERO, "gestorao.db"]:
			for sufijo in ["", ".tmp", ".bak"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s%s" % [base, nombre, sufijo]))
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


func _origen_png() -> String:
	var img := Image.create(6, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.6, 0.9, 1.0))
	var ruta := "%s/_origen.png" % BASE_B
	img.save_png(ruta)
	return ruta


func _origine() -> void:
	var a := AlmacenJson.new(BASE_A)
	a.abrir()
	a.guardar_entradas([
		{"nombre": "Uno", "url": "https://uno.com", "cat": "cat", "tags": ["a"]},
		{"nombre": "Dos", "url": "https://dos.com", "img": "png/dos.png"},
	])
	a.guardar_estados({
		"https://uno.com": {"valido": true, "mensaje": "OK (200)", "codigo": 200, "historial": [{"codigo": 200}, {"codigo": 0}]},
		"https://dos.com": {"valido": false, "mensaje": "No existe (404)", "codigo": 404, "historial": [{"codigo": 404}]},
	})
	a.guardar_borrados(["https://muerta.com/x"])
	a.guardar_cola(["https://uno.com"])
	a.guardar_config({"tema": "oscuro", "timeout": 9.5})
	a.guardar_instantaneas([{"fecha": "2026-02-01", "total": 2, "validos": 1, "caidos": 1, "sin_comprobar": 0}])
	a.guardar_presets({"mio": {"estado": 1}})
	a.guardar_cambios([{"campo": "nombre", "de": "a", "a": "b"}])
	a.guardar_captura("png/dos.png", _origen_png())


func migra_todo() -> bool:
	_preparar()
	var res := AlmacenJson.new(BASE_A).migra_a(AlmacenJson.new(BASE_B))
	if not res.get("ok", false):
		push_error("detalle: %s / %s" % [str(res.get("detalle", "")), str(res.get("destino", {}))])
		return false
	var b := AlmacenJson.new(BASE_B)
	return b.entradas().size() == 2 and b.estados().size() == 2 and b.borrados().size() == 1 \
		and b.cola() == ["https://uno.com"] and b.config().get("tema", "") == "oscuro" \
		and b.instantaneas().size() == 1 and b.presets().size() == 1 and b.cambios().size() == 1 \
		and b.capturas().has("png/dos.png")


func recuentos_coinciden() -> bool:
	_preparar()
	var res := AlmacenJson.new(BASE_A).migra_a(AlmacenJson.new(BASE_B))
	return res.get("ok", false) and res.get("origen", {}) == res.get("destino", {}) \
		and int(res.get("origen", {}).get("entradas", 0)) == 2 \
		and int(res.get("origen", {}).get("historial", 0)) == 3


func no_toca_el_origen() -> bool:
	_preparar()
	var antes := FileAccess.get_file_as_string("%s/enlaces.json" % BASE_A)
	var antes_estados := FileAccess.get_file_as_string("%s/estados.json" % BASE_A)
	AlmacenJson.new(BASE_A).migra_a(AlmacenJson.new(BASE_B))
	return FileAccess.get_file_as_string("%s/enlaces.json" % BASE_A) == antes \
		and FileAccess.get_file_as_string("%s/estados.json" % BASE_A) == antes_estados


func destino_lleno_rechazado() -> bool:
	_preparar()
	var destino := AlmacenJson.new(BASE_B)
	destino.guardar_entradas([{"nombre": "Ya estaba", "url": "https://previa.com"}])
	var ctrl := _ctrl()
	var res: Dictionary = ctrl.migrar_a_otro(destino)
	# Ni se fusiona ni se pisa: el destino conserva su unica entrada y no gana
	# ni un estado. Un "migrar" encima de datos de otra sesion seria la forma
	# facil de perder el trabajo de otra maquina.
	return not res.get("ok", true) and str(res.get("detalle", "")) != "" \
		and destino.entradas().size() == 1 and destino.estados().is_empty()


func sin_destino_no_pasa() -> bool:
	_preparar()
	var res: Dictionary = AlmacenJson.new(BASE_A).migra_a(null)
	return not res.get("ok", true) and str(res.get("detalle", "")) != "" \
		and AlmacenJson.new(BASE_A).entradas().size() == 2


func origen_vacio() -> bool:
	_limpiar()
	var vacio := AlmacenJson.new(BASE_A)
	vacio.abrir()
	var res: Dictionary = vacio.migra_a(AlmacenJson.new(BASE_B))
	return res.get("ok", false) and AlmacenJson.new(BASE_A).entradas().is_empty() \
		and AlmacenJson.new(BASE_B).entradas().is_empty()


func capturas_viajan() -> bool:
	_preparar()
	AlmacenJson.new(BASE_A).migra_a(AlmacenJson.new(BASE_B))
	# Nada de referencias al origen: si el destino apunta a la ruta del origen,
	# borrar el origen deja las capturas del destino sin fichero.
	var origen := AlmacenJson.new(BASE_A).capturas()
	var destino := AlmacenJson.new(BASE_B).capturas()
	if not destino.has("png/dos.png") or not origen.has("png/dos.png"):
		return false
	return str(destino["png/dos.png"]).begins_with(BASE_B) \
		and not str(destino["png/dos.png"]).begins_with(BASE_A) \
		and FileAccess.file_exists(str(destino["png/dos.png"]))


func historial_viaja() -> bool:
	_preparar()
	AlmacenJson.new(BASE_A).migra_a(AlmacenJson.new(BASE_B))
	return AlmacenJson.new(BASE_B).historial("https://uno.com").size() == 2 \
		and int(AlmacenJson.new(BASE_B).estado("https://dos.com").get("codigo", -1)) == 404


func si_se_pierde_algo_se_avisa() -> bool:
	_preparar()
	var origen := AlmacenJson.new(BASE_A)
	var destino := AlmacenQuePierdeEntradas.new(BASE_B)
	var res: Dictionary = origen.migra_a(destino)
	# Ni "ok" ni un detalle vacio: quien migra tiene que poder decir "no ha ido
	# bien" y no cambiar el almacenamiento activo por un sitio incompleto.
	return not res.get("ok", true) and int(res.get("errores", 0)) > 0 \
		and str(res.get("detalle", "")) != "" \
		and int(res.get("origen", {}).get("entradas", 0)) == 2 \
		and int(res.get("destino", {}).get("entradas", 0)) == 1


func migra_de_es_inversa() -> bool:
	_limpiar()
	AlmacenJson.new(BASE_B).guardar_entradas([{"nombre": "Viejo", "url": "https://viejo.com"}])
	var res: Dictionary = AlmacenJson.new(BASE_A).migra_de(AlmacenJson.new(BASE_B))
	return res.get("ok", false) and res.get("invertida", false) \
		and AlmacenJson.new(BASE_A).entradas().size() == 1


func ficheros_a_unico() -> bool:
	_preparar()
	var destino := AlmacenUno.new(BASE_B)
	destino.abrir()
	var res: Dictionary = AlmacenJson.new(BASE_A).migra_a(destino)
	if not res.get("ok", false):
		return false
	# El destino no puede dejar ni un fichero suelto de los de siempre: si quedara
	# alguno, la proxima apertura en modo único lo ignoraria y habria dos copias
	# del mismo dato sin saber cual manda.
	for nombre in AlmacenJson.FICHEROS:
		if FileAccess.file_exists("%s/%s" % [BASE_B, nombre]):
			return false
	var b := AlmacenUno.new(BASE_B)
	b.abrir()
	return FileAccess.file_exists("%s/%s" % [BASE_B, FICHERO]) \
		and b.entradas().size() == 2 and b.estados().size() == 2 and b.borrados().size() == 1 \
		and b.cola() == ["https://uno.com"] and str(b.config().get("tema", "")) == "oscuro" \
		and b.instantaneas().size() == 1 and b.presets().size() == 1 and b.cambios().size() == 1 \
		and b.capturas().has("png/dos.png")


func unico_a_ficheros() -> bool:
	_preparar()
	var origen := AlmacenUno.new(BASE_B)
	origen.abrir()
	origen.importar(AlmacenJson.new(BASE_A).volcado())
	# El destino arranca vacio: si no, la migracion escribiria encima de los ocho
	# ficheros que ya estan ahi y no se distinguiria de un merge.
	for nombre in AlmacenJson.FICHEROS:
		for sufijo in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s%s" % [BASE_A, nombre, sufijo]))
	_borrar_arbol("%s/Assets" % BASE_A)
	var antes := FileAccess.get_file_as_string("%s/%s" % [BASE_B, FICHERO])
	var res: Dictionary = origen.migra_a(AlmacenJson.new(BASE_A))
	if not res.get("ok", false) or FileAccess.file_exists("%s/%s" % [BASE_A, FICHERO]):
		return false
	for nombre in AlmacenJson.FICHEROS:
		if not FileAccess.file_exists("%s/%s" % [BASE_A, nombre]):
			return false
	return FileAccess.get_file_as_string("%s/%s" % [BASE_B, FICHERO]) == antes \
		and AlmacenJson.new(BASE_A).entradas().size() == 2 \
		and AlmacenJson.new(BASE_A).capturas().has("png/dos.png")


func _ctrl(argumentos := PackedStringArray(), base := BASE_A) -> AlmacenController:
	return AlmacenController.new(argumentos, base, {"modo": "ficheros", "base": base, "ruta_bd": "user://prueba.db"})


func el_controlador_abre() -> bool:
	_preparar()
	var ctrl := _ctrl()
	return ctrl.almacen != null and ctrl.almacen.modo() == "ficheros" and ctrl.almacen.abierto \
		and str(ctrl.config["base"]) == BASE_A


func el_controlador_abre_base_datos() -> bool:
	_preparar()
	var ctrl := AlmacenController.new(PackedStringArray(), BASE_A, {"modo": "base_datos", "base": BASE_A, "ruta_bd": "%s/gestorao.db" % BASE_A})
	return ctrl.almacen != null and ctrl.almacen.modo() == "base_datos" and ctrl.almacen.abierto \
		and ctrl.avisos.is_empty() and ctrl.info().get("modo", "") == "base_datos"


func el_controlador_info() -> bool:
	_preparar()
	var info := _ctrl().info()
	if str(info.get("base", "")) != BASE_A:
		return false
	var ficheros: Array = info.get("ficheros", [])
	if ficheros.size() != AlmacenJson.FICHEROS.size():
		return false
	for entrada in ficheros:
		if int((entrada as Dictionary).get("bytes", -1)) < 0:
			return false
	return int(info.get("total", 0)) > 0 and int(info.get("recuentos", {}).get("entradas", 0)) == 2


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)