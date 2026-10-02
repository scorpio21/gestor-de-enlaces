extends SceneTree

const SeleccionControllerScript := preload("res://scripts/seleccion_controller.gd")

var _fallos := 0

const VISIBLES := ["a.test", "b.test", "c.test", "d.test"]


func _initialize() -> void:
	TranslationServer.set_locale("es")
	_un_click()
	_rango()
	_todo_y_limpiar()
	_conservar()
	_atajos()
	_textos()
	_cerrar()


func _sel() -> SeleccionControllerScript:
	return SeleccionControllerScript.new()


func _un_click() -> void:
	var sel := _sel()
	_check(sel.contar() == 0, "una seleccion nueva no tiene nada")
	_check(not sel.contiene("a.test"), "nada esta seleccionado todavia")

	sel.alternar("a.test", false, false, VISIBLES)
	_check(sel.contar() == 1, "un clic normal selecciona una fila")
	_check(sel.contiene("a.test"), "y es justo esa")
	_check(sel.ancla() == "a.test", "la fila clicada queda como ancla")

	sel.alternar("c.test", false, false, VISIBLES)
	_check(sel.contar() == 1 and sel.contiene("c.test"), "otro clic normal deja solo la nueva")
	_check(not sel.contiene("a.test"), "y suelta la anterior")

	sel.alternar("b.test", true, false, VISIBLES)
	sel.alternar("d.test", true, false, VISIBLES)
	_check(sel.contar() == 3, "ctrl+clic acumula")
	_check(sel.contiene("c.test") and sel.contiene("b.test") and sel.contiene("d.test"), "y son las tres esperadas")

	sel.alternar("b.test", true, false, VISIBLES)
	_check(sel.contar() == 2 and not sel.contiene("b.test"), "ctrl+clic sobre la misma la quita")

	var cambios := sel.alternar("c.test", false, false, VISIBLES)
	_check(cambios.size() == 1, "volver a un solo elemento avisa de la que se suelta")
	_check(cambios[0] == "d.test", "y avisa de la correcta")
	_check(not sel.contiene("b.test"), "y quedan fuera las que no estaban")

	_check(sel.alternar("c.test", false, false, VISIBLES).is_empty(), "repetir el unico clic no cambia nada")


func _rango() -> void:
	var sel := _sel()
	sel.alternar("b.test", false, false, VISIBLES)
	var cambios := sel.alternar("d.test", false, true, VISIBLES)
	_check(sel.contar() == 3, "mayus+clic marca el rango desde el ancla")
	_check(sel.contiene("c.test"), "incluyendo las filas intermedias")
	_check(cambios.size() == 2, "y avisa solo de las que de verdad cambian de estado")

	cambios = sel.alternar("a.test", false, true, VISIBLES)
	_check(sel.contar() == 2, "el rango hacia atras empieza en el ancla y baja")
	_check(sel.contiene("a.test") and sel.contiene("b.test"), "quedan la primera y la segunda")
	_check(not sel.contiene("d.test"), "la de mas alla del rango se suelta")

	_check(sel.alternar("d.test", false, true, VISIBLES).size() == 3, "el rango hacia delante cubre hasta el final")
	_check(sel.ancla() == "b.test", "el ancla no se mueve al marcar un rango")

	var otro := _sel()
	otro.alternar("a.test", false, true, VISIBLES)
	_check(otro.contar() == 1 and otro.contiene("a.test"), "sin ancla previa el rango cae en un clic normal")
	_check(otro.alternar("d.test", false, true, VISIBLES).size() == 3, "y suelta lo anterior")

	var fuera := _sel()
	fuera.alternar("z.test", false, false, VISIBLES)
	fuera.alternar("d.test", false, true, VISIBLES)
	_check(fuera.contar() == 1 and fuera.contiene("d.test"), "si el ancla ya no esta visible el rango se trata como clic normal")

	var ambos := _sel()
	ambos.alternar("a.test", false, false, VISIBLES)
	ambos.alternar("c.test", true, true, VISIBLES)
	_check(ambos.contar() == 2, "ctrl+mayus alterna en vez de marcar rango")
	_check(ambos.contiene("a.test") and ambos.contiene("c.test"), "y anade la nueva sin quitar la anterior")


func _todo_y_limpiar() -> void:
	var sel := _sel()
	sel.alternar("b.test", true, false, VISIBLES)
	_check(sel.seleccionar_todo(VISIBLES).size() == 3, "seleccionar todo anade las que faltaban")
	_check(sel.contar() == 4, "y quedan las cuatro visibles")
	_check(sel.seleccionar_todo(VISIBLES).is_empty(), "repetirlo no cambia nada")
	_check(sel.seleccionar_todo(["a.test", "b.test"]).size() == 2, "con filtro activo se queda solo con lo filtrado")
	_check(sel.contar() == 2 and not sel.contiene("c.test"), "y suelta lo que el filtro deja fuera")
	_check(sel.ancla() == "a.test", "el ancla pasa a la primera fila visible")

	_check(sel.limpiar().size() == 2, "limpiar devuelve las que estaban seleccionadas")
	_check(sel.contar() == 0 and sel.ancla().is_empty(), "y no deja ancla colgando")

	_check(_sel().seleccionar_todo([]).is_empty(), "sin filas visibles no hay nada que seleccionar")
	_check(_sel().alternar("", false, false, VISIBLES).is_empty(), "una url vacia no se selecciona")


