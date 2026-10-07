extends SceneTree

class _FakeStore extends RefCounted:
	var estados_borrados: Array = []
	var marcados_borrado: Array = []
	func volcar() -> bool:
		return true
	func cargar() -> Dictionary:
		return {"estados": {}}
	func marcar_borrado(clave: String) -> bool:
		marcados_borrado.append(clave)
		return true
	func borrar_estado(clave: String) -> bool:
		estados_borrados.append(clave)
		return true


const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const ScanControllerScript := preload("res://scripts/scan_controller.gd")
const SeleccionControllerScript := preload("res://scripts/seleccion_controller.gd")
const Ayuda := preload("res://tests/ayuda.gd")

const BASE := "user://__test_main_seleccion__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	ConfigStoreScript.new(BASE).guardar(3, 10.0, false, 0, "oscuro", "", "", 1, "es")
	TranslationServer.set_locale("es")
	# El modo de almacenamiento no se hereda de la maquina: esta suite lee sus
	# rutas de fichero, asi que se fija a ficheros.
	OS.set_environment("GESTORAO_ALMACEN", "ficheros")
	OS.set_environment("GESTORAO_BASE", "")
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "%s/data.json" % BASE
	main.DATA_USER = "%s/enlaces.json" % BASE
	main.CONFIG_BASE = BASE
	main.ASSETS_BASE = "%s/Assets" % BASE
	root.add_child(main)
	await process_frame
	await process_frame

	var s = main.get_node(".")
	s._persistir = false
	s._estado_store = _FakeStore.new()
	s._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": "%s/Assets/png/a.png" % BASE},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": "%s/Assets/png/b.png" % BASE},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": "%s/Assets/png/c.png" % BASE},
		{"nombre": "D", "desc": "", "url": "https://d.test", "img": ""},
	]
	s._estados = {
		"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1},
		"b.test": {"valido": false, "mensaje": "Connection refused", "codigo": 0, "fecha": 1},
		"c.test": {"valido": false, "mensaje": "Not Found", "codigo": 404, "fecha": 1},
		"d.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1},
	}
	s._ui_refrescar()
	await process_frame

	_barra(main, s)
	await _clics(s)
	await _rango(s)
	await _filtro_y_atajos(main, s)
	await _eliminar(main, s)
	await _copiar(s)
	await _exportar(s)
	await _comprobar(main, s)
	await _grilla(main, s)
	_cerrar()


func _fila(s, clave: String):
	for fila in s._ui_filas_visibles():
		if str(fila.url) == "https://%s" % clave:
			return fila
	return null


func _urls(s) -> Array:
	var urls: Array = []
	for fila in s._ui_filas_visibles():
		urls.append(str(fila.url))
	return urls


func _barra(main, s) -> void:
	var barra: FlowContainer = main.get_node("%BarraSeleccion")
	_check(not barra.visible, "sin seleccion la barra de acciones esta escondida")
	_check(main.has_node("%BotonSelTodos"), "hay boton para seleccionar lo que veo")
	_check(main.has_node("%BotonSelComprobar"), "y para comprobar los seleccionados")
	_check(main.has_node("%BotonSelCopiar"), "y para copiar sus urls")
	_check(main.has_node("%BotonSelExportar"), "y para exportar la seleccion")
	_check(main.has_node("%BotonSelEliminar"), "y para borrarlos de una vez")
	_check(main.has_node("%BotonSelLimpiar"), "y para quitar la seleccion")

	s._sel_al_clic("https://a.test", false, false, _fila(s, "a.test"))
	_check(barra.visible, "al elegir algo la barra aparece")
	_check(str(main.get_node("%SelContador").text) == "1 seleccionado", "y el contador va en singular")
	_check(_fila(s, "a.test").seleccionado, "la fila queda marcada")
	_check(_fila(s, "a.test").has_theme_stylebox_override("normal"), "con borde propio")
	_check(not _fila(s, "b.test").has_theme_stylebox_override("normal"), "y las demas no")
	s._sel_limpiar()
	_check(not barra.visible, "al quitar la seleccion la barra se esconde otra vez")
	_check(not _fila(s, "a.test").seleccionado, "y la fila se desmarca")
	_check(not _fila(s, "a.test").has_theme_stylebox_override("normal"), "y pierde el borde")


func _clic(s, clave: String, ctrl := false, mayus := false):
	var fila = _fila(s, clave)
	if fila == null:
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = mayus
	ev.pressed = true
	fila._on_gui_input(ev)


func _clics(s) -> void:
	_clic(s, "a.test", true)
	await process_frame
	_check(s._sel.contar() == 1, "ctrl+clic selecciona la fila")
	_clic(s, "b.test", true)
	await process_frame
	_check(s._sel.contar() == 2, "y ctrl+clic en otra la anade")
	_check(_fila(s, "a.test").seleccionado and _fila(s, "b.test").seleccionado, "las dos quedan marcadas")
	_clic(s, "a.test", true)
	await process_frame
	_check(s._sel.contar() == 1 and not _fila(s, "a.test").seleccionado, "ctrl+clic otra vez la quita")

	s._sel_limpiar()
	_clic(s, "a.test", false)
	await process_frame
	_check(s._sel.contar() == 1, "un clic normal elige una sola fila")
	_check(_fila(s, "a.test").seleccionado, "la que se ha clicado")
	_clic(s, "c.test", false)
	await process_frame
	_check(s._sel.contar() == 1 and _fila(s, "c.test").seleccionado, "otra vez cambia el selected")
	_check(not _fila(s, "a.test").seleccionado, "y suelta la anterior")
	s._sel_limpiar()


