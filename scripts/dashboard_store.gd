extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const ColaEscaneoScript := preload("res://scripts/cola_escaneo.gd")
const RedireccionesScript := preload("res://scripts/redirecciones.gd")


static func agregar_datos(entradas: Array, estados: Dictionary, dias := 0, instantaneas := []) -> Dictionary:
	return {
		"resumen": resumen(entradas, estados),
		"categorias": por_categoria(entradas, estados),
		"hosts": por_host(entradas, estados, 10),
		"serie": serie_diaria(entradas, estados, dias, instantaneas),
		"top": top_caidos(entradas, estados),
		"reubicados": RedireccionesScript.reubicados_de(entradas, estados),
		"ultima": ultima_comprobacion(estados),
		"instantaneas": cuenta_instantaneas(instantaneas),
		"dias": dias,
	}


static func cuenta_instantaneas(instantaneas: Variant) -> int:
	if typeof(instantaneas) != TYPE_ARRAY:
		return 0
	var cuenta := 0
	for fila in instantaneas:
		if typeof(fila) == TYPE_DICTIONARY and str((fila as Dictionary).get("fecha", "")).length() == 10:
			cuenta += 1
	return cuenta


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


static func serie_diaria(entradas: Array, estados: Dictionary, dias := 0, instantaneas := []) -> Array:
	var desde := _clave_desde(dias)
	var cambios := _cambios_por_dia(entradas, estados, desde)
	var fotos := _fotos_por_dia(instantaneas, desde)
	var hay_foto := not fotos.is_empty()
	var claves := {}
	for dia in cambios:
		claves[dia] = true
	for dia in fotos:
		claves[dia] = true
	var lista: Array = []
	for dia in claves:
		var cambio: Dictionary = cambios.get(dia, {})
		var foto: Dictionary = fotos.get(dia, {})
		var con_foto := not foto.is_empty()
		lista.append({
			"fecha": dia,
			"instantanea": con_foto,
			"sin_datos": hay_foto and not con_foto,
			"total": int(foto.get("total", 0)),
			"validos": int(foto.get("validos", 0)) if con_foto else int(cambio.get("validos", 0)),
			"caidos": int(foto.get("caidos", 0)) if con_foto else int(cambio.get("caidos", 0)),
			"sin_comprobar": int(foto.get("sin_comprobar", 0)),
			"cambios_validos": int(cambio.get("validos", 0)),
			"cambios_caidos": int(cambio.get("caidos", 0)),
			"con_delta": false,
			"delta_validos": 0,
			"delta_caidos": 0,
		})
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["fecha"]) < str(b["fecha"])
	)
	_anadir_deltas(lista)
	return lista


static func _cambios_por_dia(entradas: Array, estados: Dictionary, desde: String) -> Dictionary:
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
			var dia := clave_de_dia(int(marca.get("fecha", 0)))
			if dia.is_empty() or dia < desde:
				continue
			var ficha: Dictionary = fichas.get(dia, {"fecha": dia, "validos": 0, "caidos": 0})
			if marca.get("valido") == true:
				ficha["validos"] += 1
			elif marca.get("valido") == false:
				ficha["caidos"] += 1
			fichas[dia] = ficha
	return fichas


static func _fotos_por_dia(instantaneas: Variant, desde: String) -> Dictionary:
	var fotos := {}
	if typeof(instantaneas) != TYPE_ARRAY:
		return fotos
	for fila in instantaneas:
		if typeof(fila) != TYPE_DICTIONARY:
			continue
		var dato: Dictionary = fila
		var dia := str(dato.get("fecha", ""))
		if dia.length() != 10 or dia < desde:
			continue
		fotos[dia] = dato
	return fotos


static func _anadir_deltas(lista: Array) -> void:
	var previa := {}
	for i in range(lista.size()):
		var actual: Dictionary = lista[i]
		if not bool(actual.get("instantanea", false)):
			continue
		if not previa.is_empty():
			actual["con_delta"] = true
			actual["delta_validos"] = int(actual.get("validos", 0)) - int(previa.get("validos", 0))
			actual["delta_caidos"] = int(actual.get("caidos", 0)) - int(previa.get("caidos", 0))
		previa = actual


