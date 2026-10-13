extends SceneTree

const ScanUiControllerScript := preload("res://scripts/scan_ui_controller.gd")


class _Scan extends RefCounted:
	var preparados: Array = []
	var todos: Array = []
	var lanzado := false
	var terminados: Array = []
	var limpiezas := 0
	var hechos_fijo := 1
	var pendientes_fijos: Array = []
	var validas_fijas: Array = []
	var rearmados: Array = []
	var espera := 0.0
	var posible := false


	func preparar(items: Array, todos := []) -> int:
		preparados = items
		self.todos = todos
		return items.size()


	func lanzar() -> void:
		lanzado = true


	func item_terminado(item) -> void:
		terminados.append(item)


	func hechos() -> int:
		return hechos_fijo


	func pendientes() -> Array:
		return pendientes_fijos


	func pendientes_validas(_entradas: Array) -> Array:
		return validas_fijas


	func rearmar_pendientes(p: Array) -> int:
		rearmados = p
		return p.size()


	func limpiar_cola() -> void:
		limpiezas += 1


	func auto_espera() -> float:
		return espera


	func auto_posible() -> bool:
		return posible


class _Store extends RefCounted:
	var guardados: Array = []
	var volcados := 0


	func guardar_estado(url: String, valido, mensaje: String, codigo := 0, intentos := 1, motivo := "", url_final := "") -> bool:
		guardados.append({"url": url, "valido": valido, "mensaje": mensaje, "codigo": codigo, "intentos": intentos, "motivo": motivo, "url_final": url_final})
		return true


	func volcar() -> bool:
		volcados += 1
		return true


class _Item extends Button:
	signal verificacion_terminada

	var url := ""
	var valido = null
	var mensaje := ""
	var codigo := 0
	var intentos := 1
	var motivo := ""
	var url_final := ""
	var estado := ""
	var en_escaneo := false
	var reintentos: Array = []
	var certs := false
	var verificado := false
	var marcas: Array = []


	func configurar_reintentos(a, b) -> void:
		reintentos = [a, b]


	func configurar_certificados(c) -> void:
		certs = c


	func verificar() -> void:
		verificado = true


	func marcar_cambio(m) -> void:
		marcas.append(m)


var _fallos := 0
var _barra: ProgressBar = null
var _progreso: Label = null
var _boton: Button = null
var _timer: Timer = null
var _dialogo: ConfirmationDialog = null
var _cambios: Window = null
var _store = null
var _estados := {}
var _logs: Array = []
var _instantaneas := 0
var _cambios_terminar := 0
var _cambios_abrir := 0
var _filtros := 0
var _status := 0
var _headless := true
var _reintentar := true
var _red_sin_comprobar := true
var _certificados := false
var _auto_abrir := true


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_barra = ProgressBar.new()
	_progreso = Label.new()
	_boton = Button.new()
	_timer = Timer.new()
	_dialogo = ConfirmationDialog.new()
	_cambios = Window.new()
	root.add_child(_barra)
	root.add_child(_progreso)
	root.add_child(_boton)
	root.add_child(_timer)
	root.add_child(_dialogo)
	root.add_child(_cambios)
	_store = _Store.new()
	await process_frame

	_a_iniciar()
	_b_arrancar()
	_c_lanzar_item()
	_d_item_actualizado()
	_e_terminado()
	_f_recomprobar()
	_g_pendientes()
	_h_auto()
	_cerrar()


func _ctrl(scan, contenedor: Node, entradas: Array) -> RefCounted:
	return ScanUiControllerScript.new(
		func() -> RefCounted: return scan,
		func() -> Node: return contenedor,
		self,
		_barra,
		_progreso,
		_boton,
		_timer,
		_dialogo,
		_cambios,
		func() -> RefCounted: return _store,
		func() -> Dictionary: return _estados,
		func() -> Array: return entradas,
		func() -> void: _instantaneas += 1,
		func() -> void: _cambios_terminar += 1,
		func() -> void: _cambios_abrir += 1,
		func() -> void: _filtros += 1,
		func() -> void: _status += 1,
		func() -> bool: return _headless,
		func(u: String, r: String, d: String) -> void: _logs.append([u, r, d]),
		func() -> bool: return _reintentar,
		func() -> bool: return _red_sin_comprobar,
		func() -> bool: return _certificados,
		func() -> bool: return _auto_abrir
	)


