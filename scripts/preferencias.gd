extends Window

signal aplicado(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int, tema: String, idioma: String, reintentar_transitorios: bool, red_sin_comprobar: bool, aceptar_certificados: bool, instantaneas_dias: int)

const AlmacenConfigScript := preload("res://scripts/almacen_config.gd")
const AlmacenControllerScript := preload("res://scripts/almacen_controller.gd")
const AlmacenJsonScript := preload("res://scripts/almacen_json.gd")
const AlmacenUnoScript := preload("res://scripts/almacen_uno.gd")

const IDIOMAS := [["es", "Español", "es"], ["en", "English", "gb"]]

@onready var paralelismo_spin: SpinBox = %Paralelismo
@onready var timeout_spin: SpinBox = %Timeout
@onready var auto_abrir_box: CheckBox = %AutoAbrir
@onready var intervalo_auto: OptionButton = %IntervaloAuto
@onready var tema_opcion: OptionButton = %Tema
@onready var idioma_opcion: OptionButton = %Idioma
@onready var reintentar_box: CheckBox = %ReintentarTransitorios
@onready var red_sin_comprobar_box: CheckBox = %RedSinComprobar
@onready var certificados_box: CheckBox = %AceptarCertificados
@onready var instantaneas_spin: SpinBox = %InstantaneasDias
@onready var almacen_modo: OptionButton = %AlmacenModo
@onready var almacen_base: LineEdit = %AlmacenBase
@onready var almacen_detalle: Label = %AlmacenDetalle
@onready var almacen_aviso: Label = %AlmacenAviso

var _almacen_actual: RefCounted = null
var _lector_config: RefCounted = null
# Donde se escribe la preferencia de almacenamiento. Vacio es el de siempre
# (user://almacenamiento.json); las pruebas lo re-apuntan a su carpeta para no
# tocar la configuracion del que este usando la maquina (#63).
var config_ruta := ""


func _ready() -> void:
	for i in IDIOMAS.size():
		var icono: Texture2D = null
		if FileAccess.file_exists("res://Assets/banderas/%s.svg" % IDIOMAS[i][2]):
			icono = load("res://Assets/banderas/%s.svg" % IDIOMAS[i][2])
		idioma_opcion.add_icon_item(icono, IDIOMAS[i][1], i)
	for i in AlmacenControllerScript.MODOS_SELECCION.size():
		almacen_modo.set_item_metadata(i, str(AlmacenControllerScript.MODOS_SELECCION[i]))
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)
	%BotonExaminar.pressed.connect(_examinar_carpeta)
	%BotonAbrirCarpeta.pressed.connect(_abrir_carpeta)
	almacen_modo.item_selected.connect(_modo_elegido)
	%DialogoCarpeta.dir_selected.connect(_carpeta_elegida)


func abrir(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0, tema := "oscuro", idioma := "es", reintentar_transitorios := true, red_sin_comprobar := true, aceptar_certificados := false, instantaneas_dias := 365) -> void:
	paralelismo_spin.value = paralelismo
	timeout_spin.value = timeout
	auto_abrir_box.button_pressed = auto_abrir
	reintentar_box.button_pressed = reintentar_transitorios
	red_sin_comprobar_box.button_pressed = red_sin_comprobar
	certificados_box.button_pressed = aceptar_certificados
	instantaneas_spin.value = instantaneas_dias
	_seleccionar_intervalo(intervalo)
	_seleccionar_tema(tema)
	_seleccionar_idioma(idioma)
	_mostrar_almacen()
	popup_centered()


func _mostrar_almacen() -> void:
	_lector_config = AlmacenConfigScript.new("user://", config_ruta)
	_almacen_actual = AlmacenControllerScript.new(PackedStringArray(), "user://", {}, config_ruta)
	var info: Dictionary = _almacen_actual.info()
	var rec: Dictionary = info.get("recuentos", {})
	almacen_base.text = str(info.get("base", "user://"))
	_seleccionar_modo(str(info.get("modo", "ficheros")))
	almacen_base.tooltip_text = tr("%s\nOrigen: %s") % [str(info.get("base", "")), str(info.get("origen", ""))]
	almacen_detalle.text = tr("Almacenamiento: %s · %d enlaces · %d estados · %d capturas · %s en disco") % [
		str(info.get("modo", "ficheros")),
		int(rec.get("entradas", 0)),
		int(rec.get("estados", 0)),
		int(rec.get("capturas", 0)),
		_tamano_legible(int(info.get("total", 0))),
	]
	var avisos: Array = info.get("avisos", [])
	# En una variable y no en la asignacion: el "\n" de un join pegado al .text
	# parece una cadena de UI y el chequeo de traducciones lo pide (#63).
	var texto := ""
	for aviso in avisos:
		texto += str(aviso) + "\n"
	almacen_aviso.text = texto


func _tamano_legible(bytes: int) -> String:
	if bytes < 1024:
		return tr("%d B") % bytes
	if bytes < 1024 * 1024:
		return tr("%.1f KB") % (float(bytes) / 1024.0)
	return tr("%.1f MB") % (float(bytes) / (1024.0 * 1024.0))


func _examinar_carpeta() -> void:
	%DialogoCarpeta.popup_centered_ratio(0.7)


func _abrir_carpeta() -> void:
	var base := almacen_base.text
	if base.is_empty():
		base = "user://"
	OS.shell_open(ProjectSettings.globalize_path(base))


func _carpeta_elegida(ruta: String) -> void:
	# No se cambia la base en caliente: los stores ya tienen sus rutas y sus
	# ficheros abiertos, y cambiarlos a mitad de sesion es la forma facil de
	# partir un JSON. Se copia todo al sitio nuevo y se deja escrito el fichero
	# de configuracion; el cambio entra en vigor al reiniciar.
	var modo := str(_almacen_actual.config.get("modo", "ficheros"))
	if _migrar_a(AlmacenControllerScript.crear_en(modo, ruta), modo, ruta):
		almacen_aviso.text = tr("Datos copiados a %s. Reinicia para usarlos.") % ruta


func _modo_elegido(indice: int) -> void:
	var modos: Array = AlmacenControllerScript.MODOS_SELECCION
	if indice < 0 or indice >= modos.size():
		return
	var modo := str(modos[indice])
	if modo == str(_almacen_actual.config.get("modo", "ficheros")):
		almacen_aviso.text = ""
		return
	if not AlmacenControllerScript.soporta(modo):
		almacen_aviso.text = tr("El modo «%s» todavía no está disponible.") % modo
		return
	# Cambiar de modo tambien copia: si solo se escribiese la preferencia, el
	# catalogo se quedaria partido entre el almacenamiento viejo y el nuevo.
	# El destino es la otra version de estos mismos datos en esta misma carpeta
	# (los ocho ficheros de antes o el gestorao.json de antes), asi que aqui si
	# se pisa: negarlo dejaria el selector sin poder volver atras (#63).
	var base := almacen_base.text
	if base.is_empty():
		base = "user://"
	if _migrar_a(AlmacenControllerScript.crear_en(modo, base), modo, base, true):
		almacen_aviso.text = tr("Los datos ahora van en %s. Reinicia para usarlos.") % _fichero_de_modo(modo)


func _fichero_de_modo(modo: String) -> String:
	return AlmacenUnoScript.FICHERO if modo == AlmacenUnoScript.MODO_UNICO else str(AlmacenJsonScript.FICHEROS[0])


func _seleccionar_modo(modo: String) -> void:
	for i in almacen_modo.get_item_count():
		if str(almacen_modo.get_item_metadata(i)) == modo:
			almacen_modo.select(i)
			return


func _migrar_a(destino, modo: String, base: String, pisar := false) -> bool:
	# Migrar y guardar la preferencia, en ese orden y con los recuentos de
	# comprobacion por el medio: si la copia pierde algo, no se cambia nada y el
	# gestoror sigue leyendo de donde siempre.
	almacen_aviso.text = ""
	var res: Dictionary = _almacen_actual.migrar_a_otro(destino, pisar)
	if not res.get("ok", false):
		almacen_aviso.text = tr("No se pudo migrar al almacenamiento elegido: %s") % _detalle_migracion(res)
		return false
	var ruta_bd := str(_almacen_actual.config.get("ruta_bd", ""))
	var guardado: Dictionary = _lector_config.guardar(modo, ruta_bd, base)
	if not guardado.get("ok", false):
		almacen_aviso.text = tr("Se copiaron los datos, pero no se pudo guardar la preferencia: %s") % str(guardado.get("error", ""))
		return false
	_mostrar_almacen()
	return true


func _detalle_migracion(res: Dictionary) -> String:
	var detalle := str(res.get("detalle", ""))
	if not detalle.is_empty():
		return detalle
	var origen: Dictionary = res.get("origen", {})
	var destino: Dictionary = res.get("destino", {})
	for clave in origen.keys():
		if int(origen[clave]) != int(destino.get(clave, 0)):
			return tr("%s: %d de %d") % [str(clave), int(destino.get(clave, 0)), int(origen[clave])]
	return tr("recuentos distintos")


func _seleccionar_intervalo(minutos: int) -> void:
	for i in intervalo_auto.get_item_count():
		if intervalo_auto.get_item_id(i) == minutos:
			intervalo_auto.select(i)
			return
	intervalo_auto.select(0)


func _seleccionar_tema(tema: String) -> void:
	tema_opcion.select(0 if tema == "auto" else (2 if tema == "claro" else 1))


func _seleccionar_idioma(idioma: String) -> void:
	for i in IDIOMAS.size():
		if IDIOMAS[i][0] == idioma:
			idioma_opcion.select(i)
			return
	idioma_opcion.select(0)


func _on_guardar() -> void:
	var id_tema := tema_opcion.get_selected_id()
	aplicado.emit(
		int(paralelismo_spin.value),
		float(timeout_spin.value),
		auto_abrir_box.button_pressed,
		intervalo_auto.get_selected_id(),
		"auto" if id_tema == 0 else ("claro" if id_tema == 2 else "oscuro"),
		IDIOMAS[idioma_opcion.get_selected_id()][0],
		reintentar_box.button_pressed,
		red_sin_comprobar_box.button_pressed,
		certificados_box.button_pressed,
		int(instantaneas_spin.value)
	)
	hide()
