extends SceneTree

const CambiosStoreScript := preload("res://scripts/cambios_store.gd")
const Ayuda := preload("res://tests/ayuda.gd")
const BASE := "user://__test_cambios_store__"

var _fallos := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	_clasificacion()
	_reubicado()
	_nuevos_y_retirados()
	_normalizacion()
	_resumen_y_cambio()
	_cobertura()
	_csv()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _estado(valido: Variant, mensaje := "", codigo := 0, fecha := 1000, url := "") -> Dictionary:
	var e := {"valido": valido, "mensaje": mensaje, "codigo": codigo, "fecha": fecha}
	if not url.is_empty():
		e["url"] = url
	return e


func _tipo_por_clave(cambios: Array, clave: String) -> String:
	for cambio in cambios:
		if cambio.get("clave") == clave:
			return str(cambio.get("tipo", ""))
	return ""


func _clasificacion() -> void:
	var antes := {"a.test": _estado(true, "OK", 200)}
	var despues := {"a.test": _estado(false, "Connection refused", 0, 2000)}
	var cambios: Array = CambiosStoreScript.delta(antes, despues)
	_check(cambios.size() == 1, "delta ve un enlace que cambio")
	_check(str(cambios[0].get("tipo")) == CambiosStoreScript.TIPO_NUEVO_CAIDO, "valido -> caido es nuevo_caido")
	_check(cambios[0].get("valido_ant") == true and cambios[0].get("valido_nue") == false, "delta guarda los dos lados")
	_check(int(cambios[0].get("fecha")) == 2000, "delta toma la fecha del estado nuevo")
	_check(str(cambios[0].get("mensaje_ant")) == "OK", "delta guarda el mensaje anterior")
	_check(str(cambios[0].get("mensaje_nue")) == "Connection refused", "delta guarda el mensaje nuevo")

	cambios = CambiosStoreScript.delta(despues, antes)
	_check(str(cambios[0].get("tipo")) == CambiosStoreScript.TIPO_RECUPERADO, "caido -> valido es recuperado")

	cambios = CambiosStoreScript.delta(antes, {"a.test": _estado(true, "OK", 200)})
	_check(str(cambios[0].get("tipo")) == CambiosStoreScript.TIPO_SIN_CAMBIOS, "sin cambios de estado, mensaje ni codigo es sin_cambios")

	cambios = CambiosStoreScript.delta(antes, {"a.test": _estado(true, "OK", 299, 2000)})
	_check(str(cambios[0].get("tipo")) == CambiosStoreScript.TIPO_REUBICADO, "un codigo HTTP distinto con la misma validez es reubicado")

	cambios = CambiosStoreScript.delta({}, {})
	_check(cambios.is_empty(), "sin estados no hay cambios")
	_check(CambiosStoreScript.delta({}, {}).is_empty(), "delta es puro y se puede llamar dos veces")

	var caido_igual := {"a.test": _estado(false, "Connection refused", 0, 2000)}
	_check(_tipo_por_clave(CambiosStoreScript.delta(caido_igual, caido_igual.duplicate(true)), "a.test") == CambiosStoreScript.TIPO_SIN_CAMBIOS, "un enlace que sigue caido igual no se vuelve a anunciar")
	_check(_tipo_por_clave(CambiosStoreScript.delta({}, {"a.test": _estado(false, "Connection refused", 0, 2000)}), "a.test") == CambiosStoreScript.TIPO_NUEVO_CAIDO, "un enlace nuevo que nace caido si se anuncia")
	_check(_tipo_por_clave(CambiosStoreScript.delta({"a.test": _estado(false, "Connection refused", 0, 2000)}, {}), "a.test") == CambiosStoreScript.TIPO_SIN_CAMBIOS, "un enlace caido que se retira no es un caido nuevo")

	var entrada := {"a.test": _estado(true, "OK", 200, 1)}
	CambiosStoreScript.delta({}, entrada)
	_check(not entrada["a.test"].has("url"), "delta no ensucia el estado que recibe con campos suyos")
	_check(str(entrada["a.test"].get("mensaje", "")) == "OK", "ni toca los datos del estado de entrada")

	var ambos := {
		"a.test": _estado(true),
		"b.test": _estado(true),
		"c.test": _estado(false),
	}
	var despues2 := {
		"a.test": _estado(false, "timeout", 0, 2000),
		"b.test": _estado(true),
		"c.test": _estado(true),
		"d.test": _estado(false, "no route", 0, 2000),
	}
	cambios = CambiosStoreScript.delta(ambos, despues2)
	_check(cambios.size() == 4, "delta no se pierde enlaces de ninguna de las dos partes")
	_check(_tipo_por_clave(cambios, "a.test") == CambiosStoreScript.TIPO_NUEVO_CAIDO, "el primer par es un caido nuevo")
	_check(_tipo_por_clave(cambios, "b.test") == CambiosStoreScript.TIPO_SIN_CAMBIOS, "el que se mantiene igual no es cambio")
	_check(_tipo_por_clave(cambios, "c.test") == CambiosStoreScript.TIPO_RECUPERADO, "el tercer par es recuperado")
	_check(_tipo_por_clave(cambios, "d.test") == CambiosStoreScript.TIPO_NUEVO_CAIDO, "un enlace nuevo caido es nuevo_caido")


