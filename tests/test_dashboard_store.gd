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
	_rango(entradas, estados)
	_top(entradas, estados)
	_reubicados(entradas, estados)
	_instantaneas(entradas, estados)
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

	var con_red: Dictionary = DashboardStoreScript.resumen([{"url": "https://mediafire.com/a"}], {
		"mediafire.com/a": {"valido": null, "mensaje": "Sin respuesta", "intentos": 3, "motivo": "red"},
	})
	_check(int(con_red.get("rotos")) == 0, "un enlace con fallo de red no cuenta como caído en el dashboard (#54)")
	_check(int(con_red.get("activos")) == 0, "un enlace con fallo de red tampoco cuenta como válido (#54)")
	_check(int(con_red.get("sin_comprobar")) == 1, "un enlace con fallo de red cuenta como sin comprobar (#54)")

	var con_tls: Dictionary = DashboardStoreScript.resumen([{"url": "https://antiguo.hosting/a"}], {
		"antiguo.hosting/a": {"valido": true, "mensaje": "OK (200)", "intentos": 1, "motivo": "tls"},
	})
	_check(int(con_tls.get("activos")) == 1, "un certificado aceptado por preferencia cuenta como disponible (#56)")
	_check(int(con_tls.get("rotos")) == 0 and int(con_tls.get("sin_comprobar")) == 0, "un certificado aceptado no infla los caidos ni los sin comprobar (#56)")
	_check(is_equal_approx(float(con_tls.get("disponible_pct")), 100.0), "un certificado aceptado mantiene el 100 % de disponibilidad (#56)")


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


func _rango(entradas: Array, estados: Dictionary) -> void:
	var hoy := Time.get_unix_time_from_system()
	var recientes: Array = []
	var estados_recientes := {}
	for i in range(3):
		var clave := "sitio%d.test/pagina" % i
		recientes.append({"nombre": "Reciente %d" % i, "url": "https://%s" % clave, "cat": "otro"})
		estados_recientes[clave] = {"valido": i % 2 == 0, "historial": [
			{"fecha": hoy - i * 86400, "valido": i % 2 == 0, "mensaje": "OK", "codigo": 200},
		]}
	var todo: Array = DashboardStoreScript.serie_diaria(recientes, estados_recientes)
	var siete: Array = DashboardStoreScript.serie_diaria(recientes, estados_recientes, 7)
	var uno: Array = DashboardStoreScript.serie_diaria(recientes, estados_recientes, 1)
	_check(todo.size() == 3, "sin rango la serie diaria devuelve todo el histórico")
	_check(siete.size() == 3, "un rango de 7 días cubre las tres comprobaciones")
	_check(uno.size() == 1 and str(uno[0].get("fecha")) == str(todo[2].get("fecha")), "un rango de 1 día deja solo el de hoy")
	var antiguo: Array = DashboardStoreScript.serie_diaria(entradas, estados, 7)
	_check(antiguo.is_empty(), "un rango descarta las comprobaciones antiguas")


func _top(entradas: Array, estados: Dictionary) -> void:
	var top: Array = DashboardStoreScript.top_caidos(entradas, estados)
	_check(top.size() == 2, "top_caidos solo lista los enlaces con alguna caída")
	_check(str(top[0].get("nombre")) == "A" and int(top[0].get("veces")) == 1 and int(top[0].get("codigo")) == 404, "top_caidos ordena por veces de caída y trae el último código")
	_check(str(top[0].get("host")) == "mediafire.com" and str(top[0].get("categoria")) == "cliente", "top_caidos trae host y categoría del enlace")
	_check(str(top[0].get("mensaje")) == "No", "top_caidos trae el último mensaje de error")
	var ninguno: Array = DashboardStoreScript.top_caidos([{"nombre": "X", "url": "https://x.test/a"}], {})
	_check(ninguno.is_empty(), "sin historial no hay enlaces problemáticos")
	_check(DashboardStoreScript.ultima_comprobacion(estados) == Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 9, "day": 2, "hour": 10}), "ultima_comprobacion devuelve la marca más reciente")
	_check(DashboardStoreScript.ultima_comprobacion({}) == 0, "sin historial no hay última comprobación")


