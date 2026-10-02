extends SceneTree

const InformeControllerScript := preload("res://scripts/informe_controller.gd")
const Ayuda := preload("res://tests/ayuda.gd")

const BASE := "user://__test_informe_controller__"

var _fallos := 0


func _initialize() -> void:
	TranslationServer.set_locale("es")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	_filas()
	_filtro()
	_exportar()
	_cerrar()


func _entradas() -> Array:
	return [
		{"nombre": "A", "url": "https://a.test", "desc": "", "img": "", "cat": "servidor"},
		{"nombre": "B", "url": "https://b.test", "desc": "", "img": "", "cat": "cliente"},
		{"nombre": "C", "url": "https://c.test", "desc": "", "img": "", "cat": "servidor"},
		"no es un diccionario",
		{"nombre": "sin url"},
	]


func _estados() -> Dictionary:
	return {
		"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1700000000, "intentos": 1},
		"b.test": {"valido": false, "mensaje": "Connection refused", "codigo": 0, "fecha": 1700000001, "intentos": 2, "motivo": "red"},
	}


func _filas() -> void:
	var filas := InformeControllerScript.filas(_entradas(), _estados())
	_check(filas.size() == 3, "una fila por cada entrada con url (las que no lo son se ignoran)")
	_check(str(filas[0].get("nombre")) == "A", "la primera fila es la primera entrada")
	_check(str(filas[1].get("estado")) != "Sin comprobar", "un enlace caido no sale como sin comprobar")
	_check(str(filas[2].get("estado")) == "Sin comprobar", "uno sin estado guardado sale como sin comprobar")
	_check(int(filas[2].get("fecha")) == 0, "y con fecha a cero")
	_check(str(filas[0].get("causa")) == "Correcto", "un enlace correcto se explica como correcto")
	_check(str(filas[1].get("causa")) != "", "un fallo de red explica la causa")
	_check(int(filas[1].get("fecha")) == 1700000001, "la fecha sale del estado guardado")
	_check(str(filas[2].get("causa")).is_empty(), "uno sin estado guardado no tiene causa inventada")

	var sin_url := InformeControllerScript.filas([{"nombre": "sin url"}], {})
	_check(sin_url.is_empty(), "una entrada sin url no genera fila")

	var vacio := InformeControllerScript.filas([], {})
	_check(vacio.is_empty(), "sin entradas no hay filas")
	_check(InformeControllerScript.filas([], {}).is_empty(), "y se puede llamar dos veces")


func _filtro() -> void:
	var todas := InformeControllerScript.filas(_entradas(), _estados())
	_check(todas.size() == 3, "sin filtro salen todas")

	var dos := InformeControllerScript.filas(_entradas(), _estados(), ["https://a.test", "https://c.test"])
	_check(dos.size() == 2, "con urls concretas salen solo esas")
	_check(str(dos[0].get("url")) == "https://a.test", "en el orden del catalogo, no el de la seleccion")
	_check(str(dos[1].get("url")) == "https://c.test", "y la segunda tambien")
	_check(str(dos[1].get("estado")) == "Sin comprobar", "con su estado puesto")

	var al_reves := InformeControllerScript.filas(_entradas(), _estados(), ["https://c.test", "https://a.test"])
	_check(str(al_reves[0].get("url")) == "https://a.test", "el orden de la seleccion no altera el resultado")

	var por_clave := InformeControllerScript.filas(_entradas(), _estados(), ["a.test", "c.test"])
	_check(por_clave.is_empty(), "el filtro compara con la url entera, no con la clave normalizada")

	var ninguna := InformeControllerScript.filas(_entradas(), _estados(), ["https://z.test"])
	_check(ninguna.is_empty(), "una url que no esta en el catalogo no inventa una fila")
	_check(InformeControllerScript.filas(_entradas(), _estados(), []).size() == 3, "una lista vacia se toma como sin filtro")


func _exportar() -> void:
	_check(InformeControllerScript.formato_de("informe.html") == "html", "por extension se deduce html")
	_check(InformeControllerScript.formato_de("informe.HTML") == "html", "sin mirar mayusculas")
	_check(InformeControllerScript.formato_de("informe.csv") == "csv", "csv es csv")
	_check(InformeControllerScript.formato_de("informe") == "csv", "sin extension se asume csv")
	_check(InformeControllerScript.formato_de("informe.txt") == "csv", "una extension rara tambien")

	var filas := InformeControllerScript.filas(_entradas(), _estados())
	var ruta_csv := "%s/informe.csv" % BASE
	var res := InformeControllerScript.exportar(ruta_csv, InformeControllerScript.formato_de(ruta_csv), filas)
	_check(bool(res.get("ok", false)), "el csv se escribe")
	_check(int(res.get("total", 0)) == 3, "con las tres filas de entrada")
	_check(str(res.get("ruta")) == ruta_csv, "y devuelve la ruta tal cual")
	var texto := FileAccess.get_file_as_string(ruta_csv)
	_check(texto.contains("https://a.test"), "el csv lleva la url")
	_check(texto.contains("https://b.test"), "de cada fila")
	_check(texto.contains("Connection refused"), "y el mensaje del fallo")

	var ruta_html := "%s/informe.html" % BASE
	var res_html := InformeControllerScript.exportar(ruta_html, InformeControllerScript.formato_de(ruta_html), filas)
	_check(bool(res_html.get("ok", false)), "el html se escribe")
	_check(FileAccess.get_file_as_string(ruta_html).contains("https://c.test"), "con las filas dentro")

	var sin_ext := "%s/informe" % BASE
	var res_tex := InformeControllerScript.exportar(sin_ext, InformeControllerScript.formato_de(sin_ext), filas)
	_check(bool(res_tex.get("ok", false)), "una ruta sin extension se guarda")
	_check(str(res_tex.get("ruta")) == sin_ext + ".csv", "y se le anade .csv")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(sin_ext + ".csv")), "creando el fichero con ese nombre")

	var rota := "%s/no/existe/informe.csv" % BASE
	var res_malo := InformeControllerScript.exportar(rota, "csv", filas)
	_check(not bool(res_malo.get("ok", true)), "una ruta imposible avisa en vez de fingir que ha ido bien")
	_check(not str(res_malo.get("error", "")).is_empty(), "y explica que ha pasado")


func _cerrar() -> void:
	Ayuda.borrar_arbol(BASE)
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