extends SceneTree

const ScanControllerScript := preload("res://scripts/scan_controller.gd")
const ColaStoreScript := preload("res://scripts/cola_store.gd")
const BASE := "user://__test_scan__"

var _fallos := 0
var _lanzados: Array = []
var _progresos: Array = []
var _actualizados: Array = []
var _final: Array = []


func _initialize() -> void:
	_limpiar_base()
	_preparar()
	_auto()
	_limpiar_base()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _preparar() -> void:
	_reset()
	var store = ColaStoreScript.new(BASE)
	var ctrl = _nuevo(0, 2)

	var items: Array = [_i("https://a.test"), _i("https://b.test"), _i("https://c.test")]
	var total: int = ctrl.preparar(items, items)
	_check(total == 3, "preparar devuelve el total de la cola")
	_check(ctrl.activo == true, "preparar con items deja el escaneo activo")
	_check(ctrl.hechos() == 0 and ctrl.en_vuelo() == 0, "preparar resetea los contadores")
	_check(_lanzados.is_empty(), "preparar todavía no lanza nada (la UI se prepara antes)")
	_check((store.cargar().get("urls", []) as Array) == ["https://a.test", "https://b.test", "https://c.test"], "preparar persiste la cola antes de empezar")

	ctrl.lanzar()
	_check(_lanzados.size() == 2 and ctrl.en_vuelo() == 2, "lanzar respeta el paralelismo")
	_check(ctrl.item_terminado(_lanzados[0]) == false, "item_terminado devuelve false si queda trabajo")
	_check(ctrl.hechos() == 1, "el contador de hechos sube con cada item terminado")
	_check(_lanzados.size() == 3, "al terminar uno se lanza el siguiente (hueco reutilizado)")
	_check(ctrl.item_terminado(_lanzados[1]) == false, "devuelve false aunque la cola ya esté vacía si algo sigue en vuelo")

	var ultimo: bool = ctrl.item_terminado(_lanzados[2])
	_check(ultimo == true, "el último item terminado devuelve true")
	_check(ctrl.activo == false, "al terminar todo el escaneo queda inactivo")
	_check(ctrl.en_vuelo() == 0 and ctrl.hechos() == 3, "al final no queda nada en vuelo")
	_check((store.cargar().get("urls", []) as Array).is_empty(), "al terminar se limpia la cola persistida")
	_check(_final.size() == 1 and int(_final[0][0]) == 3, "terminado emite el total una sola vez")
	_check(_progresos.size() == 3, "progreso se emite en cada item terminado")
	_check(_actualizados.size() == 3, "item_actualizado se emite en cada item terminado")
	_check(int(_progresos[0][0]) == 1 and int(_final[0][1]) == 0, "el resumen lleva los hechos y los caídos")

	var caidos: Array = [_i("https://x.test"), _i("https://y.test")]
	(caidos[0] as Item).valido = false
	(caidos[1] as Item).valido = null
	_reset()
	ctrl.paralelismo = 2
	var total2: int = ctrl.preparar(caidos, caidos)
	ctrl.lanzar()
	_check(total2 == 2, "la cola de caídos se prepara bien")
	for i in range(2):
		ctrl.item_terminado(_lanzados[i])
	_check(_final.size() == 1 and int(_final[0][1]) == 1, "cuenta como caído solo el valido == false, no el null (#54)")

	_reset()
	ctrl.reiniciar()
	_check(ctrl.activo == false and ctrl.hechos() == 0 and ctrl.en_vuelo() == 0 and ctrl.cola().is_empty(), "reiniciar deja el escaneo a cero y la cola vacía (#62)")

	var vacio: int = ctrl.preparar([], [])
	_check(vacio == 0 and ctrl.activo == false, "preparar una cola vacía devuelve 0 y no activa")
	_check(_lanzados.is_empty() and _final.is_empty(), "una cola vacía no lanza ni emite resumen")
	_check(ctrl.item_terminado() == true, "terminar sin nada pendiente cierra el escaneo")

	var nulo: Array = [_i("https://z.test"), null]
	_reset()
	ctrl.paralelismo = 4
	ctrl.preparar(nulo, [nulo[0]])
	ctrl.lanzar()
	_check(_lanzados.size() == 1, "un item liberado a mitad de cola se salta sin reservar hueco")

	_reset()
	var host = _nuevo(2, 4)
	var misma: Array = [_i("https://mediafire.com/1"), _i("https://mediafire.com/2"), _i("https://mediafire.com/3")]
	host.preparar(misma, misma)
	host.lanzar()
	_check(_lanzados.size() == 2, "el tope por host limita a 2 concurrentes del mismo dominio")
	_check(host.en_vuelo() == 2, "el tercero del mismo host no entra en vuelo")
	var pendiente: int = host.cola_pendientes()
	_check(pendiente == 1, "el item retenido por el tope quedó en la cola, no se perdió")
	host.item_terminado(_lanzados[0])
	_check(_lanzados.size() == 3, "al liberar un hueco del host, entra el tercero pendiente")
	_check(host.en_vuelo() == 2, "vuelve a haber 2 en vuelo del mismo host")
	var segundo = _lanzados[1]
	var tercero = _lanzados[2]
	_check(host.item_terminado(segundo) == false, "con el tercero en vuelo todavía no se cierra el escaneo")
	_check(host.item_terminado(tercero) == true, "terminado el tercero, el escaneo se cierra")
	_check(_final.size() == 1 and int(_final[0][0]) == 3, "con tope por host también se completa la cola entera")