func _reubicados(entradas: Array, estados: Dictionary) -> void:
	var con_destino := estados.duplicate(true)
	con_destino["mediafire.com/a"] = {
		"valido": true, "fecha": 100, "url_final": "https://mirror.com/a.zip",
		"historial": [{"fecha": 100, "valido": true, "mensaje": "OK", "codigo": 200}],
	}
	con_destino["mediafire.com/d"] = {
		"valido": true, "fecha": 200, "url_final": "https://mediafire.com/d",
		"historial": [{"fecha": 200, "valido": true, "mensaje": "OK", "codigo": 200}],
	}
	var lista: Array = DashboardStoreScript.agregar_datos(entradas, con_destino).get("reubicados", [])
	_check(lista.size() == 1, "el bloque de reubicados solo lista los destinos que se pueden actualizar")
	_check(str(lista[0].get("nombre")) == "A" and str(lista[0].get("destino")) == "https://mirror.com/a.zip", "reubicados trae nombre y destino")
	_check(DashboardStoreScript.agregar_datos(entradas, estados).get("reubicados", []).is_empty(), "sin url_final no hay reubicados")

	var con_normalizada: Dictionary = estados.duplicate(true)
	con_normalizada["mega.nz/b"] = {"valido": false, "fecha": 5, "url_final": "https://www.mega.nz/b"}
	_check(DashboardStoreScript.agregar_datos(entradas, con_normalizada).get("reubicados", []).is_empty(), "un simple https/www no cuenta como reubicado (#59)")

	_dir_csv(entradas, con_destino)


