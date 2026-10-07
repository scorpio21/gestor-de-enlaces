extends SceneTree

const DialogosControllerScript := preload("res://scripts/dialogos_controller.gd")

var _fallos := 0


func _initialize() -> void:
	TranslationServer.set_locale("es")
	_borrado()
	_reubicar()
	_limpieza()
	_actualizacion()
	_cerrar()


func _borrado() -> void:
	var d := DialogosControllerScript.new()
	_check(d.pedir_borrado([]) == "", "pedir borrado sin urls no ofrece dialogo")
	_check(d.pedir_borrado(["https://a.test"], "A") == "¿Eliminar «A» para siempre?", "en singular nombra la etiqueta")
	_check(d.pendientes_borrado() == ["https://a.test"], "queda registrado lo que se va a borrar")
	var luego := DialogosControllerScript.new()
	_check(luego.pedir_borrado(["https://a.test", "https://b.test"]) == "¿Eliminar 2 enlaces para siempre?", "en plural cuenta los enlaces")
	_check(luego.tomar_borrado() == ["https://a.test", "https://b.test"], "confirmar entrega la lista pendiente")
	_check(luego.tomar_borrado().is_empty(), "confirmar vacía la lista pendiente")
	var cancelado := DialogosControllerScript.new()
	cancelado.pedir_borrado(["https://a.test"])
	cancelado.cancelar_borrado()
	_check(cancelado.pendientes_borrado().is_empty(), "cancelar vacía la lista pendiente")


func _reubicar() -> void:
	var d := DialogosControllerScript.new()
	var entradas := [{"nombre": "Foto", "url": "https://viejo.test/foto.png"}]
	var estados := {"viejo.test/foto.png": {"valido": true, "url_final": "https://nuevo.test/foto.png"}}
	_check(d.pedir_reubicar(["https://viejo.test/foto.png"], entradas, estados) == "¿Actualizar «Foto» a https://nuevo.test/foto.png?", "en singular nombra la fila y el destino")
	_check(d.pendientes_reubicar() == ["https://viejo.test/foto.png"], "queda registrado el enlace a reubicar")
	_check(d.tomar_reubicar() == ["https://viejo.test/foto.png"], "confirmar entrega la lista pendiente")
	_check(d.tomar_reubicar().is_empty(), "confirmar vacía la lista pendiente")

	var plano := DialogosControllerScript.new()
	_check(plano.pedir_reubicar(["https://plano.test/pagina.html"], [], {}) == "", "sin destino no se ofrece reubicar")
	var login := DialogosControllerScript.new()
	var con_login := {"viejo.test/guia.html": {"valido": true, "url_final": "https://final.test/login.html"}}
	_check(login.pedir_reubicar(["https://viejo.test/guia.html"], [], con_login) == "", "un destino de login no se ofrece")
	_check(login.pendientes_reubicar().is_empty(), "y no queda nada pendiente")

	var cancelado := DialogosControllerScript.new()
	cancelado.pedir_reubicar(["https://viejo.test/foto.png"], entradas, estados)
	cancelado.cancelar_reubicar()
	_check(cancelado.pendientes_reubicar().is_empty(), "cancelar vacía la lista pendiente")


func _limpieza() -> void:
	var d := DialogosControllerScript.new()
	d.guardar_limpieza({"ok": true, "borradas": 3, "errores": 1})
	_check(d.tomar_limpieza() == {"ok": true, "borradas": 3, "errores": 1}, "confirmar entrega el resultado de la limpieza")
	_check(d.tomar_limpieza().is_empty(), "confirmar vacía el resultado pendiente")


func _actualizacion() -> void:
	var with_ultima := DialogosControllerScript.resultado_actualizacion({"nueva": true, "version": "2.0", "url": "u"}, false, "", "0.3.0")
	_check(with_ultima == {"modo": "nueva", "version": "2.0", "url": "u"}, "una version nueva sin ver se anuncia")
	var vista := DialogosControllerScript.resultado_actualizacion({"nueva": true, "version": "2.0", "url": "u"}, false, "2.0", "0.3.0")
	_check(vista.is_empty(), "una version nueva ya vista no se anuncia")
	var al_dia := DialogosControllerScript.resultado_actualizacion({"nueva": false, "version": "0.3.0", "error": ""}, true, "", "0.3.0")
	_check(al_dia == {"modo": "al_dia", "version": "0.3.0", "url": ""}, "una comprobacion manual al dia lo dice")
	var con_error := DialogosControllerScript.resultado_actualizacion({"nueva": false, "version": "", "error": "red"}, true, "", "0.3.0")
	_check(con_error == {"modo": "error", "version": "", "url": ""}, "una comprobacion manual con error lo dice")
	var callada := DialogosControllerScript.resultado_actualizacion({"nueva": false, "version": "0.3.0", "error": ""}, false, "", "0.3.0")
	_check(callada.is_empty(), "una comprobacion automatica al dia no molesta")

	var d := DialogosControllerScript.new()
	var contenido := d.aviso_actualizacion("nueva", "2.0", "https://github.com/scorpio21/gestor-de-enlaces")
	_check(str(contenido.get("titulo", "")) == "Nueva versión disponible", "el aviso de nueva version tiene titulo")
	_check(str(contenido.get("texto", "")) == "Hay una nueva versión: 2.0", "y dice la version")
	_check(str(contenido.get("ok", "")) == "Ver release", "y su boton abre el release")
	_check(contenido.get("cancelar", false) == true, "con cancelar visible")
	_check(d.con_aviso(), "queda marcado como aviso pendiente")
	_check(d.version_aviso() == "2.0", "recuerda la version")
	_check(d.url_aviso() == "https://github.com/scorpio21/gestor-de-enlaces", "recuerda la url del release")

	var al_dia_d := DialogosControllerScript.new()
	var al_dia_c := al_dia_d.aviso_actualizacion("al_dia", "0.3.0", "")
	_check(str(al_dia_c.get("texto", "")) == "Estás al día (v0.3.0)", "una comprobacion al dia dice la version actual")
	_check(al_dia_c.get("cancelar", true) == false, "sin boton de cancelar")
	_check(not al_dia_d.con_aviso(), "no queda aviso pendiente")
	_check(al_dia_d.url_aviso().is_empty(), "y no recuerda url alguna")

	var error_d := DialogosControllerScript.new()
	var error_c := error_d.aviso_actualizacion("error", "", "")
	_check(str(error_c.get("titulo", "")) == "Comprobar actualizaciones", "un error tiene titulo de comprobacion")
	_check(str(error_c.get("texto", "")) == "No se pudo comprobar actualizaciones.", "y lo dice")
	_check(not error_d.con_aviso(), "no es ningun aviso pendiente")

	error_d.limpiar_aviso()
	_check(error_d.version_aviso().is_empty() and error_d.url_aviso().is_empty(), "limpiar deja el aviso vacio")


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