static func top_caidos(entradas: Array, estados: Dictionary, tope := 8) -> Array:
	var lista: Array = []
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var estado: Dictionary = estados.get(GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))), {})
		var hist: Variant = estado.get("historial", [])
		if typeof(hist) != TYPE_ARRAY:
			continue
		var veces := 0
		var ultima := {}
		for marca in hist:
			if typeof(marca) != TYPE_DICTIONARY or marca.get("valido") != false:
				continue
			veces += 1
			if int(marca.get("fecha", 0)) >= int(ultima.get("fecha", 0)):
				ultima = marca
		if veces == 0:
			continue
		lista.append({
			"nombre": str(entrada.get("nombre", "")),
			"url": str(entrada.get("url", "")),
			"host": ColaEscaneoScript.host_de(str(entrada.get("url", ""))),
			"categoria": GestorCatalogoScript.normalizar_categoria(entrada.get("cat", "")),
			"veces": veces,
			"codigo": int(ultima.get("codigo", 0)),
			"mensaje": str(ultima.get("mensaje", "")),
			"fecha": int(ultima.get("fecha", 0)),
			"url_final": str(estado.get("url_final", "")),
		})
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["veces"]) == int(b["veces"]):
			if int(a["fecha"]) == int(b["fecha"]):
				return str(a["nombre"]) < str(b["nombre"])
			return int(a["fecha"]) > int(b["fecha"])
		return int(a["veces"]) > int(b["veces"])
	)
	if tope > 0 and lista.size() > tope:
		lista.resize(tope)
	return lista


static func ultima_comprobacion(estados: Dictionary) -> int:
	var ultima := 0
	for clave in estados:
		var estado: Dictionary = estados[clave]
		var hist: Variant = estado.get("historial", [])
		if typeof(hist) != TYPE_ARRAY:
			continue
		for marca in hist:
			if typeof(marca) == TYPE_DICTIONARY:
				ultima = maxi(ultima, int(marca.get("fecha", 0)))
	return ultima


static func exportar_csv(ruta: String, datos: Dictionary) -> Dictionary:
	var lineas := PackedStringArray(["Seccion;Clave;Comprobados;Activos;Rotos;Disponible;Total;SinComprobar;Foto"])
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
	for t in datos.get("top", []):
		lineas.append("Caidos;%s;%d;%d;%d" % [
			_escape_csv(str(t.get("nombre", ""))),
			int(t.get("codigo", 0)),
			int(t.get("veces", 0)),
			int(t.get("fecha", 0)),
		])
	for r in datos.get("reubicados", []):
		lineas.append("Reubicado;%s;%s;%d" % [
			_escape_csv(str(r.get("nombre", ""))),
			_escape_csv(str(r.get("destino", ""))),
			int(r.get("fecha", 0)),
		])
	for d in datos.get("serie", []):
		var validos := int(d.get("validos", 0))
		var caidos := int(d.get("caidos", 0))
		var pct := _porcentaje(validos, validos + caidos)
		lineas.append("Serie;%s;%d;%d;%d;%.1f;%d;%d;%s" % [
			_escape_csv(str(d.get("fecha", ""))),
			validos + caidos,
			validos,
			caidos,
			pct,
			int(d.get("total", 0)),
			int(d.get("sin_comprobar", 0)),
			"si" if bool(d.get("instantanea", false)) else "no",
		])
	return _escribir(ruta, "\n".join(lineas) + "\n", lineas.size() - 1)


static func exportar_json(ruta: String, datos: Dictionary) -> Dictionary:
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	if fichero == null:
		return {"ok": false, "total": 0}
	fichero.store_string(JSON.stringify(datos, "\t"))
	return {"ok": true, "total": 1 + int(datos.get("categorias", []).size()) + int(datos.get("hosts", []).size()) + int(datos.get("serie", []).size()) + int(datos.get("top", []).size()) + int(datos.get("reubicados", []).size())}


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


static func clave_de_dia(unix: int) -> String:
	if unix <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func _clave_dia(unix: int) -> String:
	return clave_de_dia(unix)


static func _clave_desde(dias: int) -> String:
	if dias <= 0:
		return ""
	return _clave_dia(Time.get_unix_time_from_system() - (dias - 1) * 86400)


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