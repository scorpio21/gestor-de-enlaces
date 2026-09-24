extends RefCounted

var pendientes: Array = []
var paralelismo := 1
var en_vuelo := 0
var hechos := 0
var total := 0
var tope_por_host := 0
var _en_vuelo_por_host := {}
var _lanzar: Callable = Callable()


func reiniciar() -> void:
	pendientes = []
	paralelismo = 1
	en_vuelo = 0
	hechos = 0
	total = 0
	tope_por_host = 0
	_en_vuelo_por_host = {}


func configurar(items: Array, tope: int, lanzar: Callable, tope_host := 0) -> void:
	pendientes = items
	paralelismo = tope
	_lanzar = lanzar
	tope_por_host = tope_host
	en_vuelo = 0
	hechos = 0
	total = pendientes.size()
	_en_vuelo_por_host = {}


func lanzar() -> void:
	var pasada := pendientes.size()
	var escaneados := 0
	while en_vuelo < paralelismo and not pendientes.is_empty() and escaneados < pasada:
		var item = pendientes.pop_front()
		escaneados += 1
		if not is_instance_valid(item):
			continue
		var host := host_de(item.url)
		if tope_por_host > 0 and _en_vuelo_por_host.get(host, 0) >= tope_por_host:
			pendientes.append(item)
			continue
		en_vuelo += 1
		if tope_por_host > 0:
			_en_vuelo_por_host[host] = _en_vuelo_por_host.get(host, 0) + 1
		_lanzar.call(item)


func terminar(item = null) -> void:
	en_vuelo = maxi(en_vuelo - 1, 0)
	hechos += 1
	if tope_por_host > 0 and is_instance_valid(item):
		var host := host_de(item.url)
		_en_vuelo_por_host[host] = maxi(_en_vuelo_por_host.get(host, 0) - 1, 0)


func queda_trabajo() -> bool:
	return not pendientes.is_empty() or en_vuelo > 0


static func host_de(url: String) -> String:
	var rest := url
	var idx := rest.find("://")
	if idx >= 0:
		rest = rest.substr(idx + 3)
	var slash := rest.find("/")
	if slash >= 0:
		rest = rest.substr(0, slash)
	var colon := rest.find(":")
	if colon >= 0:
		rest = rest.substr(0, colon)
	if rest.begins_with("www."):
		rest = rest.substr(4)
	return rest.to_lower()