func _reubicado() -> void:
	var antes := {"a.test": _estado(true, "OK", 200)}
	var despues := {"a.test": _estado(true, "Moved Permanently", 301, 2000)}
	var cambios: Array = CambiosStoreScript.delta(antes, despues)
	_check(str(cambios[0].get("tipo")) == CambiosStoreScript.TIPO_REUBICADO, "misma validez con otro mensaje es reubicado")

	var caido := {"a.test": _estado(false, "Connection refused", 0)}
	var caido_otro := {"a.test": _estado(false, "Read timeout", 28, 2000)}
	_check(_tipo_por_clave(CambiosStoreScript.delta(caido, caido_otro), "a.test") == CambiosStoreScript.TIPO_REUBICADO, "caido -> caido con otro motivo es reubicado, no nuevo_caido")

	var sin_comprobar := {"a.test": _estado(null, "")}
	_check(_tipo_por_clave(CambiosStoreScript.delta(sin_comprobar, caido), "a.test") == CambiosStoreScript.TIPO_NUEVO_CAIDO, "sin comprobar -> caido es nuevo_caido")
	_check(_tipo_por_clave(CambiosStoreScript.delta(caido, sin_comprobar), "a.test") == CambiosStoreScript.TIPO_REUBICADO, "caido -> sin comprobar es reubicado")
	_check(_tipo_por_clave(CambiosStoreScript.delta(sin_comprobar, {"a.test": _estado(true)}), "a.test") == CambiosStoreScript.TIPO_REUBICADO, "sin comprobar -> valido no es recuperado: no estaba caido")


func _nuevos_y_retirados() -> void:
	var cambios: Array = CambiosStoreScript.delta({}, {"a.test": _estado(true, "OK", 200)})
	_check(str(cambios[0].get("tipo")) == CambiosStoreScript.TIPO_SIN_CAMBIOS, "un enlace nuevo que ya esta bien no se anuncia")
	_check(cambios[0].get("tenia_antes") == false and cambios[0].get("tiene_despues") == true, "delta marca de que lado estaba el enlace")
	_check(str(cambios[0].get("url")) == "a.test", "un enlace nuevo sin campo url usa la clave")

	cambios = CambiosStoreScript.delta({"a.test": _estado(true)}, {})
	_check(str(cambios[0].get("tipo")) == CambiosStoreScript.TIPO_SIN_CAMBIOS, "un enlace retirado del catalogo no es cambio de estado")
	_check(cambios[0].get("tiene_despues") == false, "delta marca que ya no esta")
	_check(str(cambios[0].get("url")) == "a.test", "un enlace retirado conserva su url")


func _normalizacion() -> void:
	var antes := {"https://A.test/ruta": _estado(true, "OK", 200)}
	var despues := {"http://a.test/ruta": _estado(false, "timeout", 0, 2000)}
	var cambios: Array = CambiosStoreScript.delta(antes, despues)
	_check(cambios.size() == 1, "el esquema y las mayusculas no cuentan como enlaces distintos")
	_check(str(cambios[0].get("tipo")) == CambiosStoreScript.TIPO_NUEVO_CAIDO, "comparar por clave canonica mantiene la clasificacion")
	_check(str(cambios[0].get("url_ant")) == "https://A.test/ruta", "delta recuerda la url que habia")
	_check(str(cambios[0].get("url_nue")) == "http://a.test/ruta", "delta recuerda la url que hay")

	cambios = CambiosStoreScript.delta({}, {"a.test": "basura", "b.test": 7})
	_check(cambios.is_empty(), "lo que no es un estado se ignora")
	_check(CambiosStoreScript.delta({}, {}).is_empty(), "un snapshot vacio es un delta vacio")