func _a_iniciar() -> void:
	var cont := VBoxContainer.new()
	var visible := Button.new()
	visible.visible = true
	var oculto := Button.new()
	oculto.visible = false
	cont.add_child(visible)
	cont.add_child(oculto)
	root.add_child(cont)
	var scan = _Scan.new()
	var ctrl = _ctrl(scan, cont, [])
	ctrl.iniciar()
	_check(scan.preparados.size() == 1 and scan.preparados[0] == visible, "iniciar prepara solo los hijos visibles")
	_check(scan.todos.size() == 2, "y pasa todos los hijos como universo")
	cont.queue_free()


func _b_arrancar() -> void:
	var cont := VBoxContainer.new()
	root.add_child(cont)
	var scan = _Scan.new()
	var ctrl = _ctrl(scan, cont, [])
	_boton.disabled = false
	ctrl.arrancar([])
	_check(not _barra.visible, "sin nada que comprobar la barra se oculta")
	_check(_progreso.text == tr("Nada que comprobar"), "y se avisa por el progreso")
	_check(not scan.lanzado, "y no se lanza el escaneo")

	var a := _Item.new()
	var b := _Item.new()
	root.add_child(a)
	root.add_child(b)
	_boton.disabled = false
	ctrl.arrancar([a, b], [a, b])
	_check(_boton.disabled, "con trabajo el boton se deshabilita")
	_check(_barra.visible, "la barra aparece")
	_check(_barra.max_value == 2 and _barra.value == 0, "la barra arranca en 0 de 2")
	_check(_progreso.text == tr("Comprobando 0/%d…") % 2, "el progreso dice 0/2")
	_check(scan.lanzado, "y se lanza el escaneo")
	cont.queue_free()


func _c_lanzar_item() -> void:
	var cont := VBoxContainer.new()
	root.add_child(cont)
	var scan = _Scan.new()
	var ctrl = _ctrl(scan, cont, [])
	_reintentar = true
	_red_sin_comprobar = false
	_certificados = true
	var item := _Item.new()
	root.add_child(item)
	ctrl.lanzar_item(item)
	_check(item.en_escaneo, "lanzar_item marca la fila en escaneo")
	_check(item.reintentos == [true, false], "configura los reintentos con las preferencias")
	_check(item.certs, "configura los certificados")
	_check(item.verificado, "y verifica la fila")
	item.verificacion_terminada.emit()
	_check(not item.en_escaneo, "al terminar la verificacion la fila deja de estar en escaneo")
	_check(scan.terminados.size() == 1 and scan.terminados[0] == item, "y se lo comunica al motor")
	cont.queue_free()


func _d_item_actualizado() -> void:
	var cont := VBoxContainer.new()
	root.add_child(cont)
	var scan = _Scan.new()
	scan.hechos_fijo = 25
	var ctrl = _ctrl(scan, cont, [])
	_estados = {}
	_logs = []
	_filtros = 0
	_status = 0
	_store.guardados = []
	_store.volcados = 0
	var item := _Item.new()
	root.add_child(item)
	item.url = "https://a.test/x"
	item.valido = false
	item.mensaje = "No existe"
	item.codigo = 404
	item.intentos = 2
	ctrl.item_actualizado(item)
	_check(_store.guardados.size() == 1, "el resultado se guarda en el estado")
	_check(_store.guardados[0]["url"] == "a.test/x", "con la clave unica de la url")
	_check(_store.guardados[0]["codigo"] == 404 and _store.guardados[0]["intentos"] == 2, "con el codigo y los intentos")
	_check(_store.volcados == 1, "cada 25 comprobaciones se vuelca el estado")
	_check(_estados.has("a.test/x") and _estados["a.test/x"]["codigo"] == 404, "y el estado en memoria se actualiza")
	_check(_logs.size() == 1 and _logs[0][1] == "caido", "se registra el motivo del resultado")
	_check(item.marcas == [""], "la fila limpia su marca de cambio")
	_check(_filtros == 1 and _status == 1, "refresca filtros y contadores")
	cont.queue_free()


func _e_terminado() -> void:
	var cont := VBoxContainer.new()
	root.add_child(cont)
	var scan = _Scan.new()
	var ctrl = _ctrl(scan, cont, [])
	_store.volcados = 0
	_instantaneas = 0
	_cambios_terminar = 0
	_boton.disabled = true
	ctrl.terminado(5, 2)
	_check(_store.volcados == 1, "al terminar se vuelca el estado")
	_check(not _boton.disabled, "se rehabilita el boton de comprobar")
	_check(_progreso.text == tr("Listo: %d caídos de %d") % [2, 5], "el progreso resume el resultado")
	_check(_instantaneas == 1, "se guarda una instantanea")
	_check(_cambios_terminar == 1, "y se calculan los cambios del dia")
	cont.queue_free()


