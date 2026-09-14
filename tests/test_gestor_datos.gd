extends SceneTree

const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const BASE := "user://__test_gestor_datos__"
const RUTA := BASE + "/catalogo.json"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)

	_check(GestorDatosScript.version_de(BASE + "/no-existe.json") == -1, "version_de de un archivo inexistente es -1")

	var f_v0 := FileAccess.open(BASE + "/v0.json", FileAccess.WRITE)
	f_v0.store_string(JSON.stringify([{"nombre": "A", "url": "https://a.test"}], "\t"))
	f_v0.close()
	_check(GestorDatosScript.version_de(BASE + "/v0.json") == 0, "version_de de un array plano (v0) es 0")

	var f_v1 := FileAccess.open(BASE + "/v1.json", FileAccess.WRITE)
	f_v1.store_string(JSON.stringify({"schema_version": 1, "enlaces": [{"nombre": "B", "url": "https://b.test"}]}, "\t"))
	f_v1.close()
	_check(GestorDatosScript.version_de(BASE + "/v1.json") == 1, "version_de de un archivo v1 es 1")

	var entradas_v0 := GestorDatosScript.cargar(BASE + "/v0.json")
	_check(entradas_v0.size() == 1 and str(entradas_v0[0].get("url", "")) == "https://a.test", "cargar migra un array plano y devuelve sus entradas")
	var migrado: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASE + "/v0.json"))
	_check(typeof(migrado) == TYPE_DICTIONARY and int(migrado.get("schema_version", -1)) == 1, "cargar reescribe el v0 como v1 en disco")

	var entradas_v1 := GestorDatosScript.cargar(BASE + "/v1.json")
	_check(entradas_v1.size() == 1 and str(entradas_v1[0].get("url", "")) == "https://b.test", "cargar devuelve las entradas de un v1")

	_check(GestorDatosScript.cargar(BASE + "/no-existe.json").is_empty(), "cargar de un archivo inexistente devuelve []")

	var f_raro := FileAccess.open(BASE + "/raro.json", FileAccess.WRITE)
	f_raro.store_string("{\"a\":1}")
	f_raro.close()
	_check(GestorDatosScript.cargar(BASE + "/raro.json").is_empty(), "cargar de un JSON que no es array ni v1 devuelve []")

	var texto_futuro := JSON.stringify({"schema_version": 2, "enlaces": [{"nombre": "Z"}]}, "\t")
	var f_futuro := FileAccess.open(BASE + "/futuro.json", FileAccess.WRITE)
	f_futuro.store_string(texto_futuro)
	f_futuro.close()
	_check(GestorDatosScript.cargar(BASE + "/futuro.json").is_empty(), "cargar de un esquema futuro devuelve []")
	_check(FileAccess.get_file_as_string(BASE + "/futuro.json") == texto_futuro, "cargar no modifica el archivo de esquema futuro")

	_check(GestorDatosScript.guardar(RUTA, [{"nombre": "A", "url": "https://a.test"}]), "guardar escribe el catálogo")
	var guardado: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	_check(typeof(guardado) == TYPE_DICTIONARY and int(guardado.get("schema_version", -1)) == 1 and (guardado.get("enlaces", []) as Array).size() == 1, "guardar crea un JSON v1 con enlaces")

	var segundo_ok := GestorDatosScript.guardar(RUTA, [{"nombre": "A2", "url": "https://a2.test"}])
	_check(segundo_ok, "guardar rota el archivo en el segundo guardado")
	var bak_v1: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA + ".bak"))
	_check(segundo_ok and typeof(bak_v1) == TYPE_DICTIONARY and str((bak_v1.get("enlaces", []) as Array)[0].get("url", "")) == "https://a.test", "el segundo guardado deja en .bak el contenido previo")
	_check(not FileAccess.file_exists(RUTA + ".tmp"), "guardar no deja archivos temporales")

	_check(not GestorDatosScript.guardar(BASE + "/sin-carpeta/c.json", []), "guardar a una carpeta inexistente falla")

	_check(GestorDatosScript.hay_copia(RUTA), "hay_copia es true cuando existe el .bak")
	_check(GestorDatosScript.restaurar_copia(RUTA) and str(GestorDatosScript.cargar(RUTA)[0].get("url", "")) == "https://a.test", "restaurar_copia recupera el catálogo anterior desde el .bak")
	_check(not GestorDatosScript.restaurar_copia(BASE + "/no-existe.json"), "restaurar_copia sin copia falla")

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