extends Control

const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")
const DATA_RES := "res://data/data.json"
const DATA_USER := "user://enlaces.json"
const MAX_PARALELO := 3

@onready var lista: VBoxContainer = %ListaContenedor
@onready var busqueda: LineEdit = %Busqueda
@onready var progreso: Label = %Progreso
@onready var filtro: OptionButton = %FiltroEstado
@onready var ventana_agregar = %VentanaAgregar

var _entradas: Array = []
var _cola: Array[Button] = []
var _en_vuelo := 0
var _hechos := 0
var _total := 0


func _ready() -> void:
	_configurar_menus()
	busqueda.text_changed.connect(_on_busqueda_changed)
	%BotonComprobar.pressed.connect(_comprobar_visibles)
	filtro.clear()
	filtro.add_item("Todos", 0)
	filtro.add_item("Válidos", 1)
	filtro.add_item("Caídos / no existen", 2)
	filtro.add_item("Sin comprobar", 3)
	filtro.select(0)
	filtro.item_selected.connect(func(_i: int) -> void: _aplicar_filtro())
	ventana_agregar.guardado.connect(_on_enlace_guardado)
	_cargar_datos()
	_refrescar_vista()


func _configurar_menus() -> void:
	var menu_file: PopupMenu = %File
	menu_file.clear()
	menu_file.add_item("Salir", 0)
	menu_file.id_pressed.connect(_on_file_id)

	var menu_util: PopupMenu = %Utilidades
	menu_util.clear()
	menu_util.add_item("Agregar", 0)
	menu_util.id_pressed.connect(_on_utilidades_id)


func _on_file_id(id: int) -> void:
	if id == 0:
		get_tree().quit()


func _on_utilidades_id(id: int) -> void:
	if id == 0:
		ventana_agregar.abrir()


func _cargar_datos() -> void:
	var base := _leer_array(DATA_RES)
	var usuario := _leer_array(DATA_USER)
	_entradas = base
	if usuario.is_empty():
		return
	var urls := {}
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			urls[str(entrada.get("url", ""))] = true
	for entrada in usuario:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var url := str(entrada.get("url", ""))
		if url.is_empty() or urls.has(url):
			continue
		_entradas.append(entrada)
		urls[url] = true


func _leer_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var archivo := FileAccess.open(path, FileAccess.READ)
	if archivo == null:
		return []
	var parseado: Variant = JSON.parse_string(archivo.get_as_text())
	if typeof(parseado) != TYPE_ARRAY:
		return []
	return parseado


func _guardar_datos() -> bool:
	var texto := JSON.stringify(_entradas, "\t")
	if not _escribir_archivo(DATA_USER, texto):
		progreso.text = "No se pudo guardar el enlace."
		return false
	_escribir_archivo(DATA_RES, texto)
	return true


func _escribir_archivo(path: String, texto: String) -> bool:
	var archivo := FileAccess.open(path, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(texto)
	archivo.close()
	return true


func _on_enlace_guardado(datos: Dictionary) -> void:
	_entradas.append(datos)
	if not _guardar_datos():
		_entradas.pop_back()
		return
	_refrescar_vista()
	progreso.text = "Enlace agregado: %s" % datos.get("nombre", "")


func _refrescar_vista() -> void:
	_mostrar_lista(_filtrar_busqueda(busqueda.text))


func _filtrar_busqueda(texto: String) -> Array:
	var filtro_texto := texto.strip_edges().to_lower()
	if filtro_texto.is_empty():
		return _entradas

	var filtradas: Array = []
	for entrada in _entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var haystack := "%s %s" % [entrada.get("nombre", ""), entrada.get("desc", "")]
		if filtro_texto in haystack.to_lower():
			filtradas.append(entrada)
	return filtradas


func _mostrar_lista(entradas: Array) -> void:
	_cola.clear()
	_en_vuelo = 0
	for hijo in lista.get_children():
		hijo.queue_free()

	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var item: Button = LIST_ITEM_SCENE.instantiate()
		item.setup(
			str(entrada.get("nombre", "")),
			str(entrada.get("desc", "")),
			str(entrada.get("url", ""))
		)
		lista.add_child(item)

	_aplicar_filtro()
	progreso.text = "%d enlaces" % lista.get_child_count()


func _comprobar_visibles() -> void:
	_cola.clear()
	for hijo in lista.get_children():
		if hijo.visible:
			_cola.append(hijo)

	_total = _cola.size()
	_hechos = 0
	_en_vuelo = 0
	if _total == 0:
		progreso.text = "Nada que comprobar"
		return

	%BotonComprobar.disabled = true
	progreso.text = "Comprobando 0/%d…" % _total
	_lanzar_siguiente()


func _lanzar_siguiente() -> void:
	while _en_vuelo < MAX_PARALELO and not _cola.is_empty():
		var item: Button = _cola.pop_front()
		if not is_instance_valid(item):
			continue
		_en_vuelo += 1
		item.verificacion_terminada.connect(_on_item_terminado, CONNECT_ONE_SHOT)
		item.verificar()


func _on_item_terminado() -> void:
	_en_vuelo = maxi(_en_vuelo - 1, 0)
	_hechos += 1
	progreso.text = "Comprobando %d/%d…" % [_hechos, _total]
	_aplicar_filtro()
	if not _cola.is_empty() or _en_vuelo > 0:
		_lanzar_siguiente()
		return

	%BotonComprobar.disabled = false
	var caidos := 0
	for hijo in lista.get_children():
		if hijo.valido == false:
			caidos += 1
	progreso.text = "Listo: %d caídos de %d" % [caidos, _total]


func _aplicar_filtro() -> void:
	var modo := filtro.get_selected_id()
	for hijo in lista.get_children():
		match modo:
			1:
				hijo.visible = hijo.valido == true
			2:
				hijo.visible = hijo.valido == false
			3:
				hijo.visible = hijo.valido == null
			_:
				hijo.visible = true


func _on_busqueda_changed(_texto: String) -> void:
	_refrescar_vista()
