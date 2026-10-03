extends SceneTree

const DASHBOARD := preload("res://scenes/Dashboard.tscn")
const TARJETA := preload("res://scenes/TarjetaKpi.tscn")
const FILA := preload("res://scenes/FilaTabla.tscn")
const DashboardStoreScript := preload("res://scripts/dashboard_store.gd")
const IdiomaScript := preload("res://scripts/idioma.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")

var _fallos := 0


func _initialize() -> void:
	IdiomaScript.cargar_traducciones()
	TranslationServer.set_locale("es")
	_tarjetas()
	_filas()
	await _panel()
	await _instantaneas()
	_cerrar()


func _tarjetas() -> void:
	var tarjeta: PanelContainer = TARJETA.instantiate()
	root.add_child(tarjeta)
	await process_frame
	tarjeta.configurar("12", "Disponibles", TemaStoreScript.color_estado(true), 0.75)
	_check(tarjeta.get_node("%Valor").text == "12", "la tarjeta muestra el valor")
	_check(tarjeta.get_node("%Etiqueta").text == "Disponibles", "la tarjeta muestra la etiqueta")
	_check(tarjeta.get_node("%Valor").get_theme_color("font_color") == TemaStoreScript.color_estado(true), "la tarjeta colorea el valor")
	_check(tarjeta.get_node("%Barra").visible and is_equal_approx(tarjeta.get_node("%Barra").value, 75.0), "la tarjeta pinta la barra del ratio")
	tarjeta.configurar("3", "Total", TemaStoreScript.color_estado(null), -1.0)
	_check(not tarjeta.get_node("%Barra").visible, "una tarjeta sin ratio oculta la barra")


func _filas() -> void:
	var fila: PanelContainer = FILA.instantiate()
	root.add_child(fila)
	await process_frame
	fila.configurar("Cliente", "8", "2", "80%", TemaStoreScript.color_estado(true), 0.8)
	_check(fila.get_node("%Nombre").text == "Cliente", "la fila muestra el nombre")
	_check(fila.get_node("%ColA").text == "8" and fila.get_node("%ColB").text == "2" and fila.get_node("%ColC").text == "80%", "la fila muestra las tres columnas")
	_check(fila.get_node("%ColC").get_theme_color("font_color") == TemaStoreScript.color_estado(true), "la fila colorea la columna indicada")
	_check(not fila.get_node("%ColA").has_theme_color_override("font_color"), "las demás columnas no se colorean")
	_check(fila.get_node("%Barra").visible and is_equal_approx(fila.get_node("%Barra").value, 80.0), "la fila pinta la barra de disponibilidad")
	var emitido := [0]
	fila.elegido.connect(func() -> void: emitido[0] += 1)
	fila._gui_input(_raton(false))
	_check(emitido[0] == 0, "un clic simple no navega")
	fila._gui_input(_raton(true))
	_check(emitido[0] == 1, "un doble clic emite elegido (#49)")
	fila.pulsable(true)
	_check(fila.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "la fila navegable muestra cursor de mano")
	fila.pulsable(false)
	_check(fila.mouse_default_cursor_shape == Control.CURSOR_ARROW, "la fila no navegable vuelve al cursor normal")


