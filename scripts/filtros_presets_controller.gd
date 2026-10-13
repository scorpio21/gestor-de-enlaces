extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const EtiquetasScript := preload("res://scripts/etiquetas.gd")
const CODIGOS_FILTRO := [200, 301, 302, 403, 404, 410, 500, 503]

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
var _entradas: Callable = Callable()
var _presets_store: Callable = Callable()
var _presets: Callable = Callable()
var _set_presets: Callable = Callable()
var _refrescar: Callable = Callable()
var _persistir: Callable = Callable()
var _aplicar_filtro: Callable = Callable()


func _init(filtro: OptionButton, filtro_cat: OptionButton, filtro_tag: OptionButton, filtro_codigo: OptionButton, filtro_modo: OptionButton, filtro_dias: SpinBox, campo_busqueda: LineEdit, preset_filtros: OptionButton, nombre_preset: LineEdit, dialogo_preset: AcceptDialog, progreso: Label, espera_busqueda: Timer, entradas: Callable, presets_store: Callable, presets: Callable, set_presets: Callable, refrescar: Callable, persistir: Callable, aplicar_filtro: Callable) -> void:
	_filtro = filtro
	_filtro_cat = filtro_cat
	_filtro_tag = filtro_tag
	_filtro_codigo = filtro_codigo
	_filtro_modo = filtro_modo
	_filtro_dias = filtro_dias
	_campo_busqueda = campo_busqueda
	_preset_filtros = preset_filtros
	_nombre_preset = nombre_preset
	_dialogo_preset = dialogo_preset
	_progreso = progreso
	_espera = espera_busqueda
	_entradas = entradas
	_presets_store = presets_store
	_presets = presets
	_set_presets = set_presets
	_refrescar = refrescar
	_persistir = persistir
	_aplicar_filtro = aplicar_filtro


func cargar_filtros() -> void:
	var sel_estado := _filtro.get_selected()
	var sel_cat := _filtro_cat.get_selected()
	var sel_tag := etiqueta_seleccionada()
	_filtro.clear()
	_filtro.add_item(tr("Todos"), 0)
	_filtro.add_item(tr("Válidos"), 1)
	_filtro.add_item(tr("Caídos / no existen"), 2)
	_filtro.add_item(tr("Sin comprobar"), 3)
	if _filtro.item_selected.is_connected(filtro_estado):
		_filtro.item_selected.disconnect(filtro_estado)
	_filtro.item_selected.connect(filtro_estado)
	_filtro.select(maxi(sel_estado, 0))
	_filtro_cat.clear()
	_filtro_cat.add_item(tr("Todas"), 0)
	for i in range(GestorCatalogoScript.CATEGORIAS.size()):
		_filtro_cat.add_item(GestorCatalogoScript.new().categoria_display(GestorCatalogoScript.CATEGORIAS[i]), i + 1)
	if _filtro_cat.item_selected.is_connected(filtro_categoria):
		_filtro_cat.item_selected.disconnect(filtro_categoria)
	_filtro_cat.item_selected.connect(filtro_categoria)
	_filtro_cat.select(maxi(sel_cat, 0))
	_filtro_tag.clear()
	_filtro_tag.add_item(tr("Todas"), 0)
	for etiqueta in EtiquetasScript.frecuentes(_entradas.call(), 0):
		_filtro_tag.add_item(str(etiqueta), _filtro_tag.item_count)
	if _filtro_tag.item_selected.is_connected(filtro_etiqueta):
		_filtro_tag.item_selected.disconnect(filtro_etiqueta)
	_filtro_tag.item_selected.connect(filtro_etiqueta)
	_filtro_tag.select(indice_etiqueta(sel_tag))
	_filtro_codigo.clear()
	_filtro_codigo.add_item(tr("Todos"), 0)
	for codigo in CODIGOS_FILTRO:
		_filtro_codigo.add_item(str(codigo), codigo)
	if _filtro_codigo.item_selected.is_connected(filtro_codigo):
		_filtro_codigo.item_selected.disconnect(filtro_codigo)
	_filtro_codigo.item_selected.connect(filtro_codigo)
	_filtro_modo.clear()
	_filtro_modo.add_item(tr("Todas las palabras"), 0)
	_filtro_modo.add_item(tr("Cualquier palabra"), 1)
	if _filtro_modo.item_selected.is_connected(filtro_modo):
		_filtro_modo.item_selected.disconnect(filtro_modo)
	_filtro_modo.item_selected.connect(filtro_modo)
	_filtro_dias.suffix = " " + tr("días")
	if _filtro_dias.value_changed.is_connected(filtro_dias):
		_filtro_dias.value_changed.disconnect(filtro_dias)
	_filtro_dias.value_changed.connect(filtro_dias)


func etiqueta_seleccionada() -> String:
	var id := _filtro_tag.get_selected_id()
	if id > 0 and id < _filtro_tag.item_count:
		return _filtro_tag.get_item_text(id)
	return ""


func codigo_seleccionado() -> String:
	return str(maxi(_filtro_codigo.get_selected_id(), 0))


