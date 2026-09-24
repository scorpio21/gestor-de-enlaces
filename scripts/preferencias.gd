extends Window

signal aplicado(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int, tema: String, idioma: String)

const IDIOMAS := [["es", "Español"], ["en", "English"]]

@onready var paralelismo_spin: SpinBox = %Paralelismo
@onready var timeout_spin: SpinBox = %Timeout
@onready var auto_abrir_box: CheckBox = %AutoAbrir
@onready var intervalo_auto: OptionButton = %IntervaloAuto
@onready var tema_opcion: OptionButton = %Tema
@onready var idioma_opcion: OptionButton = %Idioma


func _ready() -> void:
	for i in IDIOMAS.size():
		var icono: Texture2D = null
		if FileAccess.file_exists("res://Assets/icon/flag_%s.svg" % IDIOMAS[i][0]):
			icono = load("res://Assets/icon/flag_%s.svg" % IDIOMAS[i][0])
		idioma_opcion.add_icon_item(icono, IDIOMAS[i][1], i)
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)


func abrir(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0, tema := "oscuro", idioma := "es") -> void:
	paralelismo_spin.value = paralelismo
	timeout_spin.value = timeout
	auto_abrir_box.button_pressed = auto_abrir
	_seleccionar_intervalo(intervalo)
	_seleccionar_tema(tema)
	_seleccionar_idioma(idioma)
	popup_centered()


func _seleccionar_intervalo(minutos: int) -> void:
	for i in intervalo_auto.get_item_count():
		if intervalo_auto.get_item_id(i) == minutos:
			intervalo_auto.select(i)
			return
	intervalo_auto.select(0)


func _seleccionar_tema(tema: String) -> void:
	tema_opcion.select(1 if tema == "claro" else 0)


func _seleccionar_idioma(idioma: String) -> void:
	for i in IDIOMAS.size():
		if IDIOMAS[i][0] == idioma:
			idioma_opcion.select(i)
			return
	idioma_opcion.select(0)


func _on_guardar() -> void:
	aplicado.emit(
		int(paralelismo_spin.value),
		float(timeout_spin.value),
		auto_abrir_box.button_pressed,
		intervalo_auto.get_selected_id(),
		"claro" if tema_opcion.get_selected_id() == 1 else "oscuro",
		IDIOMAS[idioma_opcion.get_selected_id()][0]
	)
	hide()
