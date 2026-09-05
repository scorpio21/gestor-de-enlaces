extends Window

signal guardado(datos: Dictionary)

const PLACEHOLDER := preload("res://Assets/png/no-disponible.png")
const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")

@onready var nombre: LineEdit = %Nombre
@onready var descripcion: LineEdit = %Descripcion
@onready var url: LineEdit = %Url
@onready var error_label: Label = %Error
@onready var vista_previa: TextureRect = %VistaPrevia
@onready var dialogo_imagen: FileDialog = %DialogoImagen

var _imagen_ruta: String = ""


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


func abrir() -> void:
	nombre.text = ""
	descripcion.text = ""
	url.text = ""
	error_label.text = ""
	_on_quitar_imagen()
	popup_centered()
	nombre.grab_focus()


func _on_imagen_picked(ruta: String) -> void:
	_imagen_ruta = ruta
	var img := Image.load_from_file(ruta)
	vista_previa.texture = ImageTexture.create_from_image(img) if img != null else PLACEHOLDER


func _on_quitar_imagen() -> void:
	_imagen_ruta = ""
	vista_previa.texture = PLACEHOLDER


func _on_guardar() -> void:
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

	var resultado_imagen := GestorImagenesScript.copiar(_imagen_ruta)
	if not resultado_imagen.get("ok", false):
		error_label.text = str(resultado_imagen.get("error", "No se pudo copiar la imagen."))
		return

	guardado.emit({
		"nombre": n,
		"desc": d,
		"url": u,
		"img": str(resultado_imagen.get("destino", "")),
	})
	hide()
