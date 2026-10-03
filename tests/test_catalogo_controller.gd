extends SceneTree

const CatalogoControllerScript := preload("res://scripts/catalogo_controller.gd")
const Ayuda := preload("res://tests/ayuda.gd")
const ASSETS := "user://__test_catalogo_ctrl__/Assets"

var _fallos := 0
var _cat = CatalogoControllerScript.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/png" % ASSETS))
	_consultas()
	_agregar()
	_agregar_lote()
	_editar()
	_editar_url()
	_editar_imagen()
	_actualizar_url()
	_eliminar()
	_capturas()
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _entrada(nombre: String, url: String, img := "", cat := "otro") -> Dictionary:
	return {"nombre": nombre, "desc": "", "url": url, "img": img, "cat": cat}


func _consultas() -> void:
	var entradas: Array = [_entrada("A", "https://a.test"), _entrada("B", "http://b.test/")]
	_check(_cat.urls_existentes(entradas) == ["https://a.test", "http://b.test/"], "urls_existentes devuelve las URLs en orden")
	_check(_cat.urls_existentes(["basura", 7]) == [], "urls_existentes ignora lo que no es entrada")
	_check(_cat.url_existente(entradas, "HTTPS://A.test/") == "https://a.test", "url_existente compara por clave canonica, no por texto")
	_check(_cat.url_existente(entradas, "https://c.test") == "", "url_existente devuelve cadena vacia si no esta")
	_check(_cat.buscar_entrada(entradas, "http://b.test/").get("nombre") == "B", "buscar_entrada encuentra por URL exacta")
	_check(_cat.buscar_entrada(entradas, "https://b.test").is_empty(), "buscar_entrada es literal, no canonico")
	_check(_cat.indice_entrada(entradas, "HTTPS://A.TEST/") == 0, "indice_entrada usa la clave canonica")
	_check(_cat.indice_entrada(entradas, "https://z.test") == -1, "indice_entrada devuelve -1 si no esta")
	_check(_cat.indice_entrada(entradas, "") == -1, "indice_entrada con URL vacia no revienta")
	_check(_cat.indice_entrada([1, "x"], "https://a.test") == -1, "indice_entrada tolera entradas que no son diccionarios")
	_check(_cat.cambios_url_validos(entradas, "https://a.test", "https://c.test"), "cambios_url_validos acepta una URL libre")
	_check(not _cat.cambios_url_validos(entradas, "https://a.test", "http://b.test/"), "cambios_url_validos rechaza una URL ya presente")
	_check(_cat.cambios_url_validos(entradas, "https://a.test", "https://a.test"), "cambios_url_validos acepta dejar la misma URL")

	var normalizada: Dictionary = _cat.normalizar_entrada({"url": "HTTPS://X.test/", "cat": "inventada", "tags": "uno, dos"})
	_check(str(normalizada.get("url")) == "https://x.test", "normalizar_entrada canoniza la URL")
	_check(str(normalizada.get("cat")) == "otro", "normalizar_entrada lleva una categoria desconocida a otro")
	_check(normalizada.get("tags") == ["dos", "uno"], "normalizar_entrada parsea las etiquetas")
	_check(not normalizada.has("desc"), "normalizar_entrada no inventa campos que no vienen")


func _agregar() -> void:
	var entradas: Array = [_entrada("A", "https://a.test")]
	var res: Dictionary = _cat.agregar(entradas, {"nombre": "B", "url": "HTTPS://B.test/", "cat": "cliente", "tags": "x"})
	_check(res.get("ok", false), "agregar anade una entrada nueva")
	_check(entradas.size() == 2, "agregar deja la entrada en el array")
	_check(str(entradas[1].get("url")) == "https://b.test", "agregar guarda la URL canonica")
	_check(str(entradas[1].get("cat")) == "cliente", "agregar guarda la categoria")
	_check(str(res.get("mensaje", "")).contains("B"), "agregar informa del nombre anadido")

	res = _cat.agregar(entradas, {"nombre": "otra", "url": "HTTPS://A.TEST"})
	_check(not res.get("ok", true), "agregar rechaza una URL duplicada por clave canonica")
	_check(entradas.size() == 2, "agregar no anade nada cuando la URL ya existe")
	_check(str(res.get("mensaje", "")).contains("https://a.test"), "agregar informa de la URL que ya existia")

	res = _cat.agregar(entradas, {"nombre": "C", "url": "https://c.test", "img_reutilizada": true})
	_check(res.get("reutilizada", false), "agregar propaga que la captura se reutilizo")
	res = _cat.agregar(entradas, {"nombre": "C", "url": "https://c.test"})
	_check(not res.get("reutilizada", false), "agregar sin reutilizacion lo dice")

	var datos := {"nombre": "D", "url": "https://d.test"}
	_cat.agregar([datos], {"nombre": "otro", "url": "https://e.test"})
	_check(datos.get("url") == "https://d.test", "agregar no modifica el diccionario que le pasan")


