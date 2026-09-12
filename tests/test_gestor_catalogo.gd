extends SceneTree

const GestorCatalogo := preload("res://scripts/gestor_catalogo.gd")

var _fallos := 0


func _initialize() -> void:
	_check(GestorCatalogo.dominio("https://www.ejemplo.com/ao") == "ejemplo.com", "dominio quita esquema, www. y ruta")
	_check(GestorCatalogo.dominio("http://ejemplo.com") == "ejemplo.com", "dominio con http")
	_check(GestorCatalogo.dominio("https://ejemplo.com/path?q=1") == "ejemplo.com", "dominio ignora ruta y query")
	_check(GestorCatalogo.dominio("ejemplo.com") == "ejemplo.com", "dominio sin esquema")
	_check(GestorCatalogo.dominio("https://sub.ejemplo.com:8080/x") == "sub.ejemplo.com:8080", "dominio conserva el puerto")
	_check(GestorCatalogo.dominio("") == "", "dominio de URL vacía es vacío")

	var sep := GestorCatalogo.separar([], [])
	_check(sep.get("nuevas", []) == [] and sep.get("repetidas", []) == [], "separar con listas vacías")
	sep = GestorCatalogo.separar(["https://a.com"], ["https://a.com", "https://b.com"])
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == ["https://a.com"], "separar detecta colisión con existentes")
	sep = GestorCatalogo.separar(["  https://a.com  "], ["https://a.com"])
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == ["https://a.com"], "separar recorta espacios antes de comparar")
	sep = GestorCatalogo.separar(["HTTPS://A.COM"], ["https://a.com"])
	_check(sep.get("nuevas") == ["HTTPS://A.COM"] and sep.get("repetidas") == [], "separar distingue mayúsculas")
	sep = GestorCatalogo.separar(["https://a.com", "https://b.com", "https://a.com"], [])
	_check(sep.get("nuevas") == ["https://a.com", "https://b.com"] and sep.get("repetidas") == ["https://a.com"], "separar conserva la primera y marca las repetidas del lote")
	sep = GestorCatalogo.separar(["https://a.com", "https://b.com"], ["https://c.com"])
	_check(sep.get("nuevas") == ["https://a.com", "https://b.com"] and sep.get("repetidas") == [], "separar sin duplicados")
	sep = GestorCatalogo.separar(["", " "], [])
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == [], "separar descarta líneas vacías")

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