func _f_recomprobar() -> void:
	var cont := VBoxContainer.new()
	root.add_child(cont)
	var scan = _Scan.new()
	var ctrl = _ctrl(scan, cont, [])
	_reintentar = true
	_red_sin_comprobar = true
	_certificados = false
	_store.guardados = []
	_store.volcados = 0
	var item := _Item.new()
	root.add_child(item)
	item.url = "https://a.test"
	ctrl.recomprobar(item)
	_check(item.verificado, "recomprobar verifica la fila")
	_check(item.reintentos == [true, true] and not item.certs, "con las preferencias actuales")
	_check(_progreso.text == tr("Re-comprobando %s…") % item.url, "avisa de la re-comprobacion")

	item.valido = true
	item.verificacion_terminada.emit()
	_check(_store.guardados.size() == 1, "al re-verificar se actualiza el estado")
	_check(_store.volcados == 1, "y se vuelca")

	var en_curso := _Item.new()
	root.add_child(en_curso)
	en_curso.estado = "comprobando"
	ctrl.recomprobar(en_curso)
	_check(not en_curso.verificado, "una fila ya en comprobacion no se relanza")
	cont.queue_free()


func _g_pendientes() -> void:
	var cont := VBoxContainer.new()
	root.add_child(cont)
	var scan = _Scan.new()
	var ctrl = _ctrl(scan, cont, [])
	_dialogo.hide()
	scan.pendientes_fijos = []
	ctrl.revisar_pendientes()
	_check(not _dialogo.visible, "sin pendientes no se abre el dialogo")

	scan.pendientes_fijos = ["https://x.test/1"]
	scan.validas_fijas = []
	ctrl.revisar_pendientes()
	_check(scan.limpiezas == 1, "pendientes que ya no estan en el catalogo se descartan")

	scan.pendientes_fijos = ["https://x.test/1", "https://x.test/2"]
	scan.validas_fijas = ["https://x.test/1"]
	ctrl.revisar_pendientes()
	_check(_dialogo.dialog_text == tr("¿Reanudar escaneo de %d enlaces?") % 1, "se pregunta por las pendientes validas")

	_boton.disabled = false
	scan.lanzado = false
	scan.pendientes_fijos = ["https://x.test/1"]
	ctrl.reanudar()
	_check(_boton.disabled, "reanudar deshabilita el boton")
	_check(scan.lanzado, "y lanza el escaneo rearmado")

	scan.pendientes_fijos = []
	scan.limpiezas = 0
	ctrl.reanudar()
	_check(scan.limpiezas == 0, "reanudar sin pendientes no toca la cola")

	ctrl.descartar_pendientes()
	_check(scan.limpiezas == 1, "descartar limpia la cola")
	cont.queue_free()


func _h_auto() -> void:
	var cont := VBoxContainer.new()
	var fila := Button.new()
	fila.visible = true
	cont.add_child(fila)
	root.add_child(cont)
	var scan = _Scan.new()
	var ctrl = _ctrl(scan, cont, [])
	_timer.start()
	scan.espera = 0.0
	ctrl.rearmar_auto()
	_check(_timer.is_stopped(), "sin intervalo el timer de auto-escaneo se detiene")
	scan.espera = 900.0
	ctrl.rearmar_auto()
	_check(not _timer.is_stopped(), "con intervalo el timer arranca")
	_check(is_equal_approx(_timer.wait_time, 900.0), "con la espera del motor")
	_timer.stop()

	scan.posible = false
	scan.lanzado = false
	ctrl.auto_timer()
	_check(not scan.lanzado, "el tick automatico no escanea si no es posible")
	scan.posible = true
	ctrl.auto_timer()
	_check(scan.lanzado, "el tick automatico arranca el escaneo")

	_cambios_abrir = 0
	_headless = true
	ctrl.iniciar_auto()
	_check(_cambios_abrir == 0, "en headless el auto-escaneo no abre el dialogo de cambios")
	cont.queue_free()


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_fallos += 1
	print("FALLO: " + msg)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
	else:
		print("%d FALLOS" % _fallos)
		quit(1)
