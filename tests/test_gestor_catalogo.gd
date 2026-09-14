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
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == ["https://a.com"], "separar colisiona HTTPS/https y devuelve la forma canónica")
	sep = GestorCatalogo.separar(["https://a.com", "https://b.com", "https://a.com"], [])
	_check(sep.get("nuevas") == ["https://a.com", "https://b.com"] and sep.get("repetidas") == ["https://a.com"], "separar conserva la primera y marca las repetidas del lote")
	sep = GestorCatalogo.separar(["https://a.com", "https://b.com"], ["https://c.com"])
	_check(sep.get("nuevas") == ["https://a.com", "https://b.com"] and sep.get("repetidas") == [], "separar sin duplicados")
	sep = GestorCatalogo.separar(["", " "], [])
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == [], "separar descarta líneas vacías")

	_check(GestorCatalogo.normalizar_url("HTTP://Ejemplo.com/a#sec") == "http://ejemplo.com/a", "normalizar_url baja esquema y host y quita el fragmento")
	_check(GestorCatalogo.normalizar_url("http://x.com/") == "http://x.com", "normalizar_url quita el slash de raíz")
	_check(GestorCatalogo.normalizar_url("http://x.com:80/p?q=1") == "http://x.com/p?q=1", "normalizar_url quita el puerto 80 de http")
	_check(GestorCatalogo.normalizar_url("https://x.com:443/A/B/") == "https://x.com/A/B/", "normalizar_url quita el puerto 443 y conserva la subruta")
	_check(GestorCatalogo.normalizar_url("https://x.com:8080/A/B/") == "https://x.com:8080/A/B/", "normalizar_url conserva el puerto no estándar")
	_check(GestorCatalogo.normalizar_url("ftp://x.com") == "ftp://x.com" and GestorCatalogo.normalizar_url("") == "", "normalizar_url no toca no-http ni vacía")
	_check(GestorCatalogo.normalizar_url(GestorCatalogo.normalizar_url("HTTP://x.com/")) == GestorCatalogo.normalizar_url("HTTP://x.com/"), "normalizar_url es idempotente")
	_check(GestorCatalogo.clave_unica("http://X.com/a") == GestorCatalogo.clave_unica("https://x.com/a"), "clave_unica unifica http y https")
	_check(GestorCatalogo.clave_unica("http://x.com/") == "x.com" and GestorCatalogo.clave_unica("https://x.com") == "x.com", "clave_unica ignora esquema y raíz")
	_check(GestorCatalogo.clave_unica("http://x.com/a/") == "x.com/a/" and GestorCatalogo.clave_unica("http://x.com/a/") != GestorCatalogo.clave_unica("http://x.com/a"), "clave_unica conserva el slash de subruta")
	_check(GestorCatalogo.clave_unica("http://x.com:80/a") == GestorCatalogo.clave_unica("http://x.com/a") and GestorCatalogo.clave_unica("http://x.com:8080/a") != GestorCatalogo.clave_unica("http://x.com/a"), "clave_unica ignora solo el puerto por defecto")

	# Categorías
	_check(GestorCatalogo.CATEGORIAS == ["otro", "cliente", "servidor", "codigos", "parche"], "CATEGORIAS tiene las 5 claves en orden")
	_check(GestorCatalogo.normalizar_categoria("") == "otro", "normalizar categoría vacía a otro")
	_check(GestorCatalogo.normalizar_categoria("cliente") == "cliente", "normalizar conserva clave válida")
	_check(GestorCatalogo.normalizar_categoria("Códigos fuente") == "codigos", "normalizar etiqueta con acentos a clave")
	_check(GestorCatalogo.normalizar_categoria("patch") == "parche", "normalizar patch a parche")
	_check(GestorCatalogo.normalizar_categoria("desconocida") == "otro", "normalizar valor desconocido a otro")
	_check(GestorCatalogo.categoria_display("codigos") == "Códigos fuente", "display de codigos")
	_check(GestorCatalogo.categoria_display("cliente") == "Cliente" and GestorCatalogo.categoria_display("") == "Otro", "display de cliente y de desconocida")

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