extends RefCounted

const FiltrosScript := preload("res://scripts/filtros.gd")
const OrdenadorScript := preload("res://scripts/ordenador.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")

var modo := 0
var cat_id := 0
var clave_cat := ""
var clave_tag := ""
var clave_codigo := ""
var dias := 0
var ahora := 0
var orden_columna := ""
var orden_direccion := 1

var _filas_libres: Array = []
var _vista_pool := ""


func _init(modo_vista := "lista") -> void:
	_vista_pool = modo_vista


func configurar(modo_estado: int, cat: int, clave_cat_seleccionada: String, tag: String, codigo: String, dias_filtro: int, columna := "", direccion := 1) -> void:
	modo = modo_estado
	cat_id = cat
	clave_cat = clave_cat_seleccionada
	clave_tag = tag
	clave_codigo = codigo
	dias = dias_filtro
	orden_columna = columna
	orden_direccion = direccion


func fecha_minima() -> int:
	return FiltrosScript.fecha_desde_dias(dias, ahora)


static func clave_de_categoria(indice: int) -> String:
	if indice <= 0:
		return ""
	var categorias := GestorCatalogoScript.CATEGORIAS
	if indice > categorias.size():
		return ""
	return categorias[indice - 1]


static func clave_de_codigo(indice: int) -> String:
	return "" if indice <= 0 else str(indice)


func fila_visible(fila) -> bool:
	if not is_instance_valid(fila):
		return false
	return FiltrosScript.fila_visible(fila.valido, fila.categoria, modo, cat_id, clave_cat, fila.tags, clave_tag, fila.codigo, clave_codigo, fila.fecha, fecha_minima())


func aplicar(contenedor: Node) -> void:
	if contenedor == null:
		return
	for hijo in contenedor.get_children():
		hijo.visible = fila_visible(hijo)
	ordenar(contenedor)


func ordenar(contenedor: Node) -> void:
	if contenedor == null or orden_columna == "":
		return
	var hijos: Array = contenedor.get_children()
	hijos.sort_custom(func(a, b) -> bool:
		return OrdenadorScript.comparar(a, b, orden_columna, orden_direccion)
	)
	for indice in range(hijos.size()):
		if contenedor.get_child(indice) != hijos[indice]:
			contenedor.move_child(hijos[indice], indice)


func filas_visibles(contenedor: Node) -> Array:
	var visibles: Array = []
	if contenedor == null:
		return visibles
	for hijo in contenedor.get_children():
		if hijo.visible:
			visibles.append(hijo)
	return visibles


func pool_tomar() -> Node:
	if _filas_libres.is_empty():
		return null
	return _filas_libres.pop_back()


func pool_devolver(contenedor: Node) -> void:
	if contenedor == null:
		return
	for hijo in contenedor.get_children():
		if not is_instance_valid(hijo):
			continue
		contenedor.remove_child(hijo)
		if not hijo.reutilizable():
			hijo.queue_free()
			continue
		_filas_libres.append(hijo)


func pool_vaciar() -> void:
	for fila in _filas_libres:
		if is_instance_valid(fila):
			fila.queue_free()
	_filas_libres.clear()


func cambiar_vista(modo_vista: String) -> bool:
	if modo_vista == _vista_pool:
		return false
	_vista_pool = modo_vista
	pool_vaciar()
	return true


func pool_tamano() -> int:
	return _filas_libres.size()
