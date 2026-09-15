extends SceneTree

const EstadoStore := preload("res://scripts/estado_store.gd")
const BASE := "user://__test_gestor__"

var _fallos := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	_limpiar()
	_check(cargar_vacio(), "cargar() vacío devuelve estados vacíos y borrados vacíos")
	_check(guardar_y_recuperar(), "guardar_estado() persiste y cargar() lo recupera")
	_check(actualizar_entrada(), "guardar_estado() actualiza una entrada existente")
	_check(borrados_sin_duplicados(), "marcar_borrado() no añade duplicados")
	_check(borrar_estado_limpia(), "borrar_estado() elimina la entrada")
	_check(json_roto_no_rompe(), "JSON roto no rompe cargar()")
	_check(guarda_codigo(), "guardar_estado() persiste el código HTTP")
	_check(codigo_por_defecto(), "guardar_estado() sin código persiste 0")
	_check(renombrar_mueve_estado(), "renombrar() traslada el estado a la nueva URL")
	_check(renombrar_actualiza_borrados(), "renombrar() reemplaza la URL en los borrados")
	_check(renombrar_sin_clave(), "renombrar() sin clave previa no falla")
	_check(renombrar_misma_url(), "renombrar() con la misma URL no borra el estado")
	_check(guardar_crea_historial(), "guardar_estado() crea el historial con la primera comprobación")
	_check(historial_nuevos_primero(), "guardar_estado() añade los cambios siempre al principio")
	_limpiar()
	_check(entrada_identica_no_duplica(), "una comprobación idéntica a la última no duplica el historial")
	_check(fecha_cabecera_se_actualiza(), "fecha de cabecera se actualiza aunque la comprobación sea idéntica")
	_check(historial_truncado_50(), "el historial se trunca al límite de 50 entradas")
	_check(historial_de_desconocida(), "historial_de() devuelve array vacío para URL desconocida")
	_check(historial_de_sin_campo(), "historial_de() devuelve array vacío para una entrada antigua sin historial")
	_limpiar()
	_check(borrar_estado_limpia_historial(), "borrar_estado() elimina también el historial")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func cargar_vacio() -> bool:
	var datos := EstadoStore.new(BASE).cargar()
	return datos.has("estados") and datos.has("borrados") \
		and datos["estados"] == {} and datos["borrados"] == []


func guardar_y_recuperar() -> bool:
	var store := EstadoStore.new(BASE)
	if not store.guardar_estado("https://ejemplo.com/a", true, "OK (200)"):
		return false
	var datos := store.cargar()
	var e: Dictionary = datos["estados"].get("https://ejemplo.com/a", {})
	return e.get("valido") == true and e.get("mensaje") == "OK (200)" and int(e.get("fecha", 0)) > 0


func actualizar_entrada() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://ejemplo.com/a", true, "OK (200)")
	store.guardar_estado("https://ejemplo.com/a", false, "No existe (404)")
	var e: Dictionary = store.cargar()["estados"].get("https://ejemplo.com/a", {})
	return e.get("valido") == false and e.get("mensaje") == "No existe (404)"


func borrados_sin_duplicados() -> bool:
	var store := EstadoStore.new(BASE)
	store.marcar_borrado("https://muerto.com/x")
	store.marcar_borrado("https://muerto.com/x")
	return store.cargar()["borrados"] == ["https://muerto.com/x"]


func borrar_estado_limpia() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://ejemplo.com/a", true, "OK (200)")
	store.borrar_estado("https://ejemplo.com/a")
	return store.cargar()["estados"] == {}


func json_roto_no_rompe() -> bool:
	FileAccess.open(BASE + "/estados.json", FileAccess.WRITE).store_string("{no es json")
	FileAccess.open(BASE + "/borrados.json", FileAccess.WRITE).store_string("burro")
	var datos := EstadoStore.new(BASE).cargar()
	return datos["estados"] == {} and datos["borrados"] == []


func guarda_codigo() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://ejemplo.com/a", true, "OK (200)", 200)
	var e: Dictionary = store.cargar()["estados"].get("https://ejemplo.com/a", {})
	return int(e.get("codigo", -1)) == 200


func codigo_por_defecto() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://ejemplo.com/a", true, "OK (200)")
	var e: Dictionary = store.cargar()["estados"].get("https://ejemplo.com/a", {})
	return int(e.get("codigo", -1)) == 0


func renombrar_mueve_estado() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://vieja.com", true, "OK (200)", 200)
	if not store.renombrar("https://vieja.com", "https://nueva.com"):
		return false
	var datos := store.cargar()
	return datos["estados"].has("https://nueva.com") \
		and not datos["estados"].has("https://vieja.com") \
		and int(datos["estados"]["https://nueva.com"].get("codigo", -1)) == 200


func renombrar_actualiza_borrados() -> bool:
	var store := EstadoStore.new(BASE)
	store.marcar_borrado("https://borrada.com")
	if not store.renombrar("https://borrada.com", "https://borrada2.com"):
		return false
	return store.cargar()["borrados"] == ["https://borrada2.com"]


func renombrar_sin_clave() -> bool:
	var store := EstadoStore.new(BASE)
	return store.renombrar("https://fantasma.com", "https://otra.com")


func renombrar_misma_url() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://misma.com", true, "OK (200)", 200)
	if not store.renombrar("https://misma.com", "https://misma.com"):
		return false
	var datos := store.cargar()
	return datos["estados"].has("https://misma.com") \
		and int(datos["estados"]["https://misma.com"].get("codigo", -1)) == 200


func guardar_crea_historial() -> bool:
	var store := EstadoStore.new(BASE)
	if not store.guardar_estado("https://hist.com", true, "OK (200)", 200):
		return false
	var e: Dictionary = store.cargar()["estados"].get("https://hist.com", {})
	var h: Array = e.get("historial", [])
	return h.size() == 1 and int(h[0].get("fecha", 0)) > 0 \
		and h[0].get("valido") == true and h[0].get("codigo") == 200


func historial_nuevos_primero() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://hist.com", true, "OK (200)", 200)
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	var h: Array = store.cargar()["estados"]["https://hist.com"]["historial"]
	return h.size() == 2 and h[0].get("codigo") == 404 and h[1].get("codigo") == 200


func entrada_identica_no_duplica() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	var e: Dictionary = store.cargar()["estados"]["https://hist.com"]
	return int(e.get("historial", []).size()) == 1


func fecha_cabecera_se_actualiza() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	var f1 := int(store.cargar()["estados"]["https://hist.com"].get("fecha", 0))
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	var f2 := int(store.cargar()["estados"]["https://hist.com"].get("fecha", 0))
	return f2 >= f1 and f2 > 0


func historial_truncado_50() -> bool:
	var store := EstadoStore.new(BASE)
	for i in range(55):
		store.guardar_estado("https://hist.com", true, "OK (200)", 100 + i)
	var h: Array = store.cargar()["estados"]["https://hist.com"]["historial"]
	return h.size() == 50 and h[0].get("codigo") == 154


func historial_de_desconocida() -> bool:
	return EstadoStore.new(BASE).historial_de("https://fantasma.com") == []


func historial_de_sin_campo() -> bool:
	var store := EstadoStore.new(BASE)
	FileAccess.open(BASE + "/estados.json", FileAccess.WRITE).store_string(
		'{"https://vieja.com": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1}}'
	)
	return store.historial_de("https://vieja.com") == []


func borrar_estado_limpia_historial() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://hist.com", true, "OK (200)", 200)
	store.borrar_estado("https://hist.com")
	return store.cargar()["estados"] == {}


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE + "/estados.json")
	DirAccess.remove_absolute(BASE + "/borrados.json")