func _panel() -> void:
	var ui: Window = DASHBOARD.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	var dia_1 := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 9, "day": 1, "hour": 10})
	var dia_2 := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 9, "day": 2, "hour": 10})
	var dia_3 := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 9, "day": 3, "hour": 10})
	var entradas := [
		{"nombre": "A", "url": "https://a.test", "cat": "servidor", "tags": ["AO"]},
		{"nombre": "B", "url": "https://b.test", "cat": "cliente", "tags": []},
		{"nombre": "C", "url": "https://c.test", "cat": "cliente", "tags": []},
	]
	var estados := {
		"a.test": {"valido": true, "historial": [{"fecha": dia_1, "valido": true, "mensaje": "OK", "codigo": 200}, {"fecha": dia_3, "valido": true, "mensaje": "OK", "codigo": 200}]},
		"b.test": {"valido": false, "historial": [{"fecha": dia_1, "valido": false, "mensaje": "No", "codigo": 404}, {"fecha": dia_2, "valido": false, "mensaje": "No", "codigo": 500}]},
		"c.test": {"valido": true, "historial": [{"fecha": dia_2, "valido": true, "mensaje": "OK", "codigo": 200}]},
	}
	ui.abrir(entradas, estados)
	await process_frame
	await process_frame
	var grafico: Control = ui.get_node("%Grafico")
	_check(grafico.size.x > 100.0 and grafico.size.y > 100.0, "el gráfico ocupa su panel")
	_check(grafico.serie.size() == 3, "la serie diaria cubre los tres días comprobados")
	var indice: int = grafico.indice_bajo(grafico.size.x * 0.5)
	_check(indice >= 0 and indice < 3, "el índice bajo el cursor cae dentro de la serie")
	grafico._on_gui_input(_movimiento(grafico.size * 0.5))
	await process_frame
	_check(grafico._indice >= 0 and grafico._globo.visible, "al señalar una barra aparece el globo (#49)")
	_check(grafico._globo.text.contains("2026-09-") and grafico._globo.text.contains("Válidos"), "el globo indica el día y sus válidos")
	var caja: StyleBoxFlat = grafico._caja_globo()
	_check(caja is StyleBoxFlat and caja.content_margin_left > 0.0, "el globo toma la caja del tema (#49)")
	grafico._on_fuera()
	_check(grafico._indice == -1 and not grafico._globo.visible, "al salir del gráfico el globo se oculta")
	_check(ui.get_node("%Rango").get_selected_id() == 0, "por defecto se muestra todo el histórico")
	_check(ui.get_node("%Rango").get_item_count() == 4, "el selector ofrece cuatro rangos")
	_check(ui.get_node("%AvisoSinComprobar").visible == false, "con comprobaciones no se avisa")
	_check(ui.get_node("%ListaCategorias").get_child_count() == 2, "hay una fila por categoría")
	_check(ui.get_node("%ListaCategorias").get_child(0).get_node("%Nombre").text == "Cliente", "la categoría agrupa y ordena por total")
	_check(ui.get_node("%ListaHosts").get_child_count() == 3, "hay una fila por host")
	_check(ui.get_node("%ListaHosts").get_child(0).get_node("%Nombre").text == "b.test", "el host más problemático va primero")
	_check(ui.get_node("%ListaTop").get_child_count() == 1, "solo un enlace aparece como problemático")
	var top: Control = ui.get_node("%ListaTop").get_child(0)
	_check(top.get_node("%ColA").text == "2" and top.get_node("%ColB").text == "500", "el problemático muestra veces y último código")
	_check(top.get_node("%ColC").text.ends_with("26") or top.get_node("%ColC").text.contains("/"), "el problemático muestra la última comprobación")
	_check(not top.get_node("%Barra").visible, "la tabla de problemáticos no lleva barra")
	var cab_host: HBoxContainer = ui.get_node("%CabeceraHosts")
	cab_host.get_child(0).pressed.emit()
	_check(cab_host.get_child(0).text == "Nombre ▲" and _nombres(ui, "%ListaHosts") == ["a.test", "b.test", "c.test"], "ordenar por nombre alfabetiza los hosts (#49)")
	cab_host.get_child(0).pressed.emit()
	_check(cab_host.get_child(0).text == "Nombre ▼" and _nombres(ui, "%ListaHosts")[0] == "c.test", "pulsar la misma cabecera invierte el orden (#49)")
	cab_host.get_child(2).pressed.emit()
	_check(_nombres(ui, "%ListaHosts") == ["b.test", "c.test", "a.test"], "ordenar por caídos deja el peor host primero (#49)")
	cab_host.get_child(2).pressed.emit()
	_check(_nombres(ui, "%ListaHosts") == ["a.test", "c.test", "b.test"], "invertir los caídos deja el mejor host primero (#49)")
	_check(cab_host.get_child(2).tooltip_text == "Ordenar por Caídos", "la cabecera explica por qué columna ordena")
	var cab_cat: HBoxContainer = ui.get_node("%CabeceraCategorias")
	cab_cat.get_child(1).pressed.emit()
	_check(_nombres(ui, "%ListaCategorias")[0] == "Servidor", "en empate manda el nombre descendente (#49)")
	cab_cat.get_child(1).pressed.emit()
	cab_cat.get_child(1).pressed.emit()
	_check(cab_host.get_child(0).text == "Nombre" and ui.get_node("%CabeceraTop").get_child(1).text == "Veces", "cada tabla ordena por su cuenta")
	ui._pintar_top()
	await process_frame
	_check(ui.get_node("%ListaTop").get_child_count() == 1, "repintar la tabla no duplica filas")
	var color_oscuro: Color = (ui.get_node("%LeyendaOk") as ColorRect).color
	TemaStoreScript.aplicar("claro", root)
	ui.aplicar_paleta()
	_check(ui.get_node("%LeyendaOk").color == TemaStoreScript.color_estado(true), "la leyenda sigue al tema claro")
	_check(ui.get_node("%LeyendaOk").color != color_oscuro, "la leyenda cambia de color con el tema")
	_check((ui.get_node("%PctDisponibilidad") as Label).get_theme_color("font_color") == TemaStoreScript.color_estado(null), "la disponibilidad se colorea con el tema actual")
	TemaStoreScript.aplicar("oscuro", root)
	ui.abrir([], {})
	await process_frame
	_check(ui.get_node("%EstadoVacio").visible and not ui.get_node("%Datos").visible, "sin enlaces se muestra el estado vacío (#49)")
	_check(not ui.get_node("%Rango").visible, "sin enlaces no hay rango que elegir")
	ui.abrir(entradas, {})
	await process_frame
	_check(ui.get_node("%AvisoSinComprobar").visible, "sin comprobaciones se pide pulsar Comprobar (#49)")
	_check(ui.get_node("%PctDisponibilidad").text == "0%", "sin comprobaciones la disponibilidad es cero")
	_check(ui.get_node("%EtiquetaDisponibilidad").text == "Sin comprobaciones todavía", "sin comprobaciones se explica que aún no hay datos")
	ui.queue_free()
	await process_frame


