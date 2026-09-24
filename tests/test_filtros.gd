extends SceneTree

const FiltrosScript := preload("res://scripts/filtros.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var base := [
		{"nombre": "Alfa", "desc": "parche v1", "url": "https://mediafire.com/a"},
		{"nombre": "Beta", "desc": "cliente AO", "url": "https://dropbox.com/b"},
		{"nombre": "Gamma", "desc": "", "url": "https://a.test/g"},
	]
	_check(FiltrosScript.filtrar(base, "") == base, "texto vacío devuelve las mismas entradas")
	_check((FiltrosScript.filtrar(base, "alfa") == [base[0]]), "busca por nombre sin distinguir mayúsculas")
	_check((FiltrosScript.filtrar(base, "cliente") == [base[1]]), "busca por descripción")
	_check((FiltrosScript.filtrar(base, "mediafire") == [base[0]]), "busca por URL (issue #35)")
	_check((FiltrosScript.filtrar(base, "dropbox.com/b") == [base[1]]), "busca por URL completa")
	_check((FiltrosScript.filtrar(base, "  ALFA  ") == [base[0]]), "recorta espacios y normaliza a minúsculas")
	_check((FiltrosScript.filtrar(base, "gamma") == [base[2]]), "coincide aunque la descripción esté vacía")
	_check(FiltrosScript.filtrar(base, "nada-que-ver").is_empty(), "sin coincidencias devuelve array vacío")

	var con_basura: Array = base.duplicate()
	con_basura.append("basura")
	_check((FiltrosScript.filtrar(con_basura, "alfa") == [base[0]]), "ignora entradas sin formato de diccionario")

	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "") == true, "modo todos muestra cualquier estado")
	_check(FiltrosScript.fila_visible(true, "cliente", 1, 0, "") == true, "modo válidos muestra valido true")
	_check(FiltrosScript.fila_visible(false, "cliente", 1, 0, "") == false, "modo válidos oculta valido false")
	_check(FiltrosScript.fila_visible(false, "cliente", 2, 0, "") == true, "modo caídos muestra valido false")
	_check(FiltrosScript.fila_visible(true, "cliente", 2, 0, "") == false, "modo caídos oculta valido true")
	_check(FiltrosScript.fila_visible(null, "cliente", 3, 0, "") == true, "modo sin comprobar muestra valido null")
	_check(FiltrosScript.fila_visible(false, "cliente", 3, 0, "") == false, "modo sin comprobar oculta valido false")
	_check(FiltrosScript.fila_visible(true, "otro", 0, 0, "") == true, "cat todas muestra cualquier categoría")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 2, "cliente") == true, "categoría coincidente visible")
	_check(FiltrosScript.fila_visible(true, "otro", 0, 2, "cliente") == false, "otra categoría oculta")
	_check(FiltrosScript.fila_visible(true, "cliente", 1, 2, "cliente") == true, "estado y categoría coinciden → visible")
	_check(FiltrosScript.fila_visible(false, "cliente", 1, 2, "cliente") == false, "estado no coincide aunque la categoría sí")

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