func _auto() -> void:
	var store = ColaStoreScript.new(BASE)
	var ctrl = ScanControllerScript.new(store)
	ctrl.configure(_lanzar)
	ctrl.es_headless = true
	ctrl.intervalo_auto = 15
	_check(ctrl.auto_espera() == 0.0, "en headless el auto-escaneo no espera nada")
	_check(ctrl.auto_posible() == false, "en headless el auto-escaneo no es posible")

	ctrl.es_headless = false
	_check(ctrl.auto_espera() == 900.0, "el intervalo se convierte de minutos a segundos (15 min = 900 s)")
	ctrl.intervalo_auto = 0
	_check(ctrl.auto_espera() == 0.0, "intervalo 0 desactiva la espera automática")
	ctrl.intervalo_auto = -5
	_check(ctrl.auto_espera() == 0.0, "un intervalo negativo no da una espera negativa")

	ctrl.intervalo_auto = 10
	_check(ctrl.auto_posible() == true, "sin cola ni vuelo el auto-escaneo es posible")
	var items: Array = [_i("https://auto.test")]
	ctrl.paralelismo = 1
	_reset()
	ctrl.preparar(items, items)
	_check(ctrl.auto_posible() == false, "con un item en la cola el auto-escaneo espera")
	ctrl.lanzar()
	_check(ctrl.auto_posible() == false, "con algo en vuelo el auto-escaneo espera")
	ctrl.item_terminado(_lanzados[0])
	_check(ctrl.auto_posible() == true, "al terminar el último, el auto-escaneo vuelve a ser posible")

	var store2 = ColaStoreScript.new(BASE)
	var ctrl2 = ScanControllerScript.new(store2)
	ctrl2.configure(_lanzar)
	ctrl2.paralelismo = 1
	var catalogo: Array = [_i("https://a.test"), _i("https://b.test"), _i("https://c.test")]
	ctrl2.preparar([], catalogo)
	_check(ctrl2.pendientes_validas([]).is_empty(), "sin cola guardada no hay urls válidas")

	store2.guardar(["https://a.test", "https://borrado.test"])
	_check(ctrl2.pendientes_validas([{"url": "https://a.test"}, {"url": "https://b.test"}]) == ["https://a.test"], "pendientes_validas se queda solo con las urls del catálogo")
	_check(ctrl2.pendientes_validas([]).is_empty(), "sin entradas de catálogo no hay urls válidas")
	_check(ctrl2.pendientes_validas([{"nombre": "sin url"}]).is_empty(), "una entrada de catálogo sin url no valida nada")

	store2.guardar(["https://b.test", "https://borrado.test"])
	_check(ctrl2.pendientes_validas([{"url": "https://a.test"}, {"url": "https://b.test"}]) == ["https://b.test"], "filtra la cola guardada contra el catálogo")
	_check(ctrl2.pendientes_validas([{"url": "https://otro.test"}]).is_empty(), "si ninguna guardada sigue en el catálogo, no hay nada válido")

	store2.guardar(["https://b.test", "https://borrado.test"])
	_reset()
	var ctrl3 = ScanControllerScript.new(store2)
	ctrl3.limpiar_cola()
	_check((store2.cargar().get("urls", []) as Array).is_empty(), "limpiar_cola borra la cola guardada")
	store2.guardar(["https://b.test", "https://borrado.test"])
	ctrl3.configure(_lanzar)
	ctrl3.paralelismo = 3
	ctrl3.preparar([], catalogo)
	var total: int = ctrl3.rearmar_pendientes(["https://b.test"])
	_check(total == 1, "rearmar_pendientes deja solo los items de la cola guardada")
	_check(ctrl3.cola().size() == 1 and ctrl3.cola()[0].url == "https://b.test", "la cola reconstruida contiene la url pendiente")
	_check(ctrl3.contar_caidos() == 0, "tras rearmar, contar caídos mira solo los items reanudados (#62)")

	var total_vacio: int = ctrl3.rearmar_pendientes(["https://no.test"])
	_check(total_vacio == 0 and ctrl3.activo == false, "reanudar una cola que ya no existe devuelve 0")


func _nuevo(tope_host: int, par: int) -> RefCounted:
	var ctrl = ScanControllerScript.new(ColaStoreScript.new(BASE))
	ctrl.configure(_lanzar)
	ctrl.tope_por_host = tope_host
	ctrl.paralelismo = par
	ctrl.progreso.connect(_on_progreso)
	ctrl.item_actualizado.connect(_on_actualizado)
	ctrl.terminado.connect(_on_terminado)
	return ctrl


func _reset() -> void:
	_lanzados.clear()
	_progresos.clear()
	_actualizados.clear()
	_final.clear()


func _i(url: String) -> Item:
	var item := Item.new()
	item.url = url
	return item


func _lanzar(item) -> void:
	_lanzados.append(item)


func _on_progreso(hechos: int, total: int) -> void:
	_progresos.append([hechos, total])


func _on_actualizado(item) -> void:
	_actualizados.append(item)


func _on_terminado(total: int, caidos: int) -> void:
	_final.append([total, caidos])


class Item:
	var url := ""
	var valido: Variant = null


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _limpiar_base() -> void:
	var ruta := BASE + "/colas.json"
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta)
	if DirAccess.dir_exists_absolute(BASE):
		DirAccess.remove_absolute(BASE)