func _rango(s) -> void:
	_clic(s, "b.test", false)
	await process_frame
	_clic(s, "d.test", false, true)
	await process_frame
	_check(s._sel.contar() == 3, "mayus+clic marca el rango")
	_check(_fila(s, "c.test").seleccionado, "incluyendo la fila intermedia")
	_check(not _fila(s, "a.test").seleccionado, "y sin cogerse lo que queda antes")
	_check(str(_fila(s, "a.test").tooltip_text).find("Seleccionado:") < 0, "una fila sin seleccionar no anuncia los atajos")
	_check(str(_fila(s, "c.test").tooltip_text).contains("Mayús+Supr"), "la seleccionada explica los atajos en su tooltip")
	s._sel_limpiar()
	await process_frame


func _filtro_y_atajos(main, s) -> void:
	s._sel_todo()
	await process_frame
	_check(s._sel.contar() == 4, "seleccionar lo que veo elige las cuatro filas")

	s._sel_limpiar()
	s.filtro.select(2)
	s._ui_filtro_estado(2)
	await process_frame
	_check(_urls(s) == ["https://b.test", "https://c.test"], "el filtro de caidos deja las dos rotas")
	s._sel_todo()
	await process_frame
	_check(s._sel.contar() == 2, "seleccionar lo que veo con filtro activo elige solo lo visible")
	_check(not s._sel.contiene("https://a.test"), "y no toca lo que el filtro esconde")
	_check(_fila(s, "a.test") == null, "la fila escondida ni siquiera se busca entre las visibles")

	var atajos := [
		["todo", _tecla(true, false, KEY_A)],
		["eliminar", _tecla(false, true, KEY_DELETE)],
	]
	for par in atajos:
		s._unhandled_input(par[1])
		await process_frame
		if str(par[0]) == "todo":
			_check(s._sel.contar() == 2, "ctrl+A elige lo que se ve")
		else:
			_check(main.get_node("%ConfirmarBorrado").visible, "mayus+supr pide confirmacion")
			_check(not str(main.get_node("%ConfirmarBorrado").dialog_text).is_empty(), "con un texto de aviso")
			main.get_node("%ConfirmarBorrado").hide()
			main.get_node("%ConfirmarBorrado").canceled.emit()

	s._unhandled_input(InputEventAction.new())
	s._sel_limpiar()
	s.filtro.select(0)
	s._ui_filtro_estado(0)
	await process_frame


func _tecla(ctrl: bool, mayus: bool, code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.ctrl_pressed = ctrl
	k.shift_pressed = mayus
	k.pressed = true
	return k


func _eliminar(main, s) -> void:
	var carpeta := "%s/Assets/png" % BASE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	for nombre in ["a.png", "b.png", "c.png"]:
		FileAccess.open("%s/%s" % [carpeta, nombre], FileAccess.WRITE).store_string("x")

	_clic(s, "a.test", true)
	await process_frame
	_clic(s, "c.test", true)
	await process_frame
	s._sel_eliminar()
	await process_frame

	var dialogo: ConfirmationDialog = main.get_node("%ConfirmarBorrado")
	_check(dialogo.visible, "eliminar seleccionados pide confirmacion")
	_check(str(dialogo.dialog_text).contains("2"), "una sola confirmacion dice cuantos son")
	_check(not str(dialogo.dialog_text).contains("a.test"), "y no los nombra uno a uno")

	dialogo.hide()
	dialogo.canceled.emit()
	_check(s._dialogos.pendientes_borrado().is_empty(), "al cancelar se olvida la lista pendiente")

	s._ui_eliminar_fila(_fila(s, "a.test"))
	await process_frame
	_check(dialogo.visible, "borrar desde la fila sigue pidiendo confirmacion")
	_check(str(dialogo.dialog_text) == "¿Eliminar «A» para siempre?", "y en singular nombra la etiqueta de la fila")
	dialogo.hide()
	dialogo.canceled.emit()

	s._sel_eliminar()
	await process_frame
	_check(str(dialogo.dialog_text).contains("2"), "y vuelve a preguntar por las dos juntas")
	dialogo.confirmed.emit()
	await process_frame
	_check(s._entradas.size() == 2, "las dos entradas se van de una vez")
	_check(s._buscar_entrada("https://a.test").is_empty(), "A ya no esta")
	_check(not s._buscar_entrada("https://b.test").is_empty(), "B se queda")
	_check(s._buscar_entrada("https://c.test").is_empty(), "C ya no esta")
	_check(not s._buscar_entrada("https://d.test").is_empty(), "D no se ha tocado")
	_check(str(s.progreso.text) == "2 enlaces eliminados", "el aviso cuenta las eliminadas")
	_check(s._sel.contar() == 0, "y la seleccion se vacia sola")
	_check(not main.get_node("%BarraSeleccion").visible, "la barra se esconde")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path("%s/a.png" % carpeta)), "la captura de A se borra al quedar huerfana")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path("%s/c.png" % carpeta)), "la de C tambien")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path("%s/b.png" % carpeta)), "la de B no se toca")
	_check(s._estado_store.marcados_borrado == ["a.test", "c.test"], "el store de estados recibe los dos avisos en orden")
	_check(not s._estados.has("a.test") and not s._estados.has("c.test"), "y sus estados salen del mapa")
	_check(s._estados.has("b.test"), "los de los que se quedan siguen ahi")

	s._ui_refrescar()
	await process_frame


