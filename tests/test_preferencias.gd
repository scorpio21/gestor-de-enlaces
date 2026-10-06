extends SceneTree

const PREF := preload("res://scenes/Preferencias.tscn")
const AlmacenConfigScript := preload("res://scripts/almacen_config.gd")
const AlmacenJsonScript := preload("res://scripts/almacen_json.gd")
const AlmacenUnoScript := preload("res://scripts/almacen_uno.gd")

const BASE := "user://__test_preferencias_almacen__"

var _fallos := 0
var _aplicado: Variant = null


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var ventana := PREF.instantiate()
	root.add_child(ventana)
	await process_frame

	ventana.aplicado.connect(func(p: int, t: float, a: bool, i: int, tm: String, id: String, rt: bool, rs: bool, ac: bool, inst: int) -> void: _aplicado = [p, t, a, i, tm, id, rt, rs, ac, inst])
	ventana.abrir(5, 20.0, false, 15, "oscuro")
	await process_frame
	_check(is_equal_approx(ventana.get_node("%Paralelismo").value, 5.0), "abrir precarga el paralelismo")
	_check(is_equal_approx(ventana.get_node("%Timeout").value, 20.0), "abrir precarga el timeout")
	_check(ventana.get_node("%AutoAbrir").button_pressed == false \
		and ventana.get_node("%IntervaloAuto").get_selected_id() == 15, "abrir precarga auto_abrir e intervalo")
	_check(ventana.get_node("%Tema").get_selected_id() == 1, "abrir precarga el tema")
	_check(ventana.get_node("%Idioma").get_selected_id() == 0, "abrir precarga el idioma es")
	_check(ventana.get_node("%ReintentarTransitorios").button_pressed == true \
		and ventana.get_node("%RedSinComprobar").button_pressed == true, "abrir deja los reintentos y el «sin comprobar» activados por defecto (#54)")
	_check(ventana.get_node("%AceptarCertificados").button_pressed == false, "abrir deja los certificados TLS no aceptados por defecto (#56)")
	_check(is_equal_approx(ventana.get_node("%InstantaneasDias").value, 365.0), "abrir deja 365 días de instantáneas por defecto (#60)")
	_check(ventana.size.y >= ventana.get_node("Margen/Columna").get_combined_minimum_size().y, \
		"la ventana ajusta su alto al contenido (no desborda ni solapa)")

	ventana.get_node("%BotonCancelar").pressed.emit()
	_check(_aplicado == null and not ventana.visible, "cancelar no emite aplicado y oculta")

	ventana.abrir(5, 20.0, true, 30, "claro", "en", false, false, true, 90)
	await process_frame
	_check(ventana.get_node("%Idioma").get_selected_id() == 1, "abrir precarga el idioma en")
	_check(ventana.get_node("%ReintentarTransitorios").button_pressed == false \
		and ventana.get_node("%RedSinComprobar").button_pressed == false, "abrir precarga las opciones de escaneo (#54)")
	_check(ventana.get_node("%AceptarCertificados").button_pressed == true, "abrir precarga la aceptación de certificados (#56)")
	_check(is_equal_approx(ventana.get_node("%InstantaneasDias").value, 90.0), "abrir precarga la retención de instantáneas (#60)")
	ventana.get_node("%Paralelismo").value = 7
	ventana.get_node("%Timeout").value = 15.0
	ventana.get_node("%AutoAbrir").button_pressed = true
	ventana.get_node("%IntervaloAuto").select(3)
	ventana.get_node("%ReintentarTransitorios").button_pressed = true
	ventana.get_node("%InstantaneasDias").value = 200
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_aplicado != null and _aplicado[0] == 7 and is_equal_approx(_aplicado[1], 15.0), "guardar emite aplicado con paralelismo y timeout")
	_check(_aplicado != null and _aplicado[2] == true and _aplicado[3] == 60, "guardar emite aplicado con auto_abrir e intervalo")
	_check(_aplicado != null and _aplicado[4] == "claro", "guardar emite el tema elegido")
	_check(_aplicado != null and _aplicado[5] == "en", "guardar emite el idioma elegido")
	_check(_aplicado != null and _aplicado[6] == true and _aplicado[7] == false, "guardar emite las opciones de escaneo (#54)")
	_check(_aplicado != null and _aplicado[8] == true, "guardar emite la aceptación de certificados TLS (#56)")
	_check(_aplicado != null and _aplicado[9] == 200, "guardar emite la retención de instantáneas (#60)")

	ventana.abrir(5, 20.0)
	await process_frame
	ventana.get_node("%InstantaneasDias").value = 5
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_aplicado != null and _aplicado[9] == 30, "el spinbox no deja pedir menos de 30 días de instantáneas (#60)")

	ventana.free()
	await _cambio_modo()
	_cerrar()