func _conservar() -> void:
	var sel := _sel()
	sel.seleccionar_todo(VISIBLES)
	_check(sel.conservar(VISIBLES).is_empty(), "si el catalogo sigue entero no se cae nada")
	_check(sel.contar() == 4, "y la seleccion sigue entera")

	_check(sel.conservar(["a.test", "b.test"]).size() == 2, "lo que ya no esta en el catalogo se cae")
	_check(sel.contar() == 2 and not sel.contiene("c.test"), "y solo se quedan las vivas")

	sel.alternar("b.test", false, false, VISIBLES)
	_check(sel.conservar(["a.test"]).size() == 1, "conservar tambien limpia el ancla que se queda sin fila")
	_check(sel.ancla().is_empty(), "y el ancla no apunta a nada")

	var sel2 := _sel()
	sel2.seleccionar_todo(["a.test", "b.test", "c.test"])
	_check(sel2.intersectar(["b.test", "c.test", "d.test"]) == ["b.test", "c.test"], "intersectar devuelve solo las que siguen en el catalogo")
	_check(sel2.intersectar([]).is_empty(), "y si no queda ninguna no inventa ninguna")
	_check(sel2.contar() == 3, "intersectar no toca la seleccion")


func _tecla(ctrl: bool, mayus: bool, code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.ctrl_pressed = ctrl
	k.shift_pressed = mayus
	k.pressed = true
	return k


func _atajos() -> void:
	_check(SeleccionControllerScript.atajo_de(_tecla(true, false, KEY_A)) == "todo", "ctrl+A selecciona todo")
	_check(SeleccionControllerScript.atajo_de(_tecla(true, false, KEY_C)) == "copiar", "ctrl+C copia")
	_check(SeleccionControllerScript.atajo_de(_tecla(true, false, KEY_ENTER)) == "comprobar", "ctrl+intro comprueba")
	_check(SeleccionControllerScript.atajo_de(_tecla(true, false, KEY_KP_ENTER)) == "comprobar", "el enter del teclado numerico tambien")
	_check(SeleccionControllerScript.atajo_de(_tecla(false, true, KEY_DELETE)) == "eliminar", "mayus+supr elimina")
	_check(SeleccionControllerScript.atajo_de(_tecla(true, false, KEY_B)) == "", "ctrl+B no es un atajo de seleccion")
	_check(SeleccionControllerScript.atajo_de(_tecla(false, false, KEY_DELETE)) == "", "supr a secas no borra sin mayus")
	_check(SeleccionControllerScript.atajo_de(_tecla(true, true, KEY_A)) == "", "ctrl+mayus+A no dispara el de seleccionar todo")
	_check(SeleccionControllerScript.atajo_de(InputEventMouseButton.new()) == "", "el raton no entra por aqui")

	var repetida := _tecla(true, false, KEY_A)
	repetida.echo = true
	_check(SeleccionControllerScript.atajo_de(repetida) == "", "no se repite al mantener pulsada la tecla")
	var soltada := _tecla(true, false, KEY_A)
	soltada.pressed = false
	_check(SeleccionControllerScript.atajo_de(soltada) == "", "ni al soltar")


func _textos() -> void:
	_check(SeleccionControllerScript.texto_contador(0) == "0 seleccionados", "sin seleccion el contador va a cero")
	_check(SeleccionControllerScript.texto_contador(1) == "1 seleccionado", "una sola fila se cuenta en singular")
	_check(SeleccionControllerScript.texto_contador(7) == "7 seleccionados", "varias van en plural")
	_check(SeleccionControllerScript.texto_copiadas(3) == "3 URLs copiadas", "copiar avisa de cuantas son")
	_check(SeleccionControllerScript.texto_borrados(1) == "Enlace eliminado", "un enlace se avisa en singular")
	_check(SeleccionControllerScript.texto_borrados(6) == "6 enlaces eliminados", "varios en plural")
	_check(SeleccionControllerScript.texto_eliminar(1, "https://a.test") == "¿Eliminar «https://a.test» para siempre?", "el aviso de uno nombra el enlace")
	_check(SeleccionControllerScript.texto_eliminar(4, "https://a.test").contains("4"), "el de varios dice cuantos")
	_check(not SeleccionControllerScript.texto_eliminar(4, "https://a.test").contains("a.test"), "y no confunde uno con muchos")
	_check(SeleccionControllerScript.texto_eliminar(0, "https://a.test").contains("https://a.test"), "ninguno se trata como uno")
	_check(SeleccionControllerScript.texto_eliminar(1, "https://a.test", "Mi enlace") == "¿Eliminar «Mi enlace» para siempre?", "si la fila trae etiqueta, se nombra la etiqueta y no la url")


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)