func _copiar(s) -> void:
	_clic(s, "b.test", true)
	await process_frame
	_clic(s, "d.test", true)
	await process_frame
	var urls: Array = s._sel_urls()
	_check(urls == ["https://b.test", "https://d.test"], "las urls salen en el orden en que se eligieron")
	_check(SeleccionControllerScript.texto_urls(urls) == "https://b.test\nhttps://d.test", "y se copian una por linea")
	s._sel_copiar()
	await process_frame
	_check(str(s.progreso.text) == "2 URLs copiadas", "el aviso dice cuantas se han copiado")
	s._sel_limpiar()
	await process_frame
	s._sel_copiar()
	_check(str(s.progreso.text) == "2 URLs copiadas", "sin seleccion no se toca el portapapeles ni se avisa")


func _exportar(s) -> void:
	_clic(s, "b.test", true)
	await process_frame
	_clic(s, "d.test", true)
	await process_frame
	s._sel_exportar()
	await process_frame
	_check(s._urls_informe == ["https://b.test", "https://d.test"], "exportar la seleccion guarda que filas son")
	_check(str(s.get_node("%DialogoInforme").current_file) == "seleccion.csv", "y propone un nombre de fichero")

	var ruta := "%s/solo.csv" % BASE
	s._on_informe_elegido(ruta)
	var texto := FileAccess.get_file_as_string(ruta)
	_check(texto.contains("https://b.test"), "el informe lleva la primera seleccionada")
	_check(texto.contains("https://d.test"), "y la segunda")
	_check(not texto.contains("https://a.test"), "y ninguna de las demas")
	_check(s._urls_informe.is_empty(), "despues de exportar no se recuerda la seleccion para el siguiente guardado")

	var todas := "%s/todas.csv" % BASE
	s._on_informe_elegido(todas)
	var texto_todas := FileAccess.get_file_as_string(todas)
	_check(texto_todas.contains("https://b.test"), "sin seleccion previa el informe sale entero")
	_check(texto_todas.contains("https://d.test"), "con todas las filas del catalogo")
	s._sel_limpiar()
	await process_frame


func _comprobar(main, s) -> void:
	s._scan.configure(func(_i) -> void: pass)
	_clic(s, "b.test", true)
	await process_frame
	_clic(s, "d.test", true)
	await process_frame
	s._sel_comprobar()
	_check(s._scan.activo, "comprobar los seleccionados arranca un escaneo")
	_check(s._scan.total() == 2, "con exactamente las dos filas elegidas")
	_check(s._scan.contar_caidos() == 1, "y solo se fijan los estados de esas dos, no de todo el catalogo")
	_check(str(s.progreso.text) == "Comprobando 0/2…", "y el progreso cuenta las dos")
	_check(main.get_node("%BotonComprobar").disabled, "mientras dura no se relanza el escaneo de todo")
	s._scan.reiniciar()
	main.get_node("%BotonComprobar").disabled = false

	s._sel_limpiar()
	await process_frame
	s._sel_comprobar()
	_check(not s._scan.activo, "sin seleccion no se comprueba nada")


func _grilla(main, s) -> void:
	s._scan.configure(func(_i) -> void: pass)
	s._ui_toggle_vista()
	s._ui_refrescar()
	await process_frame
	_check(s._contenedor_activo().name == "GridContenedor", "se puede pasar a la vista de grilla")
	_check(_urls(s).size() == 2, "las filas se pintan tambien en la grilla")
	s._scan_iniciar()
	_check(s._scan.total() == 2, "el boton comprobar mira lo que se ve en la grilla, no la lista escondida")
	_check(s._scan.contar_caidos() == 1, "y cuenta los caidos de lo que se ve")
	s._scan.reiniciar()

	s.filtro.select(2)
	s._ui_filtro_estado(2)
	await process_frame
	_check(_urls(s) == ["https://b.test"], "con filtro de caidos solo se ve la fila rota de la grilla")
	s._scan_iniciar()
	_check(s._scan.total() == 1, "comprobar en la grilla respeta el filtro")
	s._scan.reiniciar()
	s.filtro.select(0)
	s._ui_filtro_estado(0)
	await process_frame


func _cerrar() -> void:
	Ayuda.borrar_arbol(BASE)
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