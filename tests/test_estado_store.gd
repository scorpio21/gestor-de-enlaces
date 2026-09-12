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


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE + "/estados.json")
	DirAccess.remove_absolute(BASE + "/borrados.json")