func _agregar_lote() -> void:
	var entradas: Array = [_entrada("A", "https://a.test")]
	var res: Dictionary = _cat.agregar_lote(entradas, [
		"https://b.test",
		"  https://c.test  ",
		"HTTPS://B.TEST/",
		"no-es-una-url",
		"ftp://x.test",
		42,
	])
	_check(res.get("ok", false), "agregar_lote anade las nuevas")
	_check(int(res.get("nuevas", 0)) == 2, "agregar_lote cuenta solo las nuevas, sin repetidas ni invalidas")
	_check(entradas.size() == 3, "agregar_lote anade dos entradas")
	_check(str(entradas[1].get("nombre")) == "b.test", "agregar_lote deriva el nombre del dominio")
	_check(str(entradas[1].get("cat")) == "otro", "agregar_lote deja la categoria en otro")
	_check(str(entradas[1].get("desc")) == "", "agregar_lote deja la descripcion vacia")
	var mensaje := str(res.get("mensaje", ""))
	_check(mensaje.contains("2"), "agregar_lote dice cuantas anadio")
	_check(mensaje.contains("1 repetidas"), "agregar_lote avisa de las repetidas")
	_check(mensaje.contains("2 inv"), "agregar_lote avisa de las invalidas")

	res = _cat.agregar_lote(entradas, ["https://a.test", "basura"])
	_check(not res.get("ok", true), "agregar_lote sin nuevas no dice que anadio nada")
	_check(entradas.size() == 3, "agregar_lote sin nuevas no toca el array")
	_check(str(res.get("mensaje", "")).contains("No se añadió ningún enlace."), "agregar_lote sin nuevas lo explica")
	_check(str(res.get("mensaje", "")).contains("1 repetidas"), "agregar_lote sin nuevas cuenta las repetidas")
	_check(str(res.get("mensaje", "")).contains("1 inv"), "agregar_lote sin nuevas cuenta las invalidas")

	res = _cat.agregar_lote([], [])
	_check(not res.get("ok", true), "agregar_lote con lista vacia no falla")
	_check(str(res.get("mensaje", "")) == "No se añadió ningún enlace.", "agregar_lote con lista vacia solo dice eso")

	res = _cat.agregar_lote(entradas, ["solo-repetidas", "https://a.test"])
	_check(not res.get("ok", true), "agregar_lote con todo repetido no anade")
	_check(entradas.size() == 3, "agregar_lote con todo repetido deja el array igual")


func _editar() -> void:
	var entradas: Array = [_entrada("A", "https://a.test"), _entrada("B", "https://b.test")]
	var res: Dictionary = _cat.editar(entradas, {}, [], {"nombre": "A2", "desc": "D", "url": "https://a.test", "cat": "servidor", "tags": "nueva"}, "https://a.test", ASSETS)
	_check(res.get("ok", false), "editar con la misma URL funciona")
	_check(str(entradas[0].get("nombre")) == "A2", "editar cambia el nombre")
	_check(str(entradas[0].get("desc")) == "D", "editar cambia la descripcion")
	_check(str(entradas[0].get("cat")) == "servidor", "editar cambia la categoria")
	_check(entradas[0].get("tags") == ["nueva"], "editar cambia las etiquetas")
	_check(res.get("renombrar", []).is_empty(), "editar sin cambio de URL no renombra claves")
	_check(str(res.get("mensaje", "")).contains("A2"), "editar informa del nombre nuevo")

	res = _cat.editar(entradas, {}, [], {"nombre": "X", "url": "https://a.test"}, "https://nada.test", ASSETS)
	_check(not res.get("ok", true), "editar de una URL que no existe falla")
	_check(str(res.get("mensaje", "")) == "No se encontró el enlace.", "editar de una URL que no existe lo explica")
	_check(entradas.size() == 2, "editar de una URL que no existe no toca el array")

	res = _cat.editar(entradas, {}, [], {"nombre": "A2", "url": "https://a.test", "cat": "inventada"}, "https://a.test", ASSETS)
	_check(str(entradas[0].get("cat")) == "otro", "editar lleva una categoria desconocida a otro")

	var con_tags: Array = [_entrada("A", "https://a.test")]
	_cat.normalizar_entrada({})
	con_tags[0]["tags"] = ["vieja"]
	_cat.editar(con_tags, {}, [], {"nombre": "A", "url": "https://a.test"}, "https://a.test", ASSETS)
	_check(con_tags[0].get("tags") == ["vieja"], "editar sin tocar las etiquetas las conserva")


