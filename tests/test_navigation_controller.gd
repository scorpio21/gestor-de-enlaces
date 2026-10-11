extends SceneTree

const NavigationControllerScript := preload("res://scripts/navigation_controller.gd")

var _fallos := 0


class _FakeDashboard extends RefCounted:
	var abierto := false
	var oculto := false
	var ultima_entradas: Array = []
	var ultimas_instantaneas: Array = []

	func abrir(entradas: Array, _estados: Dictionary, instantaneas: Array) -> void:
		abierto = true
		ultima_entradas = entradas
		ultimas_instantaneas = instantaneas

	func hide() -> void:
		oculto = true


class _FakeEstadoStore extends RefCounted:
	var estados := {"a": {"valido": true}}
	var volcado := false

	func volcar() -> void:
		volcado = true

	func cargar() -> Dictionary:
		return {"estados": estados}


class _FakeInstantaneas extends RefCounted:
	var datos: Array = [{"fecha": 1}]

	func cargar() -> Array:
		return datos


func _initialize() -> void:
	var boton := Button.new()
	var lista := VBoxContainer.new()
	var grilla := GridContainer.new()
	var cabeceras := HBoxContainer.new()
	var filtro := OptionButton.new()
	filtro.add_item("todas")
	var filtro_cat := OptionButton.new()
	filtro_cat.add_item("todas")
	filtro_cat.add_item("otro")
	filtro_cat.add_item("cliente")
	var busqueda := LineEdit.new()
	var progreso := Label.new()
	var dashboard := _FakeDashboard.new()
	var estado = _FakeEstadoStore.new()
	var instantaneas = _FakeInstantaneas.new()
	var refrescado := [0]
	var persistido := [0]
	var nav = NavigationControllerScript.new(boton, lista, grilla, cabeceras, filtro, filtro_cat, busqueda, dashboard, progreso, estado, instantaneas,
		func() -> void:
			refrescado[0] += 1,
		func() -> bool:
			persistido[0] += 1
			return true,
		func() -> Array:
			return [{"nombre": "A"}])

	# Vista inicial en lista.
	nav.aplicar_vista()
	_check(lista.visible and not grilla.visible and cabeceras.visible, "aplicar_vista en lista muestra lista y cabeceras")

	# Toggle a grilla: conmuta estado, visibilidad, texto y refresca/persiste.
	var texto_lista := boton.text
	nav.toggle_vista()
	_check(nav.modo_vista == "grilla", "toggle_vista cambia el modo a grilla")
	_check(not lista.visible and grilla.visible and not cabeceras.visible, "y conmuta la visibilidad de los contenedores")
	_check(boton.text != texto_lista, "el botón cambia su texto al conmutar")
	_check(refrescado[0] == 1 and persistido[0] == 1, "toggle_vista refresca y persiste")

	# La grilla se redimensiona según su anchura (clamp 2..8).
	grilla.size = Vector2(1000, 100)
	nav.grilla_redimensionada()
	_check(grilla.columns == 5, "grilla_redimensionada ajusta a 5 columnas para 1000 px")
	var columnas_oculto := grilla.columns
	nav.toggle_vista()
	_check(nav.modo_vista == "lista", "segundo toggle vuelve a lista")
	nav.grilla_redimensionada()
	_check(grilla.columns == columnas_oculto, "con la grilla oculta no se redimensiona")

	# Navegar desde el dashboard: por texto filtra la búsqueda y oculta la ventana.
	nav.navegar_dashboard("texto", "glaciar")
	_check(busqueda.text == "glaciar", "navegar por texto pone la búsqueda")
	_check(dashboard.oculto, "y oculta el dashboard")
	_check(refrescado[0] == 3, "y refresca la lista")
	nav.navegar_dashboard("categoria", "cliente")
	_check(filtro_cat.selected == 2, "navegar por categoría selecciona el filtro")
	_check(busqueda.text == "", "y vacía la búsqueda")
	nav.navegar_dashboard("categoria", "no_existe")
	_check(filtro_cat.selected == 0, "una categoría desconocida resetea el filtro y no navega")
	_check(refrescado[0] == 4, "y la categoría desconocida no refresca")

	# Valor vacío: no hace nada.
	var oculto_tras := dashboard.oculto
	nav.navegar_dashboard("texto", "")
	nav.navegar_dashboard("categoria", "")
	_check(dashboard.oculto == oculto_tras and refrescado[0] == 4, "navegar con valor vacío no hace nada")

	# Abrir el dashboard recibe entradas e instantáneas y vuelca el estado.
	nav.abrir_dashboard()
	_check(dashboard.abierto, "abrir_dashboard abre el dashboard")
	_check(estado.volcado, "y vuelca el estado primero")
	_check(dashboard.ultima_entradas.size() == 1, "con las entradas actuales")
	_check(dashboard.ultimas_instantaneas == instantaneas.datos, "y las instantáneas")

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, texto: String) -> void:
	if condicion:
		return
	_fallos += 1
	print("FALLO: %s" % texto)