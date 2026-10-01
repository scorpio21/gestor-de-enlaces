extends SceneTree

const CAMBIOS := preload("res://scenes/Cambios.tscn")
const CambiosStoreScript := preload("res://scripts/cambios_store.gd")
const ListItemScript := preload("res://scripts/list_item.gd")
const IdiomaScript := preload("res://scripts/idioma.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")
const Ayuda := preload("res://tests/ayuda.gd")

const BASE := "user://__test_cambios_ui__"

var _fallos := 0
var _ui: Window


func _initialize() -> void:
	IdiomaScript.cargar_traducciones()
	TranslationServer.set_locale("es")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	await _arrancar()
	await _resumen()
	await _cobertura()
	await _filas()
	await _vacio()
	await _exportar()
	await _avisos()
	Ayuda.borrar_arbol(BASE)
	_cerrar()


func _cambio(clave: String, tipo: String, nombre := "", valido_ant: Variant = true, valido_nue: Variant = false, fecha := 1700000000, mensaje := "Connection refused", codigo := 0) -> Dictionary:
	return {
		"tipo": tipo,
		"clave": clave,
		"url": "https://%s" % clave,
		"valido_ant": valido_ant,
		"mensaje_ant": "OK",
		"codigo_ant": 200,
		"valido_nue": valido_nue,
		"mensaje_nue": mensaje,
		"codigo_nue": codigo,
		"fecha": fecha,
	}


func _arrancar() -> void:
	_ui = CAMBIOS.instantiate()
	root.add_child(_ui)
	await process_frame
	await process_frame


func _nombres() -> Dictionary:
	return {"a.test": "Servidor Principal", "b.test": "Otro"}


func _resumen() -> void:
	_ui.abrir([
		_cambio("a.test", CambiosStoreScript.TIPO_NUEVO_CAIDO),
		_cambio("b.test", CambiosStoreScript.TIPO_NUEVO_CAIDO),
		_cambio("c.test", CambiosStoreScript.TIPO_RECUPERADO, "", false, true),
	], _nombres(), 0)
	_check(_ui.get_node("%Resumen").text == "2 nuevos caídos · 1 recuperado", "el contador resume por tipo")
	_check(_ui.cambios().size() == 3, "la ventana guarda la lista que recibe")

	_ui.abrir([
		_cambio("a.test", CambiosStoreScript.TIPO_REUBICADO, "", true, true, 1700000000, "Moved Permanently", 301),
		_cambio("b.test", CambiosStoreScript.TIPO_NUEVO_CAIDO),
	], _nombres(), 0)
	_check(_ui.get_node("%Resumen").text == "1 nuevo caído · 1 reubicado", "en singular el contador usa la forma corta")
	_check("recuperados" not in _ui.get_node("%Resumen").text, "un tipo en cero no se anuncia")

	_ui.abrir([
		_cambio("a.test", CambiosStoreScript.TIPO_RECUPERADO, "", false, true),
		_cambio("b.test", CambiosStoreScript.TIPO_RECUPERADO, "", false, true),
		_cambio("c.test", CambiosStoreScript.TIPO_REUBICADO, "", true, true, 1700000000, "", 301),
	], _nombres(), 0)
	_check(_ui.get_node("%Resumen").text == "2 recuperados · 1 reubicado", "el plural y el singular conviven bien")


func _cobertura() -> void:
	_ui.abrir([_cambio("a.test", CambiosStoreScript.TIPO_NUEVO_CAIDO)], _nombres(), 0)
	_check(not _ui.get_node("%Cobertura").visible, "sin cobertura no se avisa de la retencion")

	var desde := 1600000000
	_ui.abrir([_cambio("a.test", CambiosStoreScript.TIPO_NUEVO_CAIDO)], _nombres(), desde)
	_check(_ui.get_node("%Cobertura").visible, "con cobertura se avisa de la retencion")
	_check(
		_ui.get_node("%Cobertura").text.contains(ListItemScript.formatear_fecha(desde)),
		"la nota dice hasta que fecha llega el historial"
	)


