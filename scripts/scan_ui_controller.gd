extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const EstadoStoreScript := preload("res://scripts/estado_store.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")

var _scan: Callable = Callable()
var _contenedor: Callable = Callable()
var _arbol: SceneTree = null
var _barra: ProgressBar = null
var _progreso: Label = null
var _boton: Button = null
var _timer: Timer = null
var _reanudar: ConfirmationDialog = null
var _dialogo_cambios: Window = null
var _estado_store: Callable = Callable()
var _estados: Callable = Callable()
var _entradas: Callable = Callable()
var _instantanea: Callable = Callable()
var _cambios_terminar: Callable = Callable()
var _cambios_abrir: Callable = Callable()
var _aplicar_filtro: Callable = Callable()
var _status: Callable = Callable()
var _headless: Callable = Callable()
var _log_scan: Callable = Callable()
var _reintentar: Callable = Callable()
var _red_sin_comprobar: Callable = Callable()
var _certificados: Callable = Callable()
var _auto_abrir: Callable = Callable()


func _init(scan: Callable, contenedor: Callable, arbol: SceneTree, barra: ProgressBar, progreso: Label, boton: Button, timer: Timer, reanudar: ConfirmationDialog, dialogo_cambios: Window, estado_store: Callable, estados: Callable, entradas: Callable, instantanea: Callable, cambios_terminar: Callable, cambios_abrir: Callable, aplicar_filtro: Callable, status: Callable, headless: Callable, log_scan: Callable, reintentar: Callable, red_sin_comprobar: Callable, certificados: Callable, auto_abrir: Callable) -> void:
	_scan = scan
	_contenedor = contenedor
	_arbol = arbol
	_barra = barra
	_progreso = progreso
	_boton = boton
	_timer = timer
	_reanudar = reanudar
	_dialogo_cambios = dialogo_cambios
	_estado_store = estado_store
	_estados = estados
	_entradas = entradas
	_instantanea = instantanea
	_cambios_terminar = cambios_terminar
	_cambios_abrir = cambios_abrir
	_aplicar_filtro = aplicar_filtro
	_status = status
	_headless = headless
	_log_scan = log_scan
	_reintentar = reintentar
	_red_sin_comprobar = red_sin_comprobar
	_certificados = certificados
	_auto_abrir = auto_abrir


func iniciar() -> void:
	var activo: Node = _contenedor.call()
	var visibles: Array = []
	for hijo in activo.get_children():
		if hijo.visible:
			visibles.append(hijo)
	arrancar(visibles, activo.get_children())


func arrancar(items: Array, todos := []) -> void:
	var total: int = _scan.call().preparar(items, todos)
	if total == 0:
		_barra.visible = false
		_progreso.text = tr("Nada que comprobar")
		return
	_boton.disabled = true
	_barra.visible = true
	_barra.remove_theme_stylebox_override("fill")
	barra_actualizar(0, total)
	_progreso.text = tr("Comprobando 0/%d…") % total
	_scan.call().lanzar()


func lanzar_item(item: Button) -> void:
	item.en_escaneo = true
	item.configurar_reintentos(_reintentar.call(), _red_sin_comprobar.call())
	item.configurar_certificados(_certificados.call())
	item.verificacion_terminada.connect(item_terminado.bind(item), CONNECT_ONE_SHOT)
	item.verificar()


func item_terminado(item: Button) -> void:
	if is_instance_valid(item):
		item.en_escaneo = false
	_scan.call().item_terminado(item)


func progreso_actualizado(hechos: int, total: int) -> void:
	barra_actualizar(hechos, total)
	_progreso.text = tr("Comprobando %d/%d…") % [hechos, total]


