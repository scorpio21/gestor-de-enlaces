extends RefCounted

signal progreso(hechos: int, total: int)
signal item_actualizado(item)
signal terminado(total: int, caidos: int)

const ColaEscaneoScript := preload("res://scripts/cola_escaneo.gd")
const ColaStoreScript := preload("res://scripts/cola_store.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")

var paralelismo := 3
var tope_por_host := 2
var intervalo_auto := 0
var auto_abrir := true
var es_headless := false
var activo := false

var _scan = ColaEscaneoScript.new()
var _cola: Array = []
var _todos: Array = []
var _cola_store: RefCounted = null
var _lanzar: Callable = Callable()


func _init(cola_store = null) -> void:
	_cola_store = cola_store if cola_store != null else ColaStoreScript.new()


func configure(lanzar: Callable) -> void:
	_lanzar = lanzar


func escaneo() -> RefCounted:
	return _scan


func reiniciar() -> void:
	_scan.reiniciar()
	_cola = []
	_todos = []
	activo = false


func en_vuelo() -> int:
	return _scan.en_vuelo


func hechos() -> int:
	return _scan.hechos


func total() -> int:
	return _scan.total


func cola() -> Array:
	return _cola


func cola_pendientes() -> int:
	return _scan.pendientes.size()


func pendientes() -> Array:
	if _cola_store == null:
		return []
	var dato: Variant = _cola_store.cargar().get("urls", [])
	return dato if typeof(dato) == TYPE_ARRAY else []


func preparar(items: Array, todos := []) -> int:
	_todos = todos.duplicate() if not todos.is_empty() else items.duplicate()
	_scan.configurar(items, paralelismo, _lanzar, tope_por_host)
	_cola = items
	activo = _scan.total > 0
	if activo:
		persistir_cola()
	return _scan.total


func lanzar() -> void:
	_scan.lanzar()


func item_terminado(item = null) -> bool:
	_scan.terminar(item)
	progreso.emit(_scan.hechos, _scan.total)
	item_actualizado.emit(item)
	if _scan.queda_trabajo():
		_scan.lanzar()
		return false
	activo = false
	limpiar_cola()
	var caidos := contar_caidos()
	terminado.emit(_scan.total, caidos)
	return true


func rearmar_pendientes(pendientes_urls: Array) -> int:
	var seleccion: Array = []
	for item in _todos:
		if is_instance_valid(item) and pendientes_urls.has(item.url):
			seleccion.append(item)
	_todos = seleccion
	return preparar(seleccion)


func contar_caidos() -> int:
	var caidos := 0
	for item in _todos:
		if is_instance_valid(item) and item.valido == false:
			caidos += 1
	return caidos


func persistir_cola() -> void:
	if _cola_store == null:
		return
	var urls: Array = []
	for item in _cola:
		if is_instance_valid(item):
			urls.append(item.url)
	_cola_store.guardar(urls)


func limpiar_cola() -> void:
	if _cola_store != null:
		_cola_store.limpiar()


func pendientes_validas(entradas: Array) -> Array:
	var guardadas := pendientes()
	if guardadas.is_empty():
		return []
	var en_catalogo := {}
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			en_catalogo[GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))] = true
	var validas: Array = []
	for url in guardadas:
		var texto := str(url)
		if en_catalogo.has(GestorCatalogoScript.clave_unica(texto)):
			validas.append(texto)
	return validas


func auto_espera() -> float:
	if es_headless or intervalo_auto <= 0:
		return 0.0
	return float(intervalo_auto * 60)


func auto_posible() -> bool:
	return not es_headless and _cola.is_empty() and _scan.en_vuelo == 0
