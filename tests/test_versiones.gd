extends SceneTree

const VersionesScript := preload("res://scripts/versiones.gd")

var _fallos := 0


func _initialize() -> void:
	_check(VersionesScript.comparar("1.2.0", "0.1.0") == 1, "versión más nueva → 1")
	_check(VersionesScript.comparar("0.1.0", "1.2.0") == -1, "versión más antigua → -1")
	_check(VersionesScript.comparar("0.1.0", "0.1.0") == 0, "misma versión → 0")
	_check(VersionesScript.comparar("1.2.10", "1.2.9") == 1, "compara por componentes decimales")
	_check(VersionesScript.comparar("2.0", "1.5.1") == 1, "longitudes distintas rellenan con 0")
	_check(VersionesScript.comparar("v2.0", "2.0") == 0, "prefijo v se ignora")
	_check(VersionesScript.comparar("1.a", "1.0") == 0, "componente no numérico equivale a 0")

	var parsed := VersionesScript.parsear_release('{"tag_name":"v2.0","html_url":"https://github.com/scorpio21/gestor-de-enlaces/releases/tag/v2.0"}')
	_check(parsed.get("version", "") == "2.0", "parsear_release extrae version sin prefijo v")
	_check(str(parsed.get("url", "")).begins_with("https://github.com/scorpio21/"), "parsear_release extrae la url de la release")
	_check(VersionesScript.manejar_tag("v2.0") == "2.0", "manejar_tag quita el prefijo v")

	_check(VersionesScript.parsear_release("{no es json").is_empty(), "JSON roto devuelve dict vacío")
	_check(VersionesScript.parsear_release('{"tag_name":""}').is_empty(), "tag vacío devuelve dict vacío")
	_check(VersionesScript.parsear_release("[1,2]").is_empty(), "JSON no-objeto devuelve dict vacío")

	_cerrar()


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