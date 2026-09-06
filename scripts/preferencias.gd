extends Window

signal aplicado(paralelismo: int, timeout: float)

@onready var paralelismo_spin: SpinBox = %Paralelismo
@onready var timeout_spin: SpinBox = %Timeout


func _ready() -> void:
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)


func abrir(paralelismo: int, timeout: float) -> void:
	paralelismo_spin.value = paralelismo
	timeout_spin.value = timeout
	popup_centered()


func _on_guardar() -> void:
	aplicado.emit(int(paralelismo_spin.value), float(timeout_spin.value))
	hide()
