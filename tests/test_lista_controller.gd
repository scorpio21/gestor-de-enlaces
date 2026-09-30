extends SceneTree

const ListaControllerScript := preload("res://scripts/lista_controller.gd")
const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")

var _fallos := 0
var _contenedor: VBoxContainer = null


func _initialize() -> void:
	_contenedor = VBoxContainer.new()
	root.add_child(_contenedor)
	_claves()
	_filtro_legible()
	_fila_por_estado()
	_orden()
	_pool()
	_contenedor.queue_free()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _claves() -> void:
	_check(ListaControllerScript.clave_de_categoria(0) == "", "indice 0 de categoría significa 'todas'")
	_check(ListaControllerScript.clave_de_categoria(1) == "otro", "el índice 1 es la primera categoría")
	_check(ListaControllerScript.clave_de_categoria(2) == "cliente", "el índice 2 es la segunda categoría")
	_check(ListaControllerScript.clave_de_categoria(99) == "", "un índice fuera de rango no revienta (#62)")
	_check(ListaControllerScript.clave_de_categoria(-1) == "", "un índice negativo no revienta")

	_check(ListaControllerScript.clave_de_codigo(0) == "", "indice 0 de código significa 'todos'")
	_check(ListaControllerScript.clave_de_codigo(404) == "404", "el código se guarda como texto")
	_check(ListaControllerScript.clave_de_codigo(-3) == "", "un índice de código negativo no revienta")


func _filtro_legible() -> void:
	var ctrl = ListaControllerScript.new()
	_check(ctrl.fecha_minima() == 0, "sin días de filtro no hay fecha mínima")
	ctrl.configurar(0, 0, "", "", "", 7)
	ctrl.ahora = 1_000_000
	_check(ctrl.fecha_minima() == 1_000_000 - 7 * 86400, "el filtro por días convierte a fecha mínima absoluta")
	ctrl.configurar(0, 0, "", "", "", 0)
	_check(ctrl.fecha_minima() == 0, "volver a 0 días desactiva el filtro por fecha")
	_check(ctrl.fila_visible(null) == false, "una fila liberada no se considera visible")


func _fila_por_estado() -> void:
	_vaciar()
	var ok := _fila("https://ok.test", true)
	var caido := _fila("https://caido.test", false)
	var nulo := _fila("https://nulo.test", null)

	var ctrl = ListaControllerScript.new()
	ctrl.configurar(1, 0, "", "", "", 0)
	_check(ctrl.fila_visible(ok) and not ctrl.fila_visible(caido) and not ctrl.fila_visible(nulo), "filtro 'válido' deja solo los true (#54)")

	ctrl.configurar(2, 0, "", "", "", 0)
	_check(not ctrl.fila_visible(ok) and ctrl.fila_visible(caido) and not ctrl.fila_visible(nulo), "filtro 'caído' deja solo los false")

	ctrl.configurar(3, 0, "", "", "", 0)
	_check(not ctrl.fila_visible(ok) and not ctrl.fila_visible(caido) and ctrl.fila_visible(nulo), "filtro 'sin comprobar' deja solo los null")

	ctrl.configurar(0, 0, "", "", "", 0)
	_check(ctrl.fila_visible(ok) and ctrl.fila_visible(caido) and ctrl.fila_visible(nulo), "sin filtro de estado salen las tres")

	_contenedor.add_child(ok)
	_contenedor.add_child(caido)
	_contenedor.add_child(nulo)
	ctrl.configurar(2, 0, "", "", "", 0)
	ctrl.aplicar(_contenedor)
	_check(not ok.visible and caido.visible and not nulo.visible, "aplicar pone la propiedad visible de cada fila")

	ctrl.configurar(0, 0, "", "", "", 0)
	ctrl.aplicar(_contenedor)
	_check(ok.visible and caido.visible and nulo.visible, "quitar el filtro vuelve a mostrar todo")
	_check(ctrl.filas_visibles(_contenedor).size() == 3, "filas_visibles cuenta las que están a la vista")
	_check(ctrl.filas_visibles(null).is_empty(), "filas_visibles de un contenedor nulo no revienta")

	var cat := _fila("https://cat.test", true)
	cat.categoria = "servidor"
	_contenedor.add_child(cat)
	ctrl.configurar(0, 4, "servidor", "", "", 0)
	ctrl.aplicar(_contenedor)
	_check(cat.visible and not ok.visible, "filtro por categoría deja solo las de esa categoría")
	ctrl.configurar(0, 4, "", "", "", 0)
	ctrl.aplicar(_contenedor)
	_check(not cat.visible, "el filtro por categoría depende también de la clave, no solo del índice")

	var con_codigo := _fila("https://404.test", true)
	con_codigo.codigo = 404
	_contenedor.add_child(con_codigo)
	ctrl.configurar(0, 0, "", "", "404", 0)
	ctrl.aplicar(_contenedor)
	_check(con_codigo.visible and not ok.visible, "filtro por código HTTP solo deja los que lo tienen")

	var con_fecha := _fila("https://fecha.test", true)
	con_fecha.fecha = 1_000_000 - 8 * 86400
	_contenedor.add_child(con_fecha)
	ctrl.ahora = 1_000_000
	ctrl.configurar(0, 0, "", "", "", 7)
	ctrl.aplicar(_contenedor)
	_check(not con_fecha.visible, "una fila más antigua que el filtro por días se oculta")

	ctrl.configurar(0, 0, "", "", "", 30)
	ctrl.aplicar(_contenedor)
	_check(con_fecha.visible, "ampliar el rango de días vuelve a mostrar la misma fila")

	ctrl.aplicar(null)
	_check(true, "aplicar con contenedor nulo no revienta (#62)")