func indice_codigo(clave: String) -> int:
	if clave.is_empty():
		return 0
	var codigo := int(clave)
	for i in range(1, _filtro_codigo.item_count):
		if _filtro_codigo.get_item_id(i) == codigo:
			return i
	return 0


func modo_busqueda() -> String:
	return "or" if _filtro_modo.get_selected_id() == 1 else "and"


func indice_etiqueta(etiqueta: String) -> int:
	var clave := etiqueta.strip_edges().to_lower()
	for i in range(1, _filtro_tag.item_count):
		if _filtro_tag.get_item_text(i).to_lower() == clave:
			return i
	return 0


func busqueda_cambiada(_texto: String) -> void:
	_espera.start()


func busqueda_aplicar() -> void:
	_refrescar.call()


func busqueda_guardar() -> void:
	_persistir.call()


func busqueda_enviada(_texto: String) -> void:
	_espera.stop()
	_refrescar.call()
	_persistir.call()


func filtro_estado(_indice: int) -> void:
	_aplicar_filtro.call()
	_persistir.call()


func filtro_categoria(_indice: int) -> void:
	_aplicar_filtro.call()
	_persistir.call()


func filtro_etiqueta(_indice: int) -> void:
	_aplicar_filtro.call()
	_persistir.call()


func filtro_codigo(_indice: int) -> void:
	_aplicar_filtro.call()
	_persistir.call()


func filtro_dias(_valor: float) -> void:
	_aplicar_filtro.call()
	_persistir.call()


func filtro_modo(_indice: int) -> void:
	_refrescar.call()
	_persistir.call()


func preset_seleccionado(indice: int) -> void:
	if indice <= 0:
		_preset_filtros.select(0)
		return
	aplicar_preset(_preset_filtros.get_item_text(indice))


func aplicar_preset(nombre: String) -> void:
	var cfg: Dictionary = _presets_store.call().aplicar_preset(_presets.call(), nombre)
	if cfg.is_empty():
		_preset_filtros.select(0)
		return
	_filtro.select(int(cfg.get("filtro_estado", 0)))
	_filtro_cat.select(int(cfg.get("filtro_categoria", 0)))
	_filtro_tag.select(indice_etiqueta(str(cfg.get("filtro_etiqueta", ""))))
	_filtro_codigo.select(indice_codigo(str(cfg.get("filtro_codigo", ""))))
	_filtro_modo.select(0 if str(cfg.get("busqueda_modo", "and")) == "and" else 1)
	_filtro_dias.value = int(cfg.get("filtro_dias", 0))
	_campo_busqueda.text = str(cfg.get("busqueda", ""))
	_refrescar.call()
	_persistir.call()
	_preset_filtros.select(0)


func boton_preset() -> void:
	_nombre_preset.text = ""
	_dialogo_preset.popup_centered()
	_nombre_preset.grab_focus()


func dialogo_preset_confirmado() -> void:
	var nombre: String = _nombre_preset.text.strip_edges()
	if not _presets_store.call().nombre_ok(nombre):
		_progreso.text = tr("El nombre no puede estar vacío.")
		return
	guardar_preset(nombre)


func guardar_preset(nombre: String) -> bool:
	var actuales: Dictionary = _presets.call()
	var presets_nuevos: Dictionary = _presets_store.call().guardar_preset(actuales, nombre, config_filtros_actual())
	if presets_nuevos == actuales:
		_progreso.text = tr("No se pudo guardar la configuración.")
		return false
	_set_presets.call(presets_nuevos)
	_presets_store.call().guardar(presets_nuevos)
	presets_recargar_ui()
	_progreso.text = tr("Filtro guardado: %s") % nombre
	return true


func dialogo_preset_eliminar() -> void:
	var nombre: String = _nombre_preset.text.strip_edges()
	if not borrar_preset(nombre):
		_progreso.text = tr("No existe ese filtro.")
		return
	_dialogo_preset.hide()


func borrar_preset(nombre: String) -> bool:
	if not _presets.call().has(nombre):
		return false
	_set_presets.call(_presets_store.call().borrar_preset(_presets.call(), nombre))
	_presets_store.call().guardar(_presets.call())
	presets_recargar_ui()
	_progreso.text = tr("Filtro eliminado: %s") % nombre
	return true


func presets_recargar_ui() -> void:
	_preset_filtros.clear()
	_preset_filtros.add_item(tr("Presets…"), -1)
	for nombre in _presets_store.call().nombres(_presets.call()):
		_preset_filtros.add_item(str(nombre), _preset_filtros.item_count)
	if _preset_filtros.item_selected.is_connected(preset_seleccionado):
		_preset_filtros.item_selected.disconnect(preset_seleccionado)
	_preset_filtros.item_selected.connect(preset_seleccionado)
	_preset_filtros.select(0)


func config_filtros_actual() -> Dictionary:
	return {
		"filtro_estado": _filtro.get_selected_id(),
		"filtro_categoria": _filtro_cat.get_selected_id(),
		"filtro_etiqueta": etiqueta_seleccionada(),
		"busqueda": _campo_busqueda.text,
		"filtro_codigo": codigo_seleccionado(),
		"filtro_dias": int(_filtro_dias.value),
		"busqueda_modo": modo_busqueda(),
	}