func _editar_url() -> void:
	var estados := {"a.test": {"valido": true}, "b.test": {"valido": false}}
	var borrados: Array = ["a.test", "c.test"]
	var entradas: Array = [_entrada("A", "http://a.test"), _entrada("B", "http://b.test")]

	var res: Dictionary = _cat.editar(entradas, estados, borrados, {"nombre": "A2", "url": "http://a2.test"}, "http://a.test", ASSETS)
	_check(res.get("ok", false), "editar a una URL nueva funciona")
	_check(str(entradas[0].get("url")) == "http://a2.test", "editar guarda la URL nueva")
	_check(res.get("renombrar", []) == ["a.test", "a2.test"], "editar devuelve el par de claves a renombrar en el store")
	_check(estados.has("a2.test") and not estados.has("a.test"), "editar mueve el estado a la clave nueva")
	_check(str(estados.get("a2.test", {}).get("valido", "")) == "true", "editar conserva el valor del estado al renombrarlo")
	_check(borrados.has("a2.test") and not borrados.has("a.test"), "editar renombra tambien la lista de borrados")
	_check(borrados.has("c.test"), "editar no toca las claves de borrados que no cambian")

	var estados2 := {"z.test": {"valido": true}}
	res = _cat.editar(entradas, estados2, [], {"nombre": "A2", "url": "http://a.test"}, "http://a2.test", ASSETS)
	_check(res.get("renombrar", []) == ["a2.test", "a.test"], "editar de vuelta tambien renombra")
	_check(not estados2.has("a2.test"), "editar de vuelta limpia la clave vieja aunque no hubiera estado")
	_check(estados2.has("z.test"), "editar de vuelta no toca estados ajenos")

	var repetida: Array = [_entrada("A", "http://a.test", "img.png"), _entrada("B", "http://b.test")]
	res = _cat.editar(repetida, {}, [], {"nombre": "A2", "url": "http://b.test", "img": "otra.png", "img_pendiente": "x.png"}, "http://a.test", ASSETS)
	_check(not res.get("ok", true), "editar a una URL que ya existe no modifica la entrada")
	_check(str(repetida[0].get("url")) == "http://a.test", "editar a una URL que ya existe deja la URL original")
	_check(str(repetida[0].get("nombre")) == "A", "editar a una URL que ya existe deja el nombre original")
	_check(res.has("reabrir"), "editar a una URL que ya existe pide reabrir el dialogo")
	_check(str(res.get("reabrir", {}).get("img")) == "img.png", "reabrir recupera la imagen de la entrada, no la del dialogo")
	_check(not res.get("reabrir", {}).has("img_pendiente"), "reabrir quita la imagen pendiente para no volver a copiarla")
	_check(str(res.get("mensaje", "")).contains("http://b.test"), "editar a una URL que ya existe avisa de la colision")

	res = _cat.editar(repetida, {}, [], {"nombre": "A2", "url": "http://a.test/otra-ruta"}, "http://a.test", ASSETS)
	_check(res.get("ok", false), "editar a una variante canonica de la misma URL se permite")


