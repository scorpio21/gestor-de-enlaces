extends Window

signal guardado(datos: Dictionary)
signal editado(datos: Dictionary, url_original: String)
signal lote_guardado(urls: Array)

const PLACEHOLDER := preload("res://Assets/png/no-disponible.png")
const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")

@onready var nombre: LineEdit = %Nombre
@onready var descripcion: LineEdit = %Descripcion
@onready var url: LineEdit = %Url
@onready var error_label: Label = %Error
@onready var vista_previa: TextureRect = %VistaPrevia
@onready var dialogo_imagen: FileDialog = %DialogoImagen
@onready var fila_modo: HBoxContainer = %FilaModo
@onready var caja_varias: VBoxContainer = %CajaVarias

var _imagen_ruta: String = ""
var _imagen_original: String = ""
var _quitar_imagen := false
var _url_original: String = ""
var _modo: String = "individual"


func _ready() -> void:
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)
	%BotonElegir.pressed.connect(func() -> void: dialogo_imagen.popup_centered())
	%BotonQuitar.pressed.connect(_on_quitar_imagen)
	dialogo_imagen.file_selected.connect(_on_imagen_picked)
	nombre.text_submitted.connect(func(_t: String) -> void: descripcion.grab_focus())
	descripcion.text_submitted.connect(func(_t: String) -> void: url.grab_focus())
	url.text_submitted.connect(func(_t: String) -> void: _on_guardar())
	%Modo.item_selected.connect(_cambiar_modo)
	for i in range(GestorCatalogoScript.CATEGORIAS.size()):
		%Categoria.add_item(GestorCatalogoScript.categoria_display(GestorCatalogoScript.CATEGORIAS[i]))


func abrir() -> void:
	_modo = "individual"
	%Modo.select(0)
	_cambiar_modo(0)
	%Categoria.select(0)
	_url_original = ""
	_imagen_original = ""
	_quitar_imagen = false
	_imagen_ruta = ""
	vista_previa.texture = PLACEHOLDER
	nombre.text = ""
	descripcion.text = ""
	url.text = ""
	error_label.text = ""
	popup_centered()
	nombre.grab_focus()


func abrir_edicion(datos: Dictionary, url_original: String) -> void:
	_modo = "editar"
	fila_modo.visible = false
	%Modo.visible = false
	caja_varias.visible = false
	_mostrar_individual(true)
	nombre.text = str(datos.get("nombre", ""))
	descripcion.text = str(datos.get("desc", ""))
	url.text = str(datos.get("url", ""))
	error_label.text = ""
	_url_original = url_original
	_imagen_original = str(datos.get("img", ""))
	_fijar_imagen(_imagen_original)
	%Categoria.select(GestorCatalogoScript.CATEGORIAS.find(GestorCatalogoScript.normalizar_categoria(datos.get("cat", ""))))
	title = "Editar enlace"
	%BotonGuardar.text = "Guardar cambios"
	popup_centered()
	nombre.grab_focus()


func _cambiar_modo(id: int) -> void:
	_modo = "varias" if id == 1 else "individual"
	fila_modo.visible = true
	%Modo.visible = true
	_mostrar_individual(_modo == "individual")
	if _modo == "varias":
		%ListaUrls.text = ""
		error_label.text = ""
		title = "Agregar varias URLs"
		%BotonGuardar.text = "Agregar"
		%ListaUrls.grab_focus()
	else:
		title = "Agregar enlace"
		%BotonGuardar.text = "Guardar"
		nombre.grab_focus()


func _mostrar_individual(individual: bool) -> void:
	%EtiquetaNombre.visible = individual
	%Nombre.visible = individual
	%EtiquetaDesc.visible = individual
	%Descripcion.visible = individual
	%EtiquetaUrl.visible = individual
	%Url.visible = individual
	%EtiquetaCategoria.visible = individual
	%Categoria.visible = individual
	%VistaPrevia.visible = individual
	%FilaImagen.visible = individual
	caja_varias.visible = not individual


func _fijar_imagen(ruta: String) -> void:
	_imagen_ruta = ""
	_quitar_imagen = false
	if ruta != "" and FileAccess.file_exists(ruta):
		var img := Image.load_from_file(ruta)
		vista_previa.texture = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else PLACEHOLDER
	else:
		vista_previa.texture = PLACEHOLDER


func _on_imagen_picked(ruta: String) -> void:
	var img := Image.load_from_file(ruta)
	if img == null or img.is_empty():
		error_label.text = "No se pudo cargar la imagen."
		return
	_imagen_ruta = ruta
	_quitar_imagen = false
	vista_previa.texture = ImageTexture.create_from_image(img)


func _on_quitar_imagen() -> void:
	_imagen_ruta = ""
	_quitar_imagen = true
	vista_previa.texture = PLACEHOLDER


func _on_guardar() -> void:
	if _modo == "varias":
		_on_guardar_lote()
		return
	var n := nombre.text.strip_edges()
	var d := descripcion.text.strip_edges()
	var u := url.text.strip_edges()

	if n.is_empty():
		error_label.text = "El nombre no puede estar vacío."
		nombre.grab_focus()
		return
	if u.is_empty():
		error_label.text = "La URL no puede estar vacía."
		url.grab_focus()
		return
	if not (u.begins_with("http://") or u.begins_with("https://")):
		error_label.text = "La URL debe empezar por http:// o https://."
		url.grab_focus()
		return

	var img_final := _imagen_original
	if _quitar_imagen:
		img_final = ""
	elif _imagen_ruta != "":
		if _modo == "editar":
			img_final = ""
		else:
			var resultado := GestorImagenesScript.copiar(_imagen_ruta)
			if not resultado.get("ok", false):
				error_label.text = str(resultado.get("error", "No se pudo copiar la imagen."))
				return
			img_final = str(resultado.get("destino", ""))

	var cat_clave: String = GestorCatalogoScript.CATEGORIAS[%Categoria.selected]
	var datos := {"nombre": n, "desc": d, "url": u, "img": img_final, "cat": cat_clave}
	if _modo == "editar" and _imagen_ruta != "" and not _quitar_imagen:
		datos["img_pendiente"] = _imagen_ruta
	hide()
	if _modo == "editar":
		editado.emit(datos, _url_original)
	else:
		guardado.emit(datos)


func _on_guardar_lote() -> void:
	var lineas: Array = []
	for parte in %ListaUrls.text.split("\n"):
		var linea: String = (parte if typeof(parte) == TYPE_STRING else str(parte)).strip_edges()
		if not linea.is_empty():
			lineas.append(linea)
	if lineas.is_empty():
		error_label.text = "Pega al menos una URL."
		%ListaUrls.grab_focus()
		return
	hide()
	lote_guardado.emit(lineas)