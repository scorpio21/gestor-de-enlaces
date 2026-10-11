extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")

var modo_vista := "lista"
var _boton_vista: Button = null
var _lista: VBoxContainer = null
var _grilla: GridContainer = null
var _fila_cabeceras: HBoxContainer = null
var _filtro: OptionButton = null
var _filtro_cat: OptionButton = null
var _busqueda: LineEdit = null
var _dashboard = null
var _progreso: Label = null
var _estado_store = null
var _instantanea_store = null
var _refrescar: Callable = Callable()
var _persistir: Callable = Callable()
var _entradas: Callable = Callable()


func _init(boton_vista: Button, lista: VBoxContainer, grilla: GridContainer, fila_cabeceras: HBoxContainer, filtro: OptionButton, filtro_cat: OptionButton, busqueda: LineEdit, dashboard, progreso: Label, estado_store, instantanea_store, refrescar: Callable, persistir: Callable, entradas: Callable) -> void:
	_boton_vista = boton_vista
	_lista = lista
	_grilla = grilla
	_fila_cabeceras = fila_cabeceras
	_filtro = filtro
	_filtro_cat = filtro_cat
	_busqueda = busqueda
	_dashboard = dashboard
	_progreso = progreso
	_estado_store = estado_store
	_instantanea_store = instantanea_store
	_refrescar = refrescar
	_persistir = persistir
	_entradas = entradas


func aplicar_vista() -> void:
	var es_grilla := modo_vista == "grilla"
	_lista.visible = not es_grilla
	_grilla.visible = es_grilla
	_fila_cabeceras.visible = not es_grilla
	_boton_vista.text = tr("Vista lista") if es_grilla else tr("Vista grilla")
	if es_grilla:
		grilla_redimensionada()


func toggle_vista() -> void:
	modo_vista = "lista" if modo_vista == "grilla" else "grilla"
	aplicar_vista()
	_refrescar.call()
	_persistir.call()


func grilla_redimensionada() -> void:
	if not _grilla.visible:
		return
	var n := clampi(floori(maxf(_grilla.size.x, 620.0) / 170.0), 2, 8)
	if _grilla.columns != n:
		_grilla.columns = n


func abrir_dashboard() -> void:
	_estado_store.volcar()
	_dashboard.abrir(_entradas.call(), _estado_store.cargar().get("estados", {}), instantaneas())


func instantaneas() -> Array:
	return [] if _instantanea_store == null else _instantanea_store.cargar()


func navegar_dashboard(tipo: String, valor: String) -> void:
	if valor.is_empty():
		return
	_filtro.select(0)
	_filtro_cat.select(0)
	if tipo == "categoria":
		var indice := GestorCatalogoScript.CATEGORIAS.find(valor)
		if indice < 0:
			return
		_busqueda.text = ""
		_filtro_cat.select(indice + 1)
	else:
		_busqueda.text = valor
	_dashboard.hide()
	_refrescar.call()
	_progreso.text = tr("Filtro aplicado desde el dashboard.")