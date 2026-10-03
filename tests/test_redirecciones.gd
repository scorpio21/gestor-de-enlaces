extends SceneTree

const Redirecciones := preload("res://scripts/redirecciones.gd")

var _fallos := 0


func _initialize() -> void:
	TranslationServer.set_locale("es")
	_partes()
	_normalizada()
	_reubicable()
	_clasificar_y_explicar()
	_destinos()
	_textos()
	_reubicados()
	_cerrar()


func _partes() -> void:
	var a := Redirecciones.partes("https://ejemplo.com/imagen.png?x=1")
	_check(str(a.get("host", "")) == "ejemplo.com", "partes(): saca el host")
	_check(int(a.get("port", 0)) == 443, "partes(): https sin puerto es 443")
	_check(str(a.get("path", "")) == "/imagen.png?x=1", "partes(): el path incluye la consulta")
	_check(bool(a.get("tls", false)), "partes(): detecta el TLS")

	var b := Redirecciones.partes("http://ejemplo.com:8080")
	_check(int(b.get("port", 0)) == 8080, "partes(): lee un puerto explicito")
	_check(str(b.get("path", "")) == "/", "partes(): sin ruta la inventa")

	_check(Redirecciones.partes("ftp://ejemplo.com").is_empty(), "partes(): un esquema raro no es URL")
	_check(Redirecciones.partes("").is_empty(), "partes(): cadena vacia")
	_check(Redirecciones.sin_www("www.ejemplo.com") == "ejemplo.com", "sin_www(): quita el prefijo")
	_check(Redirecciones.sin_www("ejemplo.com") == "ejemplo.com", "sin_www(): deja intacto lo que no lo lleva")


func _normalizada() -> void:
	_check(Redirecciones.normalizada("http://a.test/foto.png", "https://a.test/foto.png"), "http -> https es normalizacion")
	_check(Redirecciones.normalizada("https://www.a.test/foto.png", "https://a.test/foto.png"), "quitar www es normalizacion")
	_check(Redirecciones.normalizada("http://www.a.test/foto.png", "https://a.test/foto.png"), "las dos cosas a la vez tambien")
	_check(not Redirecciones.normalizada("http://a.test/foto.png", "https://a.test/otra.png"), "otra ruta no es normalizacion")
	_check(not Redirecciones.normalizada("https://a.test/foto.png", "https://b.test/foto.png"), "otro dominio no es normalizacion")
	_check(not Redirecciones.normalizada("https://a.test/foto.png", "https://a.test:8443/foto.png"), "otro puerto no es normalizacion")
	_check(not Redirecciones.normalizada("https://a.test/foto.png", "https://a.test/foto.png"), "la misma URL no es normalizacion")
	_check(not Redirecciones.normalizada("", "https://a.test/foto.png"), "sin origen no hay normalizacion")
	_check(not Redirecciones.normalizada("https://a.test/foto.png", ""), "sin destino no hay normalizacion")


func _reubicable() -> void:
	_check(Redirecciones.reubicable("http://viejo.test/foto.png", "https://nuevo.test/foto.png"), "misma extension en otro dominio se actualiza")
	_check(Redirecciones.reubicable("https://a.test/carpeta/foto.png", "https://b.test/otra/foto.png"), "misma extension en otra carpeta tambien")
	_check(Redirecciones.reubicable("https://a.test/descarga.png", "https://a.test/descarga.png2"), "mismo nombre de archivo con otra extension tambien")

	_check(not Redirecciones.reubicable("http://a.test/foto.png", "https://a.test/foto.png"), "una normalizacion no se ofrece como reubicacion")
	_check(not Redirecciones.reubicable("https://a.test/foto.png", "https://a.test/foto.png"), "la misma URL no se actualiza")
	_check(not Redirecciones.reubicable("https://a.test/foto.png", "https://b.test/"), "una portada no es el mismo recurso")
	_check(not Redirecciones.reubicable("https://drive.test/file/d/ABC", "https://login.b.test/"), "un enlace que cae en un login no se actualiza")
	_check(not Redirecciones.reubicable("https://a.test/foto.png", "https://b.test/login.php"), "un destino de servicio no se actualiza aunque comparta extension")
	_check(not Redirecciones.reubicable("https://a.test/foto.png", "https://b.test/aviso.html"), "una pagina de aviso no se actualiza")
	_check(not Redirecciones.reubicable("https://a.test/foto.png", "https://b.test/guia.html"), "una guia sin el archivo no se actualiza")
	_check(not Redirecciones.reubicable("ftp://a.test/foto.png", "https://b.test/foto.png"), "sin esquema http no hay nada que actualizar")
	_check(not Redirecciones.reubicable("", "https://b.test/foto.png"), "sin origen no hay nada que actualizar")
	_check(not Redirecciones.reubicable("https://a.test/foto.png", ""), "sin destino no hay nada que actualizar")


