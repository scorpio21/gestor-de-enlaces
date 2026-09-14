extends SceneTree

const GestorArchivoScript := preload("res://scripts/gestor_archivo.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const BASE := "user://__test_gestor_archivo__"
const RUTA := BASE + "/catalogo.json"
const MIXTO := BASE + "/mixto.json"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)

	var entradas := [
		{"nombre": "A", "desc": "Uno", "url": "HTTPS://X.test/", "img": "res://Assets/png/img_a.png", "cat": "Patch"},
		{"nombre": "B", "desc": "Dos", "url": "https://bb.test/x", "img": "", "cat": "otro", "extracampo": 7},
	]

	var re := GestorArchivoScript.exportar(RUTA, entradas)
	_check(re.get("ok", false) and int(re.get("total", -1)) == 2, "exportar escribe el catálogo y cuenta entradas")

	var leido: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	_check(typeof(leido) == TYPE_ARRAY and (leido as Array).size() == 2, "el archivo exportado es un JSON de array")

	var primero: Dictionary = (leido as Array)[0]
	_check(not primero.has("extracampo") and str(primero.get("nombre", "")) == "A", "exportar conserva solo los campos del catálogo")

	var re_err := GestorArchivoScript.exportar(BASE + "/nohay/c.json", [])
	_check(not re_err.get("ok", true) and not str(re_err.get("error", "")).is_empty(), "exportar a una carpeta inexistente falla con error")

	var ri_faltante := GestorArchivoScript.importar(BASE + "/no-existe.json", [])
	_check(not ri_faltante.get("ok", true) and str(ri_faltante.get("error", "")) == "El archivo no es un catálogo válido.", "importar un archivo inexistente falla con el mensaje de catálogo inválido")

	var f_noarr := FileAccess.open(BASE + "/no-array.json", FileAccess.WRITE)
	f_noarr.store_string("{\"a\":1}")
	f_noarr.close()
	var ri_noarr := GestorArchivoScript.importar(BASE + "/no-array.json", [])
	_check(not ri_noarr.get("ok", true) and str(ri_noarr.get("error", "")) == "El archivo no es un catálogo válido.", "importar un JSON que no es array falla con el mismo mensaje")

	var ri_rt := GestorArchivoScript.importar(RUTA, [])
	var entradas_rt: Array = ri_rt.get("entradas", [])
	_check(ri_rt.get("ok", false) and entradas_rt.size() == 2, "importar roundtrip devuelve las entradas saneadas")

	var ent0: Dictionary = entradas_rt[0]
	var ent1: Dictionary = entradas_rt[1]
	_check(str(ent0.get("url", "")) == "https://x.test" and str(ent0.get("cat", "")) == "parche", "importar normaliza url y categoría")
	_check(str(ent0.get("img", "")) == "res://Assets/png/img_a.png", "importar conserva el campo img")
	_check(not ent1.has("extracampo") and str(ent1.get("url", "")) == "https://bb.test/x", "importar conserva solo campos conocidos")

	var mezclado: Array = [
		"texto",
		42,
		{"nombre": "A", "url": "https://x.test"},
		{"nombre": "C", "url": "https://c.test"},
		{"nombre": "C2", "url": "https://C.test"},
		{"nombre": "vacía", "url": ""},
	]
	var f_mixto := FileAccess.open(MIXTO, FileAccess.WRITE)
	f_mixto.store_string(JSON.stringify(mezclado, "\t"))
	f_mixto.close()

	var ri_m := GestorArchivoScript.importar(MIXTO, ["https://x.test"])
	var entradas_m: Array = ri_m.get("entradas", [])
	_check(ri_m.get("ok", false) and entradas_m.size() == 1 and str(entradas_m[0].get("url", "")) == "https://c.test", "importar sanea: omite no-dicts, sin URL, duplicados (externos e internos)")
	_check(int(ri_m.get("omitidas", -1)) == 5, "importar cuenta las omitidas")

	var ri_todo := GestorArchivoScript.importar(MIXTO, ["https://x.test", "https://c.test", "https://C.test", "https://c.test/"])
	_check((ri_todo.get("entradas", []) as Array).is_empty(), "importar con existentes que ya cubren todo no añade nada")

	var re_vacio := GestorArchivoScript.exportar(BASE + "/vacio.json", [])
	_check(re_vacio.get("ok", false) and int(re_vacio.get("total", -1)) == 0 and FileAccess.get_file_as_string(BASE + "/vacio.json") == "[]", "exportar un catálogo vacío produce un JSON vacío")

	var f_solo_vacias := FileAccess.open(BASE + "/solo-vacias.json", FileAccess.WRITE)
	f_solo_vacias.store_string(JSON.stringify([{"nombre": "S", "url": ""}], "\t"))
	f_solo_vacias.close()
	var ri_sv := GestorArchivoScript.importar(BASE + "/solo-vacias.json", [])
	_check(ri_sv.get("ok", false) and (ri_sv.get("entradas", []) as Array).is_empty() and int(ri_sv.get("omitidas", -1)) >= 1, "importar con solo entradas sin URL devuelve ok y entradas vacías")

	_cerrar()


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  check OK — ", nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK: 14 checks")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)