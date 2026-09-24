extends RefCounted

var pendientes: Array = []
var paralelismo := 1
var en_vuelo := 0
var hechos := 0
var total := 0
var _lanzar: Callable = Callable()


func reiniciar() -> void:
	pendientes = []
	paralelismo = 1
	en_vuelo = 0
	hechos = 0
	total = 0


func configurar(items: Array, tope: int, lanzar: Callable) -> void:
	pendientes = items
	paralelismo = tope
	_lanzar = lanzar
	en_vuelo = 0
	hechos = 0
	total = pendientes.size()


func lanzar() -> void:
	while en_vuelo < paralelismo and not pendientes.is_empty():
		var item = pendientes.pop_front()
		if not is_instance_valid(item):
			continue
		en_vuelo += 1
		_lanzar.call(item)


func terminar() -> void:
	en_vuelo = maxi(en_vuelo - 1, 0)
	hechos += 1


func queda_trabajo() -> bool:
	return not pendientes.is_empty() or en_vuelo > 0