extends SceneTree

const ColaEscaneoScript := preload("res://scripts/cola_escaneo.gd")

var _fallos := 0
var _lanzados: Array = []


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var escaneo = ColaEscaneoScript.new()
	escaneo.reiniciar()
	_check(escaneo.total == 0 and escaneo.hechos == 0 and escaneo.en_vuelo == 0 and escaneo.pendientes.is_empty(), "reiniciar deja el estado a cero y la cola vacía")

	var items: Array = [_i("a"), _i("b"), _i("c"), _i("d"), _i("e")]
	escaneo.configurar(items, 3, _lanzar_registrar)
	_check(escaneo.total == 5, "configurar cuenta el total de items")
	_check(escaneo.hechos == 0 and escaneo.en_vuelo == 0 and escaneo.paralelismo == 3, "configurar resetea contadores y fija paralelismo")

	_lanzados.clear()
	escaneo.lanzar()
	_check(_lanzados.size() == 3, "lanzar arranca como mucho paralelismo items a la vez")
	_check(escaneo.en_vuelo == 3, "tras lanzar hay 3 en vuelo")
	_check(items.size() == 2, "lanzar consume la cola original (referencia compartida)")
	_check(escaneo.pendientes.size() == 2, "pendientes refleja el resto sin lanzar")

	escaneo.terminar()
	_check(escaneo.en_vuelo == 2 and escaneo.hechos == 1, "terminar libera un hueco y suma hechos")
	_lanzados.clear()
	escaneo.lanzar()
	_check(_lanzados.size() == 1, "tras terminar, lanzar completa el hueco libre")
	_check(escaneo.en_vuelo == 3 and escaneo.pendientes.size() == 1, "vuelve a estar a tope con un pendiente")

	var con_invalidos: Array = [_i("ok1"), null, _i("ok2")]
	var escaneo2 = ColaEscaneoScript.new()
	escaneo2.configurar(con_invalidos, 4, _lanzar_registrar)
	_lanzados.clear()
	escaneo2.lanzar()
	_check(_lanzados.size() == 2, "lanzar salta items inválidos sin reservar hueco")
	_check(escaneo2.en_vuelo == 2 and escaneo2.pendientes.is_empty(), "los inválidos no cuentan como en vuelo")

	escaneo2.terminar()
	_check(escaneo2.en_vuelo == 1 and escaneo2.hechos == 1, "terminar resta en_vuelo con mínimo 0")
	escaneo2.terminar()
	escaneo2.terminar()
	_check(escaneo2.en_vuelo == 0, "terminar por debajo de cero se fija a 0")

	var pend = ColaEscaneoScript.new()
	pend.reiniciar()
	_check(pend.queda_trabajo() == false, "sin cola ni vuelo no queda trabajo")
	pend.configurar([_i("x")], 1, _lanzar_registrar)
	pend.lanzar()
	_check(pend.queda_trabajo() == true, "con items en vuelo queda trabajo aunque la cola esté vacía")
	pend.terminar()
	_check(pend.queda_trabajo() == false, "tras terminar el único item no queda trabajo")

	var secuencia := [_i("r1"), _i("r2"), _i("r3"), _i("r4"), _i("r5")]
	var escaneo3 = ColaEscaneoScript.new()
	escaneo3.configurar(secuencia, 3, _lanzar_registrar)
	_lanzados.clear()
	escaneo3.lanzar()
	escaneo3.terminar()
	escaneo3.lanzar()
	escaneo3.terminar()
	escaneo3.terminar()
	escaneo3.lanzar()
	escaneo3.terminar()
	escaneo3.terminar()
	_check(_lanzados.size() == 5, "secuencia completa lanza los 5 items")
	_check(escaneo3.hechos == 5 and escaneo3.en_vuelo == 0 and escaneo3.pendientes.is_empty(), "al final todo procesado, cola vacía y sin vuelo")

	var tope_host_esc = ColaEscaneoScript.new()
	var host_items: Array = [_i("https://mediafire.com/a"), _i("https://mediafire.com/b"), _i("https://mediafire.com/c")]
	tope_host_esc.configurar(host_items, 4, _lanzar_registrar, 2)
	_lanzados.clear()
	tope_host_esc.lanzar()
	_check(_lanzados.size() == 2, "tope por host limita a 2 concurrentes del mismo dominio")
	_check(tope_host_esc.en_vuelo == 2 and tope_host_esc.pendientes.size() == 1, "el tercero del mismo host queda pendiente sin reservar hueco")
	tope_host_esc.terminar(_lanzados[0])
	_lanzados.clear()
	tope_host_esc.lanzar()
	_check(_lanzados.size() == 1, "al terminar uno, el siguiente del mismo host se lanza")
	_check(tope_host_esc.en_vuelo == 2 and tope_host_esc.pendientes.is_empty(), "el hueco liberado se reutiliza y la cola se vacía")

	var multi_host = ColaEscaneoScript.new()
	var distintos: Array = [_i("https://a.test/1"), _i("https://b.test/2"), _i("https://c.test/3")]
	multi_host.configurar(distintos, 4, _lanzar_registrar, 1)
	_lanzados.clear()
	multi_host.lanzar()
	_check(_lanzados.size() == 3, "tope de 1 por host no limita hosts distintos")

	var sin_tope = ColaEscaneoScript.new()
	var mismo: Array = [_i("https://x.test/1"), _i("https://x.test/2"), _i("https://x.test/3")]
	sin_tope.configurar(mismo, 4, _lanzar_registrar)
	_lanzados.clear()
	sin_tope.lanzar()
	_check(_lanzados.size() == 3, "sin tope por host se lanzan todos (comportamiento previo)")

	_check(ColaEscaneoScript.host_de("https://www.MediaFire.com/archivo") == "mediafire.com", "host_de quita www y normaliza a minúsculas")
	_check(ColaEscaneoScript.host_de("http://mega.nz:8080/x") == "mega.nz", "host_de quita el puerto")
	_check(ColaEscaneoScript.host_de("https://drive.google.com/file/d/1") == "drive.google.com", "host_de ignora la ruta")
	_check(ColaEscaneoScript.host_de("dropbox.com") == "dropbox.com", "host_de acepta URL sin esquema")
	_check(ColaEscaneoScript.host_de("") == "", "host_de de cadena vacía devuelve vacío")

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _i(nombre: String) -> Item:
	var f := Item.new()
	f.url = nombre
	return f


class Item:
	var url := ""


func _lanzar_registrar(item) -> void:
	_lanzados.append(item)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)