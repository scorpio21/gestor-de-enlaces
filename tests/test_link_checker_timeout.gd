extends SceneTree

const LinkChecker := preload("res://scripts/link_checker.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var checker := LinkChecker.new()
	_check(is_equal_approx(checker.timeout_s, 10.0), "timeout_s tiene default 10.0")
	checker.timeout_s = 25.0
	_check(is_equal_approx(checker.timeout_s, 25.0), "timeout_s es asignable")
	checker.free()
	_cerrar()


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