func _cambio_modo() -> void:
	# Cambiar de modo migra al backend que toca y deja la preferencia escrita, y
	# la vuelta atras tiene que funcionar aunque en la carpeta sigan estando los
	# ficheros del modo anterior (#63). Todo en una carpeta propia y con el
	# fichero de preferencias re-apuntado: ni el catalogo ni la configuracion de
	# la maquina se tocan.
	var real := FileAccess.get_file_as_string("user://almacenamiento.json")
	_borrar_arbol(BASE)
	var datos := "%s/datos" % BASE
	var mudanza := "%s/mudanza" % BASE
	var pref := "%s/almacenamiento.json" % BASE
	DirAccess.make_dir_recursive_absolute(datos)
	AlmacenJsonScript.new(datos).guardar_entradas([{"nombre": "Uno", "url": "https://a.com"}])
	OS.set_environment("GESTORAO_ALMACEN", "ficheros")
	OS.set_environment("GESTORAO_BASE", datos)
	var ventana := PREF.instantiate()
	ventana.config_ruta = pref
	root.add_child(ventana)
	await process_frame
	ventana.abrir(3, 10.0)
	await process_frame
	# De aqui el entorno ya no hace falta: a partir de aqui manda la preferencia
	# que va escribiendo el propio selector.
	OS.set_environment("GESTORAO_ALMACEN", "")
	OS.set_environment("GESTORAO_BASE", "")

	_check(ventana.almacen_modo.get_selected_id() == 0,
		"con el catalogo en ficheros el selector arranca en Ficheros sueltos (#63)")
	ventana._modo_elegido(1)
	_check(FileAccess.file_exists("%s/gestorao.json" % datos) and _entradas_unico(datos) == 1,
		"pasar a un único fichero copia el catálogo a gestorao.json (#63)")
	_check(_modo_de(pref) == AlmacenUnoScript.MODO_UNICO, "la preferencia escrita dice unico (#63)")
	_check(ventana.almacen_modo.get_selected_id() == 1, "el selector queda en el modo elegido (#63)")

	# El catalogo cambia mientras se esta en modo unico: es lo que tiene que
	# aparecer al volver a ficheros.
	var lista: Array = ventana._almacen_actual.almacen.entradas()
	lista.append({"nombre": "Dos", "url": "https://b.com"})
	ventana._almacen_actual.almacen.guardar_entradas(lista)

	ventana._modo_elegido(0)
	_check(AlmacenJsonScript.new(datos).entradas().size() == 2,
		"volver a ficheros lleva los cambios hechos en modo único, con los ficheros viejos encima (#63)")
	_check(_modo_de(pref) == AlmacenJsonScript.MODO_FICHEROS, "la preferencia vuelve a ficheros (#63)")
	_check(ventana.almacen_modo.get_selected_id() == 0, "el selector vuelve a Ficheros sueltos (#63)")

	ventana._modo_elegido(1)
	_check(_entradas_unico(datos) == 2 and _modo_de(pref) == AlmacenUnoScript.MODO_UNICO,
		"se vuelve a un único fichero en la misma carpeta, aunque gestorao.json ya exista (#63)")

	ventana._carpeta_elegida(mudanza)
	_check(FileAccess.file_exists("%s/gestorao.json" % mudanza) and _entradas_unico(mudanza) == 2 \
		and not FileAccess.file_exists("%s/enlaces.json" % mudanza),
		"cambiar de carpeta en modo único lleva gestorao.json, no enlaces.json (#63)")
	_check(_modo_de(pref) == AlmacenUnoScript.MODO_UNICO and _base_de(pref).begins_with(mudanza),
		"cambiar de carpeta no cambia el modo y apunta a la carpeta nueva (#63)")

	ventana._modo_elegido(2)
	_check(ventana.almacen_aviso.text.contains("base_datos") \
		and _modo_de(pref) == AlmacenUnoScript.MODO_UNICO,
		"un modo sin backend no se migra ni se guarda la preferencia (#63)")

	ventana.free()
	_restaurar_config("user://almacenamiento.json", real)
	_borrar_arbol(BASE)


func _entradas_unico(base: String) -> int:
	var uno := AlmacenUnoScript.new(base)
	uno.abrir()
	return uno.entradas().size()


func _modo_de(pref: String) -> String:
	return str(AlmacenConfigScript.new("user://", pref).cargar().get("modo", ""))


func _base_de(pref: String) -> String:
	return str(AlmacenConfigScript.new("user://", pref).cargar().get("base", ""))


func _restaurar_config(ruta: String, texto: String) -> void:
	# Si algo se hubiese colado en el user://almacenamiento.json de la maquina,
	# se devuelve tal cual estaba antes de salir: sin el fichero (si no existia)
	# o con su contenido viejo.
	if texto.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
		return
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_string(texto)
	archivo.close()


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


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