func _dir_csv(entradas: Array, estados: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	var datos: Dictionary = DashboardStoreScript.agregar_datos(entradas, estados)
	var ruta := BASE + "/reubicados.csv"
	_check(DashboardStoreScript.exportar_csv(ruta, datos).get("ok") == true, "exportar_csv escribe también con reubicados")
	var contenido := FileAccess.get_file_as_string(ruta)
	_check(contenido.contains("Reubicado;A;https://mirror.com/a.zip;100"), "el CSV incluye el bloque de reubicados (#59)")
	DirAccess.remove_absolute(BASE)


func _instantaneas(entradas: Array, estados: Dictionary) -> void:
	var sin_fotos: Array = DashboardStoreScript.serie_diaria(entradas, estados)
	_check(not bool(sin_fotos[0].get("instantanea", true)), "sin instantáneas ninguna fila se marca como foto (#60)")
	_check(not bool(sin_fotos[0].get("sin_datos", true)), "sin instantáneas no se marcan días sin datos (#60)")
	_check(int(sin_fotos[0].get("total", -1)) == 0 and int(sin_fotos[0].get("sin_comprobar", -1)) == 0, "sin instantáneas el total y el sin comprobar siguen a cero (#60)")

	var fotos := [
		{"fecha": "2026-09-01", "total": 4, "validos": 2, "caidos": 1, "sin_comprobar": 1},
		{"fecha": "2026-09-03", "total": 4, "validos": 3, "caidos": 1, "sin_comprobar": 0},
	]
	var serie: Array = DashboardStoreScript.serie_diaria(entradas, estados, 0, fotos)
	_check(serie.size() == 3, "con instantáneas la serie une fotos y cambios de estado (#60)")
	_check(bool(serie[0].get("instantanea")) and int(serie[0].get("total")) == 4, "la foto del día 1 aporta el total del catálogo (#60)")
	_check(int(serie[0].get("validos")) == 2 and int(serie[0].get("sin_comprobar")) == 1, "la foto manda en válidos y sin comprobar (#60)")
	_check(int(serie[1].get("cambios_validos")) == 2 and int(serie[1].get("cambios_caidos")) == 0, "el día sin foto sigue contando los cambios del historial (#60)")
	_check(bool(serie[1].get("sin_datos")) and not bool(serie[1].get("instantanea")), "un día intermedio sin foto se marca como sin datos (#60)")
	_check(int(serie[1].get("validos")) == 2 and int(serie[1].get("total")) == 0, "un día sin foto no inventa un total de catálogo (#60)")
	_check(bool(serie[2].get("con_delta")) and int(serie[2].get("delta_validos")) == 1, "el delta se mide contra la foto anterior, saltando el día sin foto (#60)")
	_check(not bool(serie[0].get("con_delta")) and not bool(serie[1].get("con_delta")), "sin foto anterior no hay delta (#60)")

	var sin_historial: Array = DashboardStoreScript.serie_diaria(entradas, {}, 0, fotos)
	_check(sin_historial.size() == 2, "sin historial la serie sale solo de las fotos (#60)")
	_check(not bool(sin_historial[1].get("sin_datos")), "sin historial no se puede decir que falte un día (#60)")

	var roto: Array = DashboardStoreScript.serie_diaria(entradas, estados, 0, ["basura", 7, {"total": 4}, {"fecha": "ayer"}])
	_check(roto.size() == 2 and not bool(roto[0].get("instantanea")), "unas instantáneas corruptas no rompen la serie (#60)")
	_check(DashboardStoreScript.cuenta_instantaneas(fotos) == 2 and DashboardStoreScript.cuenta_instantaneas(["basura", 7]) == 0, "cuenta_instantaneas solo cuenta filas con fecha (#60)")
	_check(int(DashboardStoreScript.agregar_datos(entradas, estados, 0, fotos).get("instantaneas", 0)) == 2, "agregar_datos cuenta las instantáneas (#60)")
	_check(int(DashboardStoreScript.agregar_datos(entradas, estados).get("instantaneas", -1)) == 0, "sin instantáneas el bloque cuenta cero (#60)")


func _exportacion(entradas: Array, estados: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	var datos: Dictionary = DashboardStoreScript.agregar_datos(entradas, estados)
	_check(datos.has("resumen") and datos.has("categorias") and datos.has("hosts") and datos.has("serie"), "agregar_datos empaqueta los cuatro bloques")
	_check(datos.has("top") and datos.has("ultima") and int(datos.get("dias")) == 0, "agregar_datos añade los enlaces problemáticos, la última comprobación y el rango")
	var ruta_csv := BASE + "/estadisticas.csv"
	var csv: Dictionary = DashboardStoreScript.exportar_csv(ruta_csv, datos)
	_check(csv.get("ok") == true and int(csv.get("total")) == 1 + 3 + 2 + 2 + 2, "exportar_csv escribe el bloque completo")
	var contenido := FileAccess.get_file_as_string(ruta_csv)
	_check(contenido.contains("Seccion;Clave;Comprobados;Activos;Rotos;Disponible"), "el CSV incluye la cabecera")
	_check(contenido.contains("Resumen;Total;4;2;1;66.7"), "el CSV incluye el resumen con porcentaje")
	_check(contenido.contains("Categoria;cliente;2;1;1;50.0"), "el CSV incluye una categoría formateada")
	_check(contenido.contains("Host;mega.nz;1;0;1;0.0"), "el CSV incluye un host formateado")
	_check(contenido.contains("Serie;2026-09-01;3;1;2;33.3"), "el CSV incluye la serie diaria")
	_check(contenido.contains("Seccion;Clave;Comprobados;Activos;Rotos;Disponible;Total;SinComprobar;Foto"), "la cabecera del CSV avisa de las columnas nuevas (#60)")
	_check(contenido.contains("Serie;2026-09-01;3;1;2;33.3;0;0;no"), "sin instantáneas la fila de la serie dice Foto=no (#60)")
	var con_fotos: Dictionary = DashboardStoreScript.agregar_datos(entradas, estados, 0, [
		{"fecha": "2026-09-01", "total": 4, "validos": 2, "caidos": 1, "sin_comprobar": 1},
	])
	var ruta_fotos := BASE + "/estadisticas_fotos.csv"
	DashboardStoreScript.exportar_csv(ruta_fotos, con_fotos)
	var contenido_fotos := FileAccess.get_file_as_string(ruta_fotos)
	_check(contenido_fotos.contains("Serie;2026-09-01;3;2;1;66.7;4;1;si"), "con instantáneas la fila de la serie sale de la foto (#60)")
	_check(contenido.contains("Caidos;A;404;1;"), "el CSV incluye los enlaces problemáticos con su código y veces")
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