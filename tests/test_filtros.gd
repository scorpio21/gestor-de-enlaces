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
	_check((FiltrosScript.filtrar(base, "parche mediafire") == [base[0]]), "modo and: dos palabras en la misma entrada")
	_check(FiltrosScript.filtrar(base, "parche dropbox").is_empty(), "modo and: palabras en entradas distintas no coinciden")
	_check((FiltrosScript.filtrar(base, "parche dropbox", "or") == [base[0], base[1]]), "modo or: cualquiera de las palabras coincide")
	_check((FiltrosScript.filtrar(base, "alfa beta", "or") == [base[0], base[1]]), "modo or: nombres de entradas distintas")
	_check(FiltrosScript.filtrar(base, "gamma", "or") == [base[2]], "modo or: una sola palabra como el modo and")
	_check(FiltrosScript.coincide_busqueda(base[0], "dropbox parche", "or"), "coincide_busqueda or directo")
	_check(not FiltrosScript.coincide_busqueda(base[0], "dropbox leon", "or"), "coincide_busqueda or sin coincidencia")

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

	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", ["oso", "glaciar"], "oso") == true, "etiqueta coincidente visible")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", ["oso", "glaciar"], "luna") == false, "otra etiqueta oculta")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", [], "oso") == false, "sin etiquetas oculta con filtro activo")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", ["Glaciar"], "glaciar") == true, "etiqueta sin distinguir mayusculas")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", ["oso"], "") == true, "filtro de etiqueta vacio no filtra")
	_check(FiltrosScript.fila_visible(false, "cliente", 1, 2, "cliente", ["oso"], "oso") == false, "estado no coincide aunque la etiqueta si")
	_check(FiltrosScript.fila_visible(true, "cliente", 1, 2, "cliente", ["oso"], "oso") == true, "estado, categoria y etiqueta coinciden -> visible")

	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", [], "", 404, "") == true, "sin filtro de codigo muestra cualquiera")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", [], "", 404, "404") == true, "codigo coincidente visible")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", [], "", 404, "500") == false, "otro codigo oculta")
	_check(FiltrosScript.fila_visible(false, "cliente", 1, 0, "", [], "", 500, "500") == false, "el codigo no salva un estado filtrado")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", [], "", 0, "", 100, 100) == true, "fecha dentro del rango visible")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", [], "", 0, "", 90, 100) == false, "fecha anterior al minimo oculta")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", [], "", 0, "", 0, 0) == true, "sin rango de fechas no filtra")
	_check(FiltrosScript.fila_visible(true, "cliente", 0, 0, "", [], "", 0, "", 0, 100) == false, "sin comprobar (fecha 0) queda oculta con rango")
	_check(FiltrosScript.fecha_desde_dias(0) == 0, "fecha_desde_dias con 0 devuelve 0")
	_check(FiltrosScript.fecha_desde_dias(0, 5000) == 0, "fecha_desde_dias con 0 no usa ahora")
	_check(FiltrosScript.fecha_desde_dias(7, 1000) == 1000 - 7 * 86400, "fecha_desde_dias resta dias por 86400")

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