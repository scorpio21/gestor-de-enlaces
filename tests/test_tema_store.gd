extends SceneTree

const TemaStoreScript := preload("res://scripts/tema_store.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var paleta := TemaStoreScript.paleta()
	_check(paleta.get("texto_suave") == Color(0.75, 0.75, 0.75, 1), "paleta por defecto es el set oscuro")
	_check(TemaStoreScript.normalizar("claro") == "claro" and TemaStoreScript.normalizar("oscuro") == "oscuro", "normalizar acepta los dos modos")
	_check(TemaStoreScript.normalizar("chocolate") == "oscuro" and TemaStoreScript.normalizar(3) == "oscuro", "normalizar cae a oscuro con valores inválidos")

	var verde := TemaStoreScript.color_estado(true)
	var rojo := TemaStoreScript.color_estado(false)
	var gris := TemaStoreScript.color_estado(null)
	_check(verde == paleta.get("valido") and rojo == paleta.get("caido") and gris == paleta.get("sin_comprobar"), "color_estado resuelve los tres estados desde la paleta")

	var root := Control.new()
	root.add_child(_hacer_label("SUAVE", Color(0.75, 0.75, 0.75, 1)))
	root.add_child(_hacer_label("ERROR", Color(0.95, 0.4, 0.4, 1)))
	root.add_child(_hacer_label("FUERA", null))
	var fondo := ColorRect.new()
	fondo.name = "Fondo"
	fondo.color = Color(0.12, 0.12, 0.12, 1)
	root.add_child(fondo)
	var boton := Button.new()
	boton.text = "Probar"
	root.add_child(boton)

	var ventana := Window.new()
	root.add_child(ventana)
	var fondo_ventana := ColorRect.new()
	fondo_ventana.name = "Fondo"
	fondo_ventana.color = Color(0.12, 0.12, 0.12, 1)
	ventana.add_child(fondo_ventana)
	ventana.add_child(_hacer_label("VENTANA", null))

	var ventana_sin_fondo := Window.new()
	root.add_child(ventana_sin_fondo)
	ventana_sin_fondo.add_child(_hacer_label("DIALOGO", null))

	get_root().add_child(root)

	TemaStoreScript.aplicar("claro", root)
	var tema_claro: Theme = root.theme
	_check(tema_claro != null, "aplicar claro asigna un Theme al root Control")
	_check(_color_label(root.get_child(0)) == Color(0.3, 0.3, 0.3, 1), "claro re-mapea el texto suave 0.75 a 0.30")
	_check(_color_label(root.get_child(1)) == Color(0.8, 0.15, 0.15, 1), "claro re-mapea el rojo de error")
	_check(fondo.color == Color(0.95, 0.95, 0.95, 1), "claro pinta el ColorRect Fondo")
	_check(_color_label(root.get_child(2)) == null, "un Label sin overlay de color no se toca")
	_check(tema_claro.get_color("font_color", "Label") == Color(0.3, 0.3, 0.3, 1), "el Theme claro usa el texto de la paleta")
	_check(tema_claro.get_color("font_color", "Button") == Color(0.3, 0.3, 0.3, 1), "el Theme claro aplica a los Botones")
	_check(ventana.theme == tema_claro, "una ventana con Fondo recibe el Theme claro")
	_check(ventana_sin_fondo.theme == null, "una ventana sin Fondo conserva el Theme por defecto")
	await process_frame
	_check(ventana.get_child(1).get_theme_color("font_color") == Color(0.3, 0.3, 0.3, 1), "una etiqueta de ventana con Theme resuelve el texto claro")
	_check(ventana_sin_fondo.get_child(0).get_theme_color("font_color") == Color(0.3, 0.3, 0.3, 1), "una ventana sin Theme hereda el texto claro del root")

	TemaStoreScript.aplicar("oscuro", root)
	var tema_oscuro: Theme = root.theme
	_check(_color_label(root.get_child(0)) == Color(0.75, 0.75, 0.75, 1), "oscuro restaura el texto suave")
	_check(_color_label(root.get_child(1)) == Color(0.95, 0.4, 0.4, 1), "oscuro restaura el rojo de error")
	_check(fondo.color == Color(0.12, 0.12, 0.12, 1), "oscuro preserva el fondo original")
	_check(_color_label(root.get_child(2)) == null, "un Label sin overlay sigue intacto tras oscuro")
	_check(tema_oscuro.get_color("font_color", "Label") == Color(0.75, 0.75, 0.75, 1), "el Theme oscuro usa el texto de la paleta")
	_check(ventana.theme == tema_oscuro, "una ventana con Fondo recibe el Theme oscuro")
	_check(ventana_sin_fondo.theme == null, "una ventana sin Fondo no recibe Theme oscuro")
	await process_frame
	_check(ventana.get_child(1).get_theme_color("font_color") == Color(0.75, 0.75, 0.75, 1), "una etiqueta de ventana con Theme resuelve el texto oscuro")
	_check(ventana_sin_fondo.get_child(0).get_theme_color("font_color") == Color(0.75, 0.75, 0.75, 1), "una ventana sin Theme hereda el texto oscuro del root")

	TemaStoreScript.aplicar("oscuro", root)
	_check(fondo.color == Color(0.12, 0.12, 0.12, 1) \
		and _color_label(root.get_child(1)) == Color(0.95, 0.4, 0.4, 1), "aplicar el mismo modo dos veces es idempotente")

	root.free()
	_cerrar()


func _hacer_label(texto: String, color: Variant) -> Label:
	var l := Label.new()
	l.name = texto
	l.text = texto
	if color != null:
		l.add_theme_color_override("font_color", color)
	return l


func _color_label(n: Node) -> Variant:
	var v: Variant = n.get("theme_override_colors/font_color")
	return v


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