func _actualizar_url() -> void:
	var captura := _crear_captura("img_reub.png")
	var entradas: Array = [_entrada("Foto", "https://viejo.test/foto.png", captura, "cliente")]
	var estados := {"viejo.test/foto.png": {"valido": true, "url_final": "https://nuevo.test/foto.png"}}
	var borrados := ["viejo.test/foto.png"]

	var res: Dictionary = _cat.actualizar_url(entradas, estados, borrados, "https://viejo.test/foto.png", "https://nuevo.test/foto.png")
	_check(res.get("ok", false), "actualizar_url cambia la URL al destino de la redireccion (#59)")
	_check(str(entradas[0].get("url")) == "https://nuevo.test/foto.png", "actualizar_url guarda la URL nueva en la entrada (#59)")
	_check(str(entradas[0].get("nombre")) == "Foto", "actualizar_url no toca el nombre del enlace (#59)")
	_check(str(entradas[0].get("cat")) == "cliente" and entradas[0].get("tags") == [], "actualizar_url conserva categoria y etiquetas (#59)")
	_check(str(entradas[0].get("img")) == captura, "actualizar_url conserva la captura (#59)")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(captura)), "actualizar_url no borra la captura del enlace (#59)")
	_check(res.get("renombrar", []) == ["viejo.test/foto.png", "nuevo.test/foto.png"], "actualizar_url devuelve las claves a renombrar (#59)")
	_check(estados.has("nuevo.test/foto.png") and not estados.has("viejo.test/foto.png"), "actualizar_url mueve el estado a la clave nueva (#59)")
	_check(borrados == ["nuevo.test/foto.png"], "actualizar_url renombra tambien los borrados (#59)")

	var res2: Dictionary = _cat.actualizar_url(entradas, {}, [], "https://nada.test/x.png", "https://otro.test/x.png")
	_check(not res2.get("ok", true), "actualizar_url de una URL que no esta falla (#59)")
	_check(str(res2.get("mensaje", "")) == "No se encontró el enlace.", "actualizar_url de una URL que no esta lo explica (#59)")

	var res3: Dictionary = _cat.actualizar_url(entradas, {}, [], "https://nuevo.test/foto.png", "https://nuevo.test/foto.png")
	_check(not res3.get("ok", true), "actualizar_url a la misma URL no hace nada (#59)")
	_check(str(res3.get("mensaje", "")) == "La URL nueva es la misma.", "actualizar_url a la misma URL lo explica (#59)")

	var res4: Dictionary = _cat.actualizar_url(entradas, {}, [], "https://nuevo.test/foto.png", "")
	_check(not res4.get("ok", true), "actualizar_url sin destino no hace nada (#59)")


func _editar_imagen() -> void:
	var captura := _crear_captura("img_ctrl_antes.png")
	var entradas: Array = [_entrada("A", "https://a.test", captura)]
	var res: Dictionary = _cat.editar(entradas, {}, [], {"nombre": "A", "url": "https://a.test", "img": captura}, "https://a.test", ASSETS)
	_check(res.get("ok", false), "editar sin tocar la imagen funciona")
	_check(str(entradas[0].get("img")) == captura, "editar sin tocar la imagen la conserva")
	_check(str(res.get("img_anterior")) == captura, "editar devuelve la imagen anterior")
	_check(str(res.get("img")) == captura, "editar devuelve la imagen final")

	var nueva := _crear_captura("img_ctrl_nueva.png")
	res = _cat.editar(entradas, {}, [], {"nombre": "A", "url": "https://a.test", "img_pendiente": nueva}, "https://a.test", ASSETS)
	_check(res.get("ok", false), "editar con imagen pendiente copia el fichero")
	_check(str(res.get("img", "")) != nueva, "editar con imagen pendiente guarda la copia, no el origen")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(str(res.get("img", "")))), "la copia existe en disco")
	_check(str(res.get("img_anterior")) == captura, "editar con imagen pendiente dice cual era la anterior")

	res = _cat.editar(entradas, {}, [], {"nombre": "A", "url": "https://a.test", "img": ""}, "https://a.test", ASSETS)
	_check(str(entradas[0].get("img")) == "", "editar quitando la captura la deja vacia")
	_check(str(res.get("img_anterior")) != "", "editar quitando la captura dice cual habia")

	res = _cat.editar(entradas, {}, [], {"nombre": "A", "url": "https://a.test", "img_pendiente": "no-existe-este-fichero.png"}, "https://a.test", ASSETS)
	_check(not res.get("ok", true), "editar con una imagen pendiente que no existe falla")
	_check(str(res.get("mensaje", "")) == "No se pudo procesar la imagen.", "editar con una imagen pendiente que no existe lo explica")
	_check(str(entradas[0].get("img")) == "", "editar con una imagen pendiente que no existe no toca la entrada")


