extends SceneTree

const TemaSistemaScript := preload("res://scripts/tema_sistema.gd")

var _fallos := 0


func _initialize() -> void:
	_check(TemaSistemaScript.resolver("claro", true, true) == "claro", "el modo manual claro se mantiene")
	_check(TemaSistemaScript.resolver("oscuro", true, false) == "oscuro", "el modo manual oscuro se mantiene")
	_check(TemaSistemaScript.resolver("auto", false, true) == "oscuro", "auto sin soporte del SO cae a oscuro")
	_check(TemaSistemaScript.resolver("auto", true, true) == "oscuro", "auto con SO oscuro resuelve oscuro")
	_check(TemaSistemaScript.resolver("auto", true, false) == "claro", "auto con SO claro resuelve claro")
	_check(TemaSistemaScript.resolver("chocolate", true, false) == "oscuro", "un modo inválido cae al defecto")
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