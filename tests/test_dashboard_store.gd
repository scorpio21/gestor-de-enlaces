extends SceneTree

const DashboardStoreScript := preload("res://scripts/dashboard_store.gd")
const BASE := "user://__test_dashboard_store__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var d1 := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 9, "day": 1, "hour": 10})
	var d2 := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 9, "day": 2, "hour": 10})
	var entradas := [
		{"nombre": "A", "url": "https://mediafire.com/a", "cat": "cliente"},
		{"nombre": "B", "url": "https://MEGA.nz/b", "cat": "cliente"},
		{"nombre": "C", "url": "https://mediafire.com/c", "cat": "codigos"},
		{"nombre": "D", "url": "https://mediafire.com/d"},
	]
	var estados := {
		"mediafire.com/a": {"valido": true, "historial": [
			{"fecha": d1, "valido": true, "mensaje": "OK", "codigo": 200},
			{"fecha": d1, "valido": false, "mensaje": "No", "codigo": 404},
			{"fecha": d2, "valido": true, "mensaje": "OK", "codigo": 200},
		]},
		"mega.nz/b": {"valido": false, "historial": [
			{"fecha": d1, "valido": false, "mensaje": "No", "codigo": 404},
		]},
		"mediafire.com/c": {"valido": true, "historial": [
			{"fecha": d2, "valido": true, "mensaje": "OK", "codigo": 200},
		]},
	}
	_resumen(entradas, estados)
	_categorias(entradas, estados)
	_hosts(entradas, estados)
	_serie(entradas, estados)
	_exportacion(entradas, estados)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
	else:
		push_error("%d comprobaciones fallidas" % _fallos)
		quit(1)


func _resumen(entradas: Array, estados: Dictionary) -> void:
	var res: Dictionary = DashboardStoreScript.resumen(entradas, estados)
	_check(int(res.get("total")) == 4, "resumen cuenta los enlaces")
	_check(int(res.get("activos")) == 2, "resumen cuenta los válidos")
	_check(int(res.get("rotos")) == 1, "resumen cuenta los caídos")
	_check(int(res.get("sin_comprobar")) == 1, "resumen cuenta los sin comprobar")
	_check(is_equal_approx(float(res.get("disponible_pct")), 100.0 * 2.0 / 3.0), "resumen calcula el porcentaje sobre comprobados")
	var vacio: Dictionary = DashboardStoreScript.resumen([], {})
	_check(int(vacio.get("total")) == 0 and float(vacio.get("disponible_pct")) == 0.0, "sin datos el resumen es cero")


func _categorias(entradas: Array, estados: Dictionary) -> void:
	var cats: Array = DashboardStoreScript.por_categoria(entradas, estados)
	_check(cats.size() == 3, "por_categoria agrupa las categorías presentes")
	_check(str(cats[0].get("categoria")) == "cliente" and int(cats[0].get("total")) == 2, "por_categoria ordena por total descendente")
	_check(int(cats[0].get("activos")) == 1 and int(cats[0].get("rotos")) == 1, "por_categoria cuenta válidos y caídos por grupo")
	_check(is_equal_approx(float(cats[0].get("disponible_pct")), 50.0), "por_categoria calcula el porcentaje por grupo")
	_check(str(cats[1].get("categoria")) == "codigos", "por_categoria separa las categorías")


func _hosts(entradas: Array, estados: Dictionary) -> void:
	var hosts: Array = DashboardStoreScript.por_host(entradas, estados)
	_check(hosts.size() == 2, "por_host agrupa por host")
	_check(str(hosts[0].get("host")) == "mega.nz", "por_host ordena por caídos primero")
	_check(str(hosts[1].get("host")) == "mediafire.com" and int(hosts[1].get("total")) == 3, "por_host agrupa los enlaces por host")
	var tope: Array = DashboardStoreScript.por_host(entradas, estados, 1)
	_check(tope.size() == 1 and str(tope[0].get("host")) == "mega.nz", "por_host respeta el tope")


func _serie(entradas: Array, estados: Dictionary) -> void:
	var serie: Array = DashboardStoreScript.serie_diaria(entradas, estados)
	_check(serie.size() == 2, "serie_diaria agrupa por día")
	_check(str(serie[0].get("fecha")) == "2026-09-01" and int(serie[0].get("validos")) == 1 and int(serie[0].get("caidos")) == 2, "serie_diaria cuenta válidos y caídos del día 1")
	_check(str(serie[1].get("fecha")) == "2026-09-02" and int(serie[1].get("validos")) == 2 and int(serie[1].get("caidos")) == 0, "serie_diaria cuenta válidos y caídos del día 2")


func _exportacion(entradas: Array, estados: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	var datos: Dictionary = DashboardStoreScript.agregar_datos(entradas, estados)
	_check(datos.has("resumen") and datos.has("categorias") and datos.has("hosts") and datos.has("serie"), "agregar_datos empaqueta los cuatro bloques")
	var ruta_csv := BASE + "/estadisticas.csv"
	var csv: Dictionary = DashboardStoreScript.exportar_csv(ruta_csv, datos)
	_check(csv.get("ok") == true and int(csv.get("total")) == 1 + 3 + 2 + 2, "exportar_csv escribe el bloque completo")
	var contenido := FileAccess.get_file_as_string(ruta_csv)
	_check(contenido.contains("Seccion;Clave;Comprobados;Activos;Rotos;Disponible"), "el CSV incluye la cabecera")
	_check(contenido.contains("Resumen;Total;4;2;1;66.7"), "el CSV incluye el resumen con porcentaje")
	_check(contenido.contains("Categoria;cliente;2;1;1;50.0"), "el CSV incluye una categoría formateada")
	_check(contenido.contains("Host;mega.nz;1;0;1;0.0"), "el CSV incluye un host formateado")
	_check(contenido.contains("Serie;2026-09-01;3;1;2;33.3"), "el CSV incluye la serie diaria")
	var ruta_json := BASE + "/estadisticas.json"
	var json: Dictionary = DashboardStoreScript.exportar_json(ruta_json, datos)
	_check(json.get("ok") == true, "exportar_json escribe el fichero")
	var parse: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta_json))
	var parse_obj: Dictionary = parse if typeof(parse) == TYPE_DICTIONARY else {}
	var resumen_json: Dictionary = parse_obj.get("resumen", {})
	_check(int(resumen_json.get("total")) == 4 and int(resumen_json.get("activos")) == 2, "el JSON mantiene el resumen exportado")
	DirAccess.remove_absolute(BASE)


func _check(condicion: bool, nombre: String) -> void:
	if condicion:
		print("OK   %s" % nombre)
	else:
		_fallos += 1
		push_error("FALLO  %s" % nombre)