func item_actualizado(item) -> void:
	if is_instance_valid(item):
		var ahora := int(Time.get_unix_time_from_system())
		var clave_estado := GestorCatalogoScript.clave_unica(item.url)
		_estado_store.call().guardar_estado(clave_estado, item.valido, item.mensaje, item.codigo, item.intentos, item.motivo, str(item.url_final))
		_estados.call()[clave_estado] = {
			"valido": item.valido,
			"mensaje": item.mensaje,
			"codigo": item.codigo,
			"fecha": ahora,
			"intentos": item.intentos,
			"motivo": item.motivo,
			"url_final": str(item.url_final),
		}
		_log_scan.call(item.url, _motivo(item), item.mensaje)
		if item.has_method("marcar_cambio"):
			item.marcar_cambio("")
		if _scan.call().hechos() % EstadoStoreScript.INTERVALO_VOLCADO == 0:
			_estado_store.call().volcar()
	_aplicar_filtro.call()
	_status.call()


func terminado(total: int, caidos: int) -> void:
	_estado_store.call().volcar()
	_boton.disabled = false
	barra_final(caidos)
	_progreso.text = tr("Listo: %d caídos de %d") % [caidos, total]
	_instantanea.call()
	_cambios_terminar.call()


func recomprobar(item: Button) -> void:
	if not is_instance_valid(item):
		return
	if item.estado == "comprobando":
		return
	_progreso.text = tr("Re-comprobando %s…") % item.url
	item.configurar_reintentos(_reintentar.call(), _red_sin_comprobar.call())
	item.configurar_certificados(_certificados.call())
	item.verificacion_terminada.connect(_recompra.bind(item), CONNECT_ONE_SHOT)
	item.verificar()


func revisar_pendientes() -> void:
	var pendientes: Array = _scan.call().pendientes()
	if pendientes.is_empty():
		return
	var validas: Array = _scan.call().pendientes_validas(_entradas.call())
	if validas.is_empty():
		_scan.call().limpiar_cola()
		return
	_reanudar.dialog_text = tr("¿Reanudar escaneo de %d enlaces?") % validas.size()
	_reanudar.popup_centered()


func reanudar() -> void:
	var pendientes: Array = _scan.call().pendientes()
	if pendientes.is_empty():
		return
	var total: int = _scan.call().rearmar_pendientes(pendientes)
	if total == 0:
		_scan.call().limpiar_cola()
		_boton.disabled = false
		return
	_boton.disabled = true
	_barra.visible = true
	_barra.remove_theme_stylebox_override("fill")
	barra_actualizar(0, total)
	_progreso.text = tr("Comprobando 0/%d…") % total
	_scan.call().lanzar()


func descartar_pendientes() -> void:
	_scan.call().limpiar_cola()


func rearmar_auto() -> void:
	var espera: float = _scan.call().auto_espera()
	if espera <= 0.0:
		_timer.stop()
		return
	_timer.wait_time = espera
	_timer.start()


func iniciar_auto() -> void:
	if _headless.call() or not _auto_abrir.call():
		return
	await _arbol.create_timer(0.5).timeout
	await _cambios_abrir.call()
	if _dialogo_cambios.visible:
		await _dialogo_cambios.visibility_changed
	if _scan.call().auto_posible():
		iniciar()
	rearmar_auto()


func auto_timer() -> void:
	if _scan.call().auto_posible():
		iniciar()


func barra_actualizar(hechos: int, total: int) -> void:
	_barra.max_value = maxi(total, 1)
	_barra.value = hechos


func barra_final(caidos: int) -> void:
	_barra.add_theme_stylebox_override("fill", TemaStoreScript.relleno(TemaStoreScript.color_estado(caidos == 0), 0))


func _recompra(item: Button) -> void:
	if not is_instance_valid(item):
		return
	item_actualizado(item)
	_estado_store.call().volcar()


func _motivo(item) -> String:
	if item.valido == true:
		return "valido_tls" if item.motivo == "tls" else "valido"
	if item.valido == null:
		return "sin_comprobar"
	return "caido_tls" if item.motivo == "tls" else "caido"