func _eliminar() -> void:
	var entradas: Array = [_entrada("A", "https://a.test", "a.png"), _entrada("B", "https://b.test", "b.png"), _entrada("A2", "HTTPS://A.test/")]
	var res: Dictionary = _cat.eliminar(entradas, "https://a.test")
	_check(res.get("ok", false), "eliminar quita la entrada")
	_check(entradas.size() == 1, "eliminar quita todas las entradas con la misma clave canonica")
	_check(str(res.get("img", "")) == "a.png", "eliminar devuelve la imagen de la entrada quitada")
	_check(str(res.get("clave", "")) == "a.test", "eliminar devuelve la clave del estado a borrar, sin esquema")
	_check(str(entradas[0].get("url")) == "https://b.test", "eliminar deja el resto del array en orden")

	res = _cat.eliminar(entradas, "https://z.test")
	_check(not res.get("ok", true), "eliminar una URL que no esta falla")
	_check(entradas.size() == 1, "eliminar una URL que no esta no toca el array")
	_check(_cat.eliminar([], "https://a.test").get("ok", true) == false, "eliminar sobre un array vacio no revienta")
	_check(str(_cat.eliminar(entradas, "https://b.test").get("clave", "")) == "b.test", "eliminar normaliza la clave que devuelve")


func _capturas() -> void:
	var huerfana := _crear_captura("img_ctrl_huerfana.png")
	var compartida := _crear_captura("img_ctrl_compartida.png")
	var propia := "%s/png/img_ctrl_compartida.png" % ASSETS

	_check(_cat.es_captura_propia(propia, ASSETS), "es_captura_propia acepta una ruta de la base")
	_check(not _cat.es_captura_propia("res://Assets/png/no-disponible.png", ASSETS), "es_captura_propia rechaza una captura del paquete")

	_check(_cat.borrar_captura_si_huerfana([], huerfana, ASSETS), "una captura sin referencias se borra")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(huerfana)), "el fichero desaparece de verdad")

	_check(not _cat.borrar_captura_si_huerfana([], "res://Assets/png/no-disponible.png", ASSETS), "una captura del paquete no se toca")
	_check(FileAccess.file_exists("res://Assets/png/no-disponible.png"), "la captura del paquete sigue en su sitio")

	_check(not _cat.borrar_captura_si_huerfana([], "%s/png/no-disponible.png" % ASSETS, ASSETS), "el archivo fijo de la base tampoco se borra")
	_check(not _cat.borrar_captura_si_huerfana([_entrada("A", "https://a.test", compartida)], compartida, ASSETS), "una captura referenciada no se borra")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(compartida)), "la captura referenciada sigue en disco")
	_check(not _cat.borrar_captura_si_huerfana([], "", ASSETS), "una ruta vacia no se borra")
	_check(not _cat.borrar_captura_si_huerfana([], "otra-base/img.png", ASSETS), "una captura de otra base no se borra")

	# #62: al borrar una entrada, su captura solo se va si ningun otro enlace la usa
	var entradas: Array = [_entrada("A", "https://a.test", compartida), _entrada("B", "https://b.test", compartida)]
	var res: Dictionary = _cat.eliminar(entradas, "https://a.test")
	_check(_cat.borrar_captura_si_huerfana(entradas, str(res.get("img", "")), ASSETS) == false, "una captura compartida con otro enlace sobrevive al borrado (#62)")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(compartida)), "el fichero de la captura compartida no se borra (#62)")
	res = _cat.eliminar(entradas, "https://b.test")
	_check(_cat.borrar_captura_si_huerfana(entradas, str(res.get("img", "")), ASSETS) == true, "cuando ya nadie la usa, se borra (#62)")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(compartida)), "la captura huérfana si se borra (#62)")


func _crear_captura(nombre: String) -> String:
	var ruta := "%s/png/%s" % [ASSETS, nombre]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/png" % ASSETS))
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	img.save_png(ProjectSettings.globalize_path(ruta))
	return ruta


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _limpiar() -> void:
	Ayuda.borrar_arbol(ASSETS)