func _instantaneas() -> void:
	var ui: Window = DASHBOARD.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	var entradas := [
		{"nombre": "A", "url": "https://a.test", "cat": "servidor", "tags": ["AO"]},
		{"nombre": "B", "url": "https://b.test", "cat": "cliente", "tags": []},
		{"nombre": "C", "url": "https://c.test", "cat": "cliente", "tags": []},
		{"nombre": "D", "url": "https://d.test", "cat": "cliente", "tags": []},
	]
	var estados := {
		"a.test": {"valido": true},
		"b.test": {"valido": false},
	}
	var grafico: Control = ui.get_node("%Grafico")
	var hoy := DashboardStoreScript.clave_de_dia(int(Time.get_unix_time_from_system()))
	var ayer := DashboardStoreScript.clave_de_dia(int(Time.get_unix_time_from_system()) - 86400)
	var fotos := [
		{"fecha": ayer, "total": 4, "validos": 2, "caidos": 1, "sin_comprobar": 1},
		{"fecha": hoy, "total": 4, "validos": 2, "caidos": 1, "sin_comprobar": 1},
	]

	ui.abrir(entradas, estados)
	await process_frame
	_check(ui.get_node("%AvisoInstantaneas").visible, "sin instantáneas el gráfico aviva de que usa el historial (#60)")
	_check(grafico.serie.is_empty(), "sin comprobaciones la serie del gráfico queda vacía (#60)")

	ui.abrir(entradas, estados, fotos)
	await process_frame
	await process_frame
	_check(not ui.get_node("%AvisoInstantaneas").visible, "con instantáneas ya no hace falta el aviso (#60)")
	_check(grafico.serie.size() == 2, "el gráfico dibuja una barra por cada día fotografiado (#60)")
	var hoy_fila: Dictionary = grafico.serie[1]
	_check(bool(hoy_fila.get("instantanea")) and int(hoy_fila.get("total")) == 4, "la barra del día trae el total del catálogo (#60)")
	_check(int(hoy_fila.get("sin_comprobar")) == 1, "la barra del día trae los sin comprobar (#60)")
	_check(bool(hoy_fila.get("con_delta")) and int(hoy_fila.get("delta_validos")) == 0, "el globo calcula el delta entre fotos (#60)")
	_check(grafico._maximo() == 4, "la escala del eje llega al total del catálogo (#60)")
	grafico.serie = [{"fecha": "2026-09-01", "total": 40, "validos": 2, "caidos": 1, "sin_comprobar": 1}]
	_check(grafico._maximo() == 40, "una foto con más enlaces que estados decide la escala el total (#60)")
	grafico.serie = [{"fecha": "2026-09-01", "total": 2, "validos": 9, "caidos": 3, "sin_comprobar": 5}]
	_check(grafico._maximo() == 17, "unos datos que no cuadran no recortan la barra: manda la suma de las series (#60)")
	grafico.serie = [{"fecha": "2026-09-01", "validos": 9, "caidos": 3, "sin_comprobar": 5}]
	_check(grafico._maximo() == 17, "sin total la escala suma las tres series (#60)")
	grafico.serie = [{"fecha": "2026-09-01", "sin_datos": true}]
	_check(grafico._maximo() == 1, "un gráfico sin nada que dibujar no divide por cero (#60)")
	grafico.serie = [{"fecha": "2026-09-01", "total": 4, "validos": 2, "caidos": 1, "sin_comprobar": 1}]

	var texto: String = grafico.texto_dia(hoy_fila)
	_check(texto.contains("Sin comprobar 1"), "el globo explica los sin comprobar del día (#60)")
	_check(texto.contains("Desde el día anterior"), "el globo compara con la foto anterior (#60)")
	var sin_datos: String = grafico.texto_dia({"fecha": "2026-09-02", "sin_datos": true, "cambios_validos": 3})
	_check(sin_datos.contains("Sin datos"), "un día sin foto se explica en el globo (#60)")
	_check(not sin_datos.contains("Válidos 0"), "un día sin foto no finge cero válidos (#60)")
	var plano: String = grafico.texto_dia({"fecha": "2026-09-02"})
	_check(plano.contains("Total 0") and not plano.contains("Desde el día anterior"), "un día sin deltas no inventa comparación (#60)")

	ui.abrir(entradas, estados, [{"fecha": "basura"}])
	await process_frame
	_check(grafico.serie.is_empty(), "unas instantáneas corruptas no inventan barras (#60)")
	_check(ui.get_node("%AvisoInstantaneas").visible, "unas instantáneas corruptas vuelven a avisar (#60)")

	ui.abrir([], {}, fotos)
	await process_frame
	_check(ui.get_node("%EstadoVacio").visible and not ui.get_node("%AvisoInstantaneas").visible, "sin enlaces no se avisa de instantáneas (#60)")
	ui.queue_free()
	await process_frame


func _nombres(ui: Window, ruta: String) -> Array:
	var lista: Array = []
	for hijo in ui.get_node(ruta).get_children():
		lista.append(hijo.get_node("%Nombre").text)
	return lista


func _raton(doble: bool) -> InputEventMouseButton:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_LEFT
	evento.pressed = true
	evento.double_click = doble
	return evento


func _movimiento(pos: Vector2) -> InputEventMouseMotion:
	var evento := InputEventMouseMotion.new()
	evento.position = pos
	return evento


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