func _orden() -> void:
	_vaciar()
	var a := _fila("https://c.test", true)
	a.nombre = "Charlie"
	var b := _fila("https://a.test", true)
	b.nombre = "Alpha"
	var c := _fila("https://b.test", false)
	c.nombre = "Bravo"
	for f in [a, b, c]:
		_contenedor.add_child(f)

	var ctrl = ListaControllerScript.new()
	ctrl.configurar(0, 0, "", "", "", 0)
	ctrl.ordenar(_contenedor)
	_check(_nombres() == ["Charlie", "Alpha", "Bravo"], "sin columna de orden no se reordena nada (#62)")

	ctrl.configurar(0, 0, "", "", "", 0, "nombre", 1)
	ctrl.ordenar(_contenedor)
	_check(_nombres() == ["Alpha", "Bravo", "Charlie"], "orden ascendente por nombre")

	ctrl.configurar(0, 0, "", "", "", 0, "nombre", -1)
	ctrl.ordenar(_contenedor)
	_check(_nombres() == ["Charlie", "Bravo", "Alpha"], "orden descendente por nombre")

	ctrl.configurar(0, 0, "", "", "", 0, "estado", 1)
	ctrl.ordenar(_contenedor)
	_check(_nombres() == ["Alpha", "Charlie", "Bravo"], "orden ascendente por estado deja el caído al final (#54)")

	ctrl.configurar(0, 0, "", "", "", 0, "estado", -1)
	ctrl.ordenar(_contenedor)
	_check(_nombres() == ["Bravo", "Alpha", "Charlie"], "orden descendente por estado pone el caído primero y desempata por url")

	ctrl.configurar(0, 0, "", "", "", 0, "fecha", 1)
	ctrl.ordenar(_contenedor)
	_check(true, "ordenar por fecha no revienta con fechas a cero")

	ctrl.configurar(0, 0, "", "", "", 0, "nombre", 1)
	ctrl.ordenar(null)
	_check(true, "ordenar con contenedor nulo no revienta")


func _pool() -> void:
	_vaciar()
	var ctrl = ListaControllerScript.new()
	_check(ctrl.pool_tomar() == null, "con el pool vacío tomar devuelve null")
	_check(ctrl.pool_tamano() == 0, "el pool arranca vacío")

	var a := _fila("https://a.test", true)
	_contenedor.add_child(a)
	var b := _fila("https://b.test", true)
	_contenedor.add_child(b)
	ctrl.pool_devolver(_contenedor)
	_check(_contenedor.get_child_count() == 0, "devolver saca las filas del contenedor")
	_check(ctrl.pool_tamano() == 2, "devolver guarda las filas reutilizables en el pool")
	_check(a.get_parent() == null and b.get_parent() == null, "las filas devueltas quedan fuera del árbol")

	var retomada: Button = ctrl.pool_tomar()
	_check(retomada == a or retomada == b, "tomar devuelve una de las filas del pool")
	_check(ctrl.pool_tamano() == 1, "tomar descuenta del pool")

	ctrl.pool_devolver(null)
	_check(ctrl.pool_tamano() == 1, "devolver con contenedor nulo no toca el pool (#62)")

	ctrl.cambiar_vista("grilla")
	_check(ctrl.pool_tamano() == 0, "cambiar de vista vacía el pool")
	_check(ctrl.cambiar_vista("grilla") == false, "cambiar a la misma vista no vacía nada")
	_check(ctrl.cambiar_vista("lista") == true, "cambiar a otra vista vacía el pool")

	ctrl.pool_devolver(_contenedor)
	ctrl.pool_vaciar()
	_check(ctrl.pool_tamano() == 0, "pool_vaciar deja el pool a cero")
	ctrl.pool_vaciar()
	_check(true, "pool_vaciar dos veces no revienta (#62)")


func _fila(url: String, valido: Variant) -> Button:
	var item: Button = LIST_ITEM_SCENE.instantiate()
	item.url = url
	item.valido = valido
	return item


func _vaciar() -> void:
	for hijo in _contenedor.get_children():
		_contenedor.remove_child(hijo)
		hijo.queue_free()


func _nombres() -> Array:
	var lista: Array = []
	for hijo in _contenedor.get_children():
		lista.append(hijo.nombre)
	return lista


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)