func _resumen_y_cambio() -> void:
	var antes := {"a.test": _estado(true), "b.test": _estado(false), "c.test": _estado(true, "OK", 200)}
	var despues := {
		"a.test": _estado(false, "x", 0, 2),
		"b.test": _estado(true, "", 200, 2),
		"c.test": _estado(true, "Moved", 301, 2),
	}
	var completo: Array = CambiosStoreScript.delta(antes, despues)
	var reales: Array = CambiosStoreScript.cambios_de(completo)
	_check(reales.size() == 3, "cambios_de quita los que no cambiaron")
	_check(CambiosStoreScript.cambios_de([{"tipo": CambiosStoreScript.TIPO_SIN_CAMBIOS}]).is_empty(), "cambios_de de un delta sin cambios devuelve nada")
	_check(CambiosStoreScript.cambios_de(["basura", 7]).is_empty(), "cambios_de tolera basura en la lista")

	var cuenta: Dictionary = CambiosStoreScript.resumen(completo)
	_check(int(cuenta.get(CambiosStoreScript.TIPO_NUEVO_CAIDO, 0)) == 1, "resumen cuenta los nuevos caidos")
	_check(int(cuenta.get(CambiosStoreScript.TIPO_RECUPERADO, 0)) == 1, "resumen cuenta los recuperados")
	_check(int(cuenta.get(CambiosStoreScript.TIPO_REUBICADO, 0)) == 1, "resumen cuenta los reubicados")
	_check(int(cuenta.get(CambiosStoreScript.TIPO_SIN_CAMBIOS, 0)) == 0, "resumen no cuenta los que no cambiaron")
	_check(int(CambiosStoreScript.resumen([]).get(CambiosStoreScript.TIPO_NUEVO_CAIDO, -1)) == 0, "resumen de una lista vacia son ceros")
	_check(CambiosStoreScript.resumen(["x", {}]).get(CambiosStoreScript.TIPO_RECUPERADO) == 0, "resumen tolera basura en la lista")
	_check(CambiosStoreScript.TIPOS.size() == 4, "hay cuatro tipos de cambio")


func _cobertura() -> void:
	_check(CambiosStoreScript.cobertura({}) == 0, "sin estados no hay cobertura que anunciar")
	_check(CambiosStoreScript.cobertura({"a.test": _estado(true)}) == 0, "un estado sin historial no da cobertura")
	_check(CambiosStoreScript.cobertura({"a.test": {"valido": true, "historial": "basura"}}) == 0, "un historial que no es lista no da cobertura")
	_check(CambiosStoreScript.cobertura({"a.test": {"valido": true, "historial": []}}) == 0, "un historial vacio no da cobertura")
	_check(CambiosStoreScript.cobertura({"a.test": {"valido": true, "historial": [{"fecha": 0}]}}) == 0, "una fecha cero no cuenta como cobertura")

	var estados := {
		"a.test": {"valido": true, "historial": [{"fecha": 5000}, {"fecha": 400}, {"fecha": 9000}]},
		"b.test": {"valido": true, "historial": [{"fecha": 700}, {"fecha": 8000}]},
		"c.test": {"valido": true},
	}
	_check(CambiosStoreScript.cobertura(estados) == 400, "la cobertura es la fecha mas antigua de todo el historial")
	_check(CambiosStoreScript.cobertura(estados) == 400, "la cobertura no depende del estado que se mire")


func _csv() -> void:
	var cambios: Array = CambiosStoreScript.delta(
		{"a.test": _estado(true, "OK", 200, 100)},
		{"a.test": _estado(false, "Connection refused, otra vez", 0, 1700000000)}
	)
	var ruta := "%s/cambios.csv" % BASE
	var resultado: Dictionary = CambiosStoreScript.exportar_csv(ruta, cambios, {"a.test": "Servidor Principal"})
	_check(resultado.get("ok", false), "exportar_csv escribe el fichero")

	var texto := FileAccess.get_file_as_string(ruta)
	var lineas := texto.split("\n")
	_check(lineas.size() >= 2, "el CSV tiene cabecera y al menos una fila")
	_check(str(lineas[0]) == CambiosStoreScript.CABECERA_CSV, "la cabecera del CSV es la esperada")
	_check(lineas[1].contains('"Servidor Principal"'), "el CSV lleva el nombre del enlace")
	_check(lineas[1].contains('"nuevo_caido"'), "el CSV lleva el tipo de cambio")
	_check(lineas[1].contains('"valido"') and lineas[1].contains('"caido"'), "el CSV lleva el estado antes y despues")
	_check(lineas[1].contains('"Connection refused, otra vez"'), "una coma en el mensaje no parte la fila en dos")
	_check(lineas[1].count('"') % 2 == 0, "las comillas del CSV van balanceadas")
	_check(lineas[1].contains('"a.test"'), "el CSV lleva la url cuando el estado no la trae")

	_check(CambiosStoreScript.exportar_csv(ruta, cambios, {}).get("ok", false), "exportar_csv funciona sin nombres")
	_check(not FileAccess.get_file_as_string(ruta).contains("Servidor Principal"), "sin nombres el CSV sale vacio en esa columna")
	_check(CambiosStoreScript.exportar_csv(ruta, [], {}).get("ok", false), "exportar_csv de una lista vacia solo escribe la cabecera")
	_check(FileAccess.get_file_as_string(ruta).strip_edges() == CambiosStoreScript.CABECERA_CSV, "sin cambios el CSV solo tiene cabecera")
	_check(CambiosStoreScript.exportar_csv("%s/no-existe-dir/x.csv" % BASE, cambios, {}).get("ok", true) == false, "exportar_csv avisa si no puede escribir")

	Ayuda.borrar_arbol(BASE)


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)