func _clasificar_y_explicar() -> void:
	_check(Redirecciones.clasificar("http://a.test/foto.png", "https://b.test/foto.png") == Redirecciones.REUBICADO, "clasificar(): reubicado")
	_check(Redirecciones.clasificar("http://a.test/foto.png", "https://a.test/foto.png") == Redirecciones.NORMALIZADA, "clasificar(): normalizada")
	_check(Redirecciones.clasificar("https://a.test/foto.png", "https://b.test/") == Redirecciones.NINGUNA, "clasificar(): sin categoria")
	_check(Redirecciones.REUBICADO != Redirecciones.NORMALIZADA, "las categorias son distintas")

	_check(Redirecciones.explicar("http://a.test/foto.png", "https://b.test/foto.png") == "Redirige a: https://b.test/foto.png", "explicar(): el reubicado nombra el destino")
	_check(Redirecciones.explicar("http://a.test/foto.png", "https://a.test/foto.png").contains("https://a.test/foto.png"), "explicar(): la normalizacion tambien lo nombra")
	_check(Redirecciones.explicar("https://a.test/foto.png", "https://b.test/").is_empty(), "explicar(): sin categoria no dice nada")
	_check(Redirecciones.aviso_destino("https://a.test/foto.png", "https://b.test/foto.png").contains("https://b.test/foto.png"), "aviso_destino(): nombra ambos lados")


func _destinos() -> void:
	var estados := {
		"a.test/foto.png": {"url_final": "https://b.test/foto.png"},
		"a.test/vacio.png": {},
	}
	_check(Redirecciones.destino_de(estados, "https://a.test/foto.png") == "https://b.test/foto.png", "destino_de(): lee la URL final guardada")
	_check(Redirecciones.destino_de(estados, "https://a.test/vacio.png").is_empty(), "destino_de(): sin URL final devuelve cadena vacia")
	_check(Redirecciones.destino_de(estados, "https://c.test/foto.png").is_empty(), "destino_de(): una clave que no existe no inventa nada")

	_check(Redirecciones.reubicables_de(
		["https://a.test/foto.png", "https://a.test/vacio.png", "https://a.test/guia.html"],
		estados
	) == ["https://a.test/foto.png"], "reubicables_de(): deja solo lo que se puede actualizar")
	_check(Redirecciones.reubicables_de([], estados).is_empty(), "reubicables_de(): lista vacia")


func _textos() -> void:
	var entradas := [{"url": "https://a.test/foto.png", "nombre": "Foto vieja"}]
	var estados := {"a.test/foto.png": {"url_final": "https://b.test/foto.png"}}
	var uno := Redirecciones.texto_confirmar(entradas, estados, ["https://a.test/foto.png"])
	_check(uno == "¿Actualizar «Foto vieja» a https://b.test/foto.png?", "texto_confirmar(): uno nombra el enlace y el destino")
	var varios := Redirecciones.texto_confirmar(entradas, estados, ["https://a.test/foto.png", "https://a.test/vacio.png"])
	_check(varios == "¿Actualizar la URL de 2 enlaces a la nueva?", "texto_confirmar(): varios da la cuenta")
	_check(Redirecciones.texto_confirmar(entradas, {}, ["https://c.test/otra.png"]) == "¿Actualizar «https://c.test/otra.png» a ?", "texto_confirmar(): sin entrada a mano usa la URL")
	_check(Redirecciones.texto_actualizadas(1) == "1 URL actualizada", "texto_actualizadas(): el singular tiene su propia forma")
	_check(Redirecciones.texto_actualizadas(3) == "3 URLs actualizadas", "texto_actualizadas(): el plural cuenta")


func _reubicados() -> void:
	var entradas := [
		{"url": "https://a.test/foto.png", "nombre": "Foto"},
		{"url": "https://a.test/vieja.png", "nombre": "Vieja"},
		{"url": "https://a.test/guia.html", "nombre": "Guia"},
		{"url": "https://a.test/login.php", "nombre": "Login"},
		"no es un diccionario",
	]
	var estados := {
		"a.test/foto.png": {"url_final": "https://b.test/foto.png", "fecha": 1000},
		"a.test/vieja.png": {"url_final": "https://c.test/vieja.png", "fecha": 2000},
		"a.test/guia.html": {"url_final": "https://c.test/", "fecha": 3000},
		"a.test/login.php": {"url_final": "https://portal.test/login.php", "fecha": 4000},
	}
	var lista: Array = Redirecciones.reubicados_de(entradas, estados)
	_check(lista.size() == 2, "reubicados_de(): solo cuenta los destinos actualizables")
	_check(str(lista[0].get("nombre", "")) == "Vieja", "reubicados_de(): el mas reciente va primero")
	_check(str(lista[0].get("destino", "")) == "https://c.test/vieja.png", "reubicados_de(): trae el destino")
	_check(int(lista[0].get("fecha", 0)) == 2000, "reubicados_de(): trae la fecha de la comprobacion")
	_check(Redirecciones.reubicados_de([], estados).is_empty(), "reubicados_de(): sin entradas no hay reubicados")
	_check(Redirecciones.reubicados_de(entradas, estados, 0).size() == 2, "reubicados_de(): sin tope devuelve todo")
	_check(Redirecciones.reubicados_de(entradas, estados, 1).size() == 1, "reubicados_de(): el tope recorta")

	var muchas := []
	for i in range(5):
		muchas.append({"url": "https://a.test/foto%d.png" % i, "nombre": "F%d" % i})
	var estados_muchos := {}
	for i in range(5):
		estados_muchos["a.test/foto%d.png" % i] = {"url_final": "https://b.test/foto%d.png" % i, "fecha": i}
	_check(Redirecciones.reubicados_de(muchas, estados_muchos, 2).size() == 2, "reubicados_de(): el tope recorta")


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