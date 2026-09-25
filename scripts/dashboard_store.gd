extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const ColaEscaneoScript := preload("res://scripts/cola_escaneo.gd")


static func agregar_datos(entradas: Array, estados: Dictionary) -> Dictionary:
	return {
		"resumen": resumen(entradas, estados),
		"categorias": por_categoria(entradas, estados),
		"hosts": por_host(entradas, estados, 10),
		"serie": serie_diaria(entradas, estados),
	}


static func resumen(entradas: Array, estados: Dictionary) -> Dictionary:
	var total := 0
	var activos := 0
	var rotos := 0
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		total += 1
		var estado: Dictionary = estados.get(GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))), {})
		if estado.get("valido") == true:
			activos += 1
		elif estado.get("valido") == false:
			rotos += 1
	var comprobados := activos + rotos
	var pct := 0.0
	if comprobados > 0:
		pct = 100.0 * float(activos) / float(comprobados)
	return {
		"total": total,
		"activos": activos,
		"rotos": rotos,
		"sin_comprobar": total - comprobados,
		"disponible_pct": pct,
	}


static func por_categoria(entradas: Array, estados: Dictionary) -> Array:
	var grupos := {}
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var cat := GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))
		var grupo: Dictionary = grupos.get(cat, {"categoria": cat, "total": 0, "activos": 0, "rotos": 0})
		_agregar_grupo(grupo, estados, str(entrada.get("url", "")))
		grupos[cat] = grupo
	return _lista_ordenada(grupos, "categoria", false)


static func por_host(entradas: Array, estados: Dictionary, tope := 0) -> Array:
	var grupos := {}
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var host := ColaEscaneoScript.host_de(str(entrada.get("url", "")))
		if host.is_empty():
			continue
		var grupo: Dictionary = grupos.get(host, {"host": host, "total": 0, "activos": 0, "rotos": 0})
		_agregar_grupo(grupo, estados, str(entrada.get("url", "")))
		grupos[host] = grupo
	var lista := _lista_ordenada(grupos, "host", true)
	if tope > 0 and lista.size() > tope:
		lista.resize(tope)
	return lista


static func serie_diaria(entradas: Array, estados: Dictionary) -> Array:
	var fichas := {}
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var estado: Dictionary = estados.get(GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))), {})
		var hist: Variant = estado.get("historial", [])
		if typeof(hist) != TYPE_ARRAY:
			continue
		for marca in hist:
			if typeof(marca) != TYPE_DICTIONARY:
				continue
			var dia := _clave_dia(int(marca.get("fecha", 0)))
			if dia.is_empty():
				continue
			var ficha: Dictionary = fichas.get(dia, {"fecha": dia, "validos": 0, "caidos": 0})
			if marca.get("valido") == true:
				ficha["validos"] += 1
			elif marca.get("valido") == false:
				ficha["caidos"] += 1
			fichas[dia] = ficha
	var lista: Array = []
	for clave in fichas:
		lista.append(fichas[clave])
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["fecha"]) < str(b["fecha"])
	)
	return lista


static func exportar_csv(ruta: String, datos: Dictionary) -> Dictionary:
	var lineas := PackedStringArray(["Seccion;Clave;Comprobados;Activos;Rotos;Disponible"])
	var res: Dictionary = datos.get("resumen", {})
	lineas.append("Resumen;Total;%d;%d;%d;%.1f" % [
		int(res.get("total", 0)),
		int(res.get("activos", 0)),
		int(res.get("rotos", 0)),
		float(res.get("disponible_pct", 0.0)),
	])
	for g in datos.get("categorias", []):
		lineas.append(_fila_grupo("Categoria", g, "categoria"))
	for g in datos.get("hosts", []):
		lineas.append(_fila_grupo("Host", g, "host"))
	for d in datos.get("serie", []):
		var validos := int(d.get("validos", 0))
		var caidos := int(d.get("caidos", 0))
		var pct := 0.0
		if validos + caidos > 0:
			pct = 100.0 * float(validos) / float(validos + caidos)
		lineas.append("Serie;%s;%d;%d;%d;%.1f" % [
			_escape_csv(str(d.get("fecha", ""))),
			validos + caidos,
			validos,
			caidos,
			pct,
		])
	return _escribir(ruta, "\n".join(lineas) + "\n", lineas.size() - 1)


static func exportar_json(ruta: String, datos: Dictionary) -> Dictionary:
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	if fichero == null:
		return {"ok": false, "total": 0}
	fichero.store_string(JSON.stringify(datos, "\t"))
	return {"ok": true, "total": 1 + int(datos.get("categorias", []).size()) + int(datos.get("hosts", []).size()) + int(datos.get("serie", []).size())}


static func _lista_ordenada(grupos: Dictionary, clave_nombre: String, por_rotos: bool) -> Array:
	var lista: Array = []
	for clave in grupos:
		lista.append(grupos[clave])
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var k := "rotos" if por_rotos else "total"
		if int(a[k]) == int(b[k]):
			if int(a["total"]) == int(b["total"]):
				return str(a[clave_nombre]) < str(b[clave_nombre])
			return int(a["total"]) > int(b["total"])
		return int(a[k]) > int(b[k])
	)
	for g in lista:
		g["disponible_pct"] = _porcentaje(int(g.get("activos", 0)), int(g.get("activos", 0)) + int(g.get("rotos", 0)))
	return lista


static func _agregar_grupo(grupo: Dictionary, estados: Dictionary, url: String) -> void:
	grupo["total"] += 1
	var estado: Dictionary = estados.get(GestorCatalogoScript.clave_unica(url), {})
	if estado.get("valido") == true:
		grupo["activos"] += 1
	elif estado.get("valido") == false:
		grupo["rotos"] += 1


static func _porcentaje(activos: int, comprobados: int) -> float:
	if comprobados <= 0:
		return 0.0
	return 100.0 * float(activos) / float(comprobados)


static func _clave_dia(unix: int) -> String:
	if unix <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func _fila_grupo(seccion: String, g: Dictionary, clave: String) -> String:
	var activos := int(g.get("activos", 0))
	var rotos := int(g.get("rotos", 0))
	return "%s;%s;%d;%d;%d;%.1f" % [
		seccion,
		_escape_csv(str(g.get(clave, ""))),
		activos + rotos,
		activos,
		rotos,
		float(g.get("disponible_pct", 0.0)),
	]


static func _escape_csv(texto: String) -> String:
	return texto.replace(";", ",")


static func _escribir(ruta: String, contenido: String, filas: int) -> Dictionary:
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	if fichero == null:
		return {"ok": false, "total": 0}
	fichero.store_string(contenido)
	if fichero.get_position() == 0:
		return {"ok": false, "total": 0}
	return {"ok": true, "total": filas}