extends SceneTree

const FiltrosPresetsControllerScript := preload("res://scripts/filtros_presets_controller.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")


class _Presets extends RefCounted:
	var aplicar_res := {}
	var nombres_res: Array = []
	var nombre_ok_res := true
	var guardar_res := {}
	var borrar_res := {}
	var guardados: Array = []
	var aplicados: Array = []
	var ok_llamadas: Array = []


	func aplicar_preset(_presets: Dictionary, nombre: String) -> Dictionary:
		aplicados.append(nombre)
		return aplicar_res


	func nombre_ok(nombre: String) -> bool:
		ok_llamadas.append(nombre)
		return nombre_ok_res


	func guardar_preset(_presets: Dictionary, _nombre: String, _cfg: Dictionary) -> Dictionary:
		return guardar_res


	func borrar_preset(_presets: Dictionary, _nombre: String) -> Dictionary:
		return borrar_res


	func guardar(presets: Dictionary) -> void:
		guardados.append(presets)


	func nombres(_presets: Dictionary) -> Array:
		return nombres_res


var _fallos := 0
var _filtro: OptionButton = null
var _filtro_cat: OptionButton = null
var _filtro_tag: OptionButton = null
var _filtro_codigo: OptionButton = null
var _filtro_modo: OptionButton = null
var _filtro_dias: SpinBox = null
var _campo_busqueda: LineEdit = null
var _preset_filtros: OptionButton = null
var _nombre_preset: LineEdit = null
var _dialogo_preset: AcceptDialog = null
var _progreso: Label = null
var _espera: Timer = null
var _presets_store: _Presets = null
var _entradas: Array = []
var _presets_val := {}
var _set_valor := {}
var _refrescos := 0
var _persistidos := 0
var _aplicados := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_filtro = OptionButton.new()
	_filtro_cat = OptionButton.new()
	_filtro_tag = OptionButton.new()
	_filtro_codigo = OptionButton.new()
	_filtro_modo = OptionButton.new()
	_filtro_dias = SpinBox.new()
	_campo_busqueda = LineEdit.new()
	_preset_filtros = OptionButton.new()
	_nombre_preset = LineEdit.new()
	_dialogo_preset = AcceptDialog.new()
	_progreso = Label.new()
	_espera = Timer.new()
	root.add_child(_espera)
	root.add_child(_dialogo_preset)
	_presets_store = _Presets.new()
	await process_frame

	_a_cargar_filtros()
	_b_lectores()
	_c_busqueda()
	_d_handlers()
	_e_presets()
	_f_config()
	_cerrar()


func _ctrl() -> RefCounted:
	return FiltrosPresetsControllerScript.new(
		_filtro,
		_filtro_cat,
		_filtro_tag,
		_filtro_codigo,
		_filtro_modo,
		_filtro_dias,
		_campo_busqueda,
		_preset_filtros,
		_nombre_preset,
		_dialogo_preset,
		_progreso,
		_espera,
		func() -> Array: return _entradas,
		func() -> RefCounted: return _presets_store,
		func() -> Dictionary: return _presets_val,
		func(valor: Dictionary) -> void: _set_valor = valor,
		func() -> void: _refrescos += 1,
		func() -> void: _persistidos += 1,
		func() -> void: _aplicados += 1
	)


func _a_cargar_filtros() -> void:
	_entradas = [{"nombre": "A", "url": "https://a.test", "tags": ["uno", "dos"]}]
	var ctrl := _ctrl()
	ctrl.cargar_filtros()
	_check(_filtro.item_count == 4, "el filtro de estado tiene 4 opciones")
	_check(_filtro_modo.item_count == 2, "el filtro de modo tiene 2 opciones")
	_check(_filtro_codigo.item_count == 9, "el filtro de codigo tiene Todos + 8 codigos")
	_check(_filtro_cat.item_count == GestorCatalogoScript.CATEGORIAS.size() + 1, "el filtro de categoria tiene Todas + las categorias")
	_check(_filtro_tag.item_count >= 3, "el filtro de etiqueta lista las etiquetas frecuentes")
	_aplicados = 0
	_persistidos = 0
	_filtro.item_selected.emit(2)
	_check(_aplicados == 1 and _persistidos == 1, "elegir un estado aplica el filtro y persiste")
	ctrl.cargar_filtros()
	_aplicados = 0
	_filtro.item_selected.emit(1)
	_check(_aplicados == 1, "recargar los filtros no duplica la señal")


func _b_lectores() -> void:
	var ctrl := _ctrl()
	ctrl.cargar_filtros()
	_filtro_tag.select(1)
	_check(ctrl.etiqueta_seleccionada() == _filtro_tag.get_item_text(1), "etiqueta_seleccionada devuelve el texto elegido")
	_check(ctrl.indice_etiqueta(ctrl.etiqueta_seleccionada()) == 1, "indice_etiqueta encuentra la etiqueta")
	_check(ctrl.indice_etiqueta("no-existe-xyz") == 0, "indice_etiqueta cae a Todos si no la encuentra")
	_filtro_codigo.select(3)
	_check(ctrl.codigo_seleccionado() == str(_filtro_codigo.get_selected_id()), "codigo_seleccionado devuelve el id elegido")
	_check(ctrl.indice_codigo(ctrl.codigo_seleccionado()) == 3, "indice_codigo encuentra el codigo")
	_check(ctrl.indice_codigo("") == 0, "indice_codigo vacio cae a Todos")
	_filtro_modo.select(1)
	_check(ctrl.modo_busqueda() == "or", "modo_busqueda or con Cualquier palabra")
	_filtro_modo.select(0)
	_check(ctrl.modo_busqueda() == "and", "modo_busqueda and por defecto")


func _c_busqueda() -> void:
	var ctrl := _ctrl()
	_refrescos = 0
	_persistidos = 0
	ctrl.busqueda_cambiada("x")
	_check(not _espera.is_stopped(), "escribir arranca el temporizador de busqueda")
	ctrl.busqueda_aplicar()
	_check(_refrescos == 1, "aplicar la busqueda refresca")
	ctrl.busqueda_guardar()
	_check(_persistidos == 1, "perder el foco persiste")
	ctrl.busqueda_enviada("x")
	_check(_espera.is_stopped(), "enviar detiene el temporizador")
	_check(_refrescos == 2 and _persistidos == 2, "enviar refresca y persiste")


func _d_handlers() -> void:
	var ctrl := _ctrl()
	for handler in [ctrl.filtro_estado, ctrl.filtro_categoria, ctrl.filtro_etiqueta, ctrl.filtro_codigo, ctrl.filtro_dias]:
		_aplicados = 0
		_persistidos = 0
		handler.call(0)
		_check(_aplicados == 1 and _persistidos == 1, "los filtros aplican y persisten")
	_refrescos = 0
	_persistidos = 0
	ctrl.filtro_modo(0)
	_check(_refrescos == 1 and _persistidos == 1, "cambiar el modo refresca y persiste")


func _e_presets() -> void:
	var ctrl := _ctrl()
	ctrl.cargar_filtros()
	_presets_store.nombres_res = ["A", "B"]
	ctrl.presets_recargar_ui()
	_check(_preset_filtros.item_count == 3, "el selector de presets tiene Presets… + los guardados")
	_check(_preset_filtros.get_item_text(1) == "A", "y lista los nombres")
	_check(_preset_filtros.get_selected() == 0, "y vuelve a la opcion inicial")
	_preset_filtros.item_selected.emit(2)
	_check(_presets_store.aplicados.has("B"), "elegir un preset lo aplica")

	var cfg := {
		"filtro_estado": 2,
		"filtro_categoria": 1,
		"filtro_etiqueta": "",
		"filtro_codigo": "404",
		"filtro_dias": 7,
		"busqueda_modo": "or",
		"busqueda": "srv",
	}
	_presets_store.aplicar_res = cfg
	_refrescos = 0
	_persistidos = 0
	ctrl.aplicar_preset("B")
	_check(_filtro.get_selected_id() == 2, "el preset fija el estado")
	_check(_filtro_cat.get_selected_id() == 1, "y la categoria")
	_check(_filtro_dias.value == 7, "y los dias")
	_check(_campo_busqueda.text == "srv", "y la busqueda")
	_check(ctrl.modo_busqueda() == "or", "y el modo")
	_check(_refrescos == 1 and _persistidos == 1, "y refresca y persiste")
	_presets_store.aplicar_res = {}
	ctrl.aplicar_preset("Nada")
	_check(_preset_filtros.get_selected() == 0, "un preset inexistente vuelve a la opcion inicial")

	_nombre_preset.text = ""
	_progreso.text = ""
	ctrl.dialogo_preset_confirmado()
	_check(not _presets_store.ok_llamadas.is_empty(), "confirmar consulta el nombre al store")
	_presets_store.nombre_ok_res = false
	ctrl.dialogo_preset_confirmado()
	_check(_progreso.text == tr("El nombre no puede estar vacío."), "un nombre vacio avisa")
	_presets_store.nombre_ok_res = true

	_presets_val = {"A": {"filtro_estado": 1}}
	_presets_store.guardar_res = {"A": {"filtro_estado": 1}}
	_set_valor = {}
	_progreso.text = ""
	_check(not ctrl.guardar_preset("A"), "guardar sin cambios falla")
	_check(_progreso.text == tr("No se pudo guardar la configuración."), "y avisa")
	_presets_store.guardar_res = {"A": {"filtro_estado": 1}, "B": {"filtro_estado": 2}}
	_presets_store.guardados = []
	_check(ctrl.guardar_preset("B"), "guardar un preset nuevo tiene exito")
	_check(_set_valor.has("B"), "y actualiza los presets")
	_check(_presets_store.guardados.size() == 1, "y los persiste")
	_check(_progreso.text == tr("Filtro guardado: %s") % "B", "y avisa del guardado")

	_presets_val = {"A": {}}
	_check(not ctrl.borrar_preset("Z"), "borrar un preset inexistente falla")
	_presets_store.borrar_res = {"B": {}}
	_set_valor = {}
	_check(ctrl.borrar_preset("A"), "borrar un preset existente tiene exito")
	_check(_set_valor.has("B"), "y deja los que quedan")
	_nombre_preset.text = "A"
	ctrl.dialogo_preset_eliminar()
	_check(_progreso.text == tr("Filtro eliminado: %s") % "A", "eliminar avisa")


func _f_config() -> void:
	var ctrl := _ctrl()
	ctrl.cargar_filtros()
	_filtro.select(2)
	_filtro_cat.select(1)
	_filtro_dias.value = 5
	_filtro_modo.select(1)
	_campo_busqueda.text = "hola"
	var cfg: Dictionary = ctrl.config_filtros_actual()
	_check(int(cfg.get("filtro_estado", -1)) == 2, "config_filtros_actual recoge el estado")
	_check(int(cfg.get("filtro_categoria", -1)) == 1, "y la categoria")
	_check(int(cfg.get("filtro_dias", -1)) == 5, "y los dias")
	_check(str(cfg.get("busqueda_modo", "")) == "or", "y el modo")
	_check(str(cfg.get("busqueda", "")) == "hola", "y el texto de busqueda")


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_fallos += 1
	print("FALLO: " + msg)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
	else:
		print("%d FALLOS" % _fallos)
		quit(1)
