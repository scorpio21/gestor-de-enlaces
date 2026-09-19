extends Window

signal aplicado(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int, tema: String)

@onready var paralelismo_spin: SpinBox = %Paralelismo
@onready var timeout_spin: SpinBox = %Timeout
@onready var auto_abrir_box: CheckBox = %AutoAbrir
@onready var intervalo_auto: OptionButton = %IntervaloAuto
@onready var tema_opcion: OptionButton = %Tema


func _ready() -> void:
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)


func abrir(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0, tema := "oscuro") -> void:
	paralelismo_spin.value = paralelismo
	timeout_spin.value = timeout
	auto_abrir_box.button_pressed = auto_abrir
	_seleccionar_intervalo(intervalo)
	_seleccionar_tema(tema)
	popup_centered()


func _seleccionar_intervalo(minutos: int) -> void:
	for i in intervalo_auto.get_item_count():
		if intervalo_auto.get_item_id(i) == minutos:
			intervalo_auto.select(i)
			return
	intervalo_auto.select(0)


func _seleccionar_tema(tema: String) -> void:
	tema_opcion.select(1 if tema == "claro" else 0)


func _on_guardar() -> void:
	aplicado.emit(
		int(paralelismo_spin.value),
		float(timeout_spin.value),
		auto_abrir_box.button_pressed,
		intervalo_auto.get_selected_id(),
		"claro" if tema_opcion.get_selected_id() == 1 else "oscuro"
	)
	hide()
