extends Window

signal guardado(datos: Dictionary)

@onready var nombre: LineEdit = %Nombre
@onready var descripcion: LineEdit = %Descripcion
@onready var url: LineEdit = %Url
@onready var error_label: Label = %Error


func _ready() -> void:
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)
	nombre.text_submitted.connect(func(_t: String) -> void: descripcion.grab_focus())
	descripcion.text_submitted.connect(func(_t: String) -> void: url.grab_focus())
	url.text_submitted.connect(func(_t: String) -> void: _on_guardar())


func abrir() -> void:
	nombre.text = ""
	descripcion.text = ""
	url.text = ""
	error_label.text = ""
	popup_centered()
	nombre.grab_focus()


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

	guardado.emit({
		"nombre": n,
		"desc": d,
		"url": u,
	})
	hide()