func _filas() -> void:
	_ui.abrir([
		_cambio("a.test", CambiosStoreScript.TIPO_NUEVO_CAIDO),
		_cambio("b.test", CambiosStoreScript.TIPO_RECUPERADO, "", false, true, 1600000000, "", 200),
	], _nombres(), 0)
	var filas := _ui.get_node("%ListaCambios").get_children()
	_check(filas.size() == 2, "la ventana pinta una fila por cambio")

	var primera := filas[0]
	_check(primera.get_node("%Nombre").text == "Servidor Principal", "la fila lleva el nombre del enlace")
	_check(primera.get_node("%ColA").text == ListItemScript.formatear_fecha(1700000000), "la fila lleva la fecha")
	_check(primera.get_node("%ColB").text == "Válido → Caído", "la fila muestra el salto de estado")
	_check(primera.get_node("%ColB").get_theme_color("font_color") == TemaStoreScript.color_clave("caido"), "un caido se pinta en rojo")
	_check(not primera.get_node("%Barra").visible, "la fila de cambios no lleva barra de disponibilidad")

	var segunda := filas[1]
	_check(segunda.get_node("%ColB").text == "Caído → Válido", "un recuperado va de caido a valido")
	_check(segunda.get_node("%ColB").get_theme_color("font_color") == TemaStoreScript.color_clave("valido"), "un recuperado se pinta en verde")

	_ui.abrir([_cambio("z.test", CambiosStoreScript.TIPO_NUEVO_CAIDO)], {}, 0)
	var sin_nombre := _ui.get_node("%ListaCambios").get_child(0)
	_check(sin_nombre.get_node("%Nombre").text == "https://z.test", "sin nombre en el catalogo se muestra la url")

	_ui.abrir([_cambio("q.test", CambiosStoreScript.TIPO_REUBICADO, "", true, true, 1700000000, "", 0)], {}, 0)
	var sin_mensaje := _ui.get_node("%ListaCambios").get_child(0)
	_check(sin_mensaje.get_node("%ColC").text == "https://q.test", "sin mensaje el detalle cae en la url")
	_check(sin_mensaje.get_node("%ColB").get_theme_color("font_color") == TemaStoreScript.color_clave("aviso"), "un reubicado se pinta en ambar")
	_check(not sin_mensaje.get_node("%ColC").has_theme_color_override("font_color"), "solo la columna del cambio se colorea")

	_ui.aplicar_paleta()
	_check(_ui.get_node("%ListaCambios").get_child_count() == 1, "aplicar la paleta no pierde filas")


func _vacio() -> void:
	_ui.abrir([], {}, 0)
	_check(_ui.get_node("%ListaCambios").get_child_count() == 0, "sin cambios no hay filas")
	_check(_ui.get_node("%AvisoVacio").visible, "sin cambios se muestra el aviso")
	_check(_ui.get_node("%Resumen").text.is_empty(), "sin cambios el contador queda vacio")


func _exportar() -> void:
	_ui.abrir([_cambio("a.test", CambiosStoreScript.TIPO_NUEVO_CAIDO)], _nombres(), 0)
	var ruta := "%s/cambios.csv" % BASE
	_ui._on_exportar_elegido(ruta)
	_check(_ui.get_node("%Nota").text == "Cambios exportados.", "exportar bien avisa")
	var texto := FileAccess.get_file_as_string(ruta)
	_check(texto.split("\n")[0] == CambiosStoreScript.CABECERA_CSV, "el CSV lleva la cabecera esperada")
	_check(texto.contains('"Servidor Principal"'), "el CSV lleva el nombre del enlace")

	_ui._on_exportar_elegido("%s/no-existe-dir/x.csv" % BASE)
	_check(_ui.get_node("%Nota").text == "No se pudo exportar.", "exportar mal avisa del fallo")


func _avisos() -> void:
	_ui.abrir([_cambio("a.test", CambiosStoreScript.TIPO_NUEVO_CAIDO)], _nombres(), 0)
	var filtrado := [0]
	var al_dashboard := [0]
	_ui.filtrar_pedido.connect(func() -> void: filtrado[0] += 1)
	_ui.dashboard_pedido.connect(func() -> void: al_dashboard[0] += 1)
	_ui.get_node("%BotonFiltrar").pressed.emit()
	_check(filtrado[0] == 1, "Filtrar en la lista avisa a la app")
	_check(al_dashboard[0] == 0, "Filtrar no abre el dashboard")
	_ui.get_node("%BotonDashboard").pressed.emit()
	_check(al_dashboard[0] == 1, "Abrir el dashboard avisa a la app")

	_check(_ui.get_node("%DialogoExportar").file_mode == FileDialog.FILE_MODE_SAVE_FILE, "el dialogo de exportar es de guardar")
	_check(_ui.get_node("%DialogoExportar").access == FileDialog.ACCESS_FILESYSTEM, "el dialogo de exportar llega al disco entero")
	_ui._preparar_csv()
	_check(_ui.get_node("%DialogoExportar").filters.size() == 1, "exportar ofrece un unico filtro")
	_check(_ui.get_node("%DialogoExportar").filters[0].contains("*.csv"), "ese filtro es el CSV")
	_check(_ui.get_node("%DialogoExportar").current_file == "cambios.csv", "propone un nombre de fichero")
	_ui.get_node("%DialogoExportar").hide()


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)