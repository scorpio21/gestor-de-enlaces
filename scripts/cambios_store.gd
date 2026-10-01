extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const ListItemScript := preload("res://scripts/list_item.gd")

const TIPO_NUEVO_CAIDO := "nuevo_caido"
const TIPO_RECUPERADO := "recuperado"
const TIPO_REUBICADO := "reubicado"
const TIPO_SIN_CAMBIOS := "sin_cambios"

const TIPOS := [TIPO_NUEVO_CAIDO, TIPO_RECUPERADO, TIPO_REUBICADO, TIPO_SIN_CAMBIOS]

const CABECERA_CSV := "fecha,nombre,tipo,antes,despues,mensaje,url"


static func _clave(url: String) -> String:
	var clave := GestorCatalogoScript.clave_unica(url)
	return url if clave.is_empty() else clave


static func _estado_igual(a: Dictionary, b: Dictionary) -> bool:
	return a.get("valido") == b.get("valido") \
		and a.get("mensaje") == b.get("mensaje") \
		and a.get("codigo") == b.get("codigo")


static func _indices(estados: Dictionary) -> Dictionary:
	var por_clave: Dictionary = {}
	for url in estados.keys():
		var valor: Variant = estados[url]
		if typeof(valor) != TYPE_DICTIONARY:
			continue
		var clave := _clave(str(url))
		if por_clave.has(clave):
			continue
		var estado: Dictionary = valor.duplicate()
		estado["url"] = estado.get("url", url)
		por_clave[clave] = estado
	return por_clave


static func delta(antes: Dictionary, despues: Dictionary) -> Array:
	var por_antes := _indices(antes)
	var por_despues := _indices(despues)
	var conjunto: Dictionary = {}
	for clave in por_antes.keys():
		conjunto[clave] = true
	for clave in por_despues.keys():
		conjunto[clave] = true
	var claves: Array = conjunto.keys()
	claves.sort()

	var cambios: Array = []
	for clave in claves:
		var estado_antes: Dictionary = por_antes.get(clave, {})
		var estado_despues: Dictionary = por_despues.get(clave, {})
		cambios.append(_cambio(clave, estado_antes, estado_despues))
	return cambios


static func _cambio(clave: String, antes: Dictionary, despues: Dictionary) -> Dictionary:
	var hay_antes := not antes.is_empty()
	var hay_despues := not despues.is_empty()
	var tipo := TIPO_SIN_CAMBIOS

	if hay_antes and hay_despues and not _estado_igual(antes, despues):
		var caido_antes: bool = antes.get("valido") == false
		var caido_despues: bool = despues.get("valido") == false
		if caido_despues and not caido_antes:
			tipo = TIPO_NUEVO_CAIDO
		elif caido_antes and despues.get("valido") == true:
			tipo = TIPO_RECUPERADO
		else:
			tipo = TIPO_REUBICADO
	elif hay_despues and not hay_antes and despues.get("valido") == false:
		tipo = TIPO_NUEVO_CAIDO

	var url_ant := str(antes.get("url", "")) if hay_antes else ""
	var url_nue := str(despues.get("url", "")) if hay_despues else ""
	var url := url_nue if not url_nue.is_empty() else url_ant
	return {
		"tipo": tipo,
		"clave": clave,
		"url": url if not url.is_empty() else clave,
		"url_ant": url_ant if not url_ant.is_empty() else url,
		"url_nue": url_nue if not url_nue.is_empty() else url,
		"fecha": int(despues.get("fecha", 0)) if hay_despues else int(antes.get("fecha", 0)),
		"valido_ant": antes.get("valido"),
		"mensaje_ant": str(antes.get("mensaje", "")),
		"codigo_ant": int(antes.get("codigo", 0)),
		"valido_nue": despues.get("valido"),
		"mensaje_nue": str(despues.get("mensaje", "")),
		"codigo_nue": int(despues.get("codigo", 0)),
		"tenia_antes": hay_antes,
		"tiene_despues": hay_despues,
	}


static func cambios_de(delta_completo: Array) -> Array:
	var cambios: Array = []
	for cambio in delta_completo:
		if typeof(cambio) == TYPE_DICTIONARY and cambio.get("tipo") != TIPO_SIN_CAMBIOS:
			cambios.append(cambio)
	return cambios


static func resumen(delta_completo: Array) -> Dictionary:
	var cuenta := {}
	for tipo in TIPOS:
		cuenta[tipo] = 0
	for cambio in delta_completo:
		if typeof(cambio) != TYPE_DICTIONARY:
			continue
		var tipo := str(cambio.get("tipo", TIPO_SIN_CAMBIOS))
		if cuenta.has(tipo):
			cuenta[tipo] = int(cuenta[tipo]) + 1
	return cuenta


static func cobertura(estados: Dictionary) -> int:
	var primera := 0
	for url in estados.keys():
		var estado: Variant = estados[url]
		if typeof(estado) != TYPE_DICTIONARY:
			continue
		var historial: Variant = (estado as Dictionary).get("historial", [])
		if typeof(historial) != TYPE_ARRAY or (historial as Array).is_empty():
			continue
		for entrada in historial as Array:
			if typeof(entrada) != TYPE_DICTIONARY:
				continue
			var fecha := int((entrada as Dictionary).get("fecha", 0))
			if fecha <= 0:
				continue
			if primera == 0 or fecha < primera:
				primera = fecha
	return primera


static func exportar_csv(ruta: String, cambios: Array, nombres: Dictionary) -> Dictionary:
	var file := FileAccess.open(ruta, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "motivo": FileAccess.get_open_error()}
	file.store_line(CABECERA_CSV)
	for cambio in cambios:
		if typeof(cambio) != TYPE_DICTIONARY:
			continue
		file.store_line(_linea_csv(cambio, nombres))
	file.close()
	return {"ok": true}


static func _linea_csv(cambio: Dictionary, nombres: Dictionary) -> String:
	var celdas := [
		ListItemScript.formatear_fecha(int(cambio.get("fecha", 0))),
		str(nombres.get(str(cambio.get("clave", "")), "")),
		str(cambio.get("tipo", "")),
		_texto_estado(cambio.get("valido_ant")),
		_texto_estado(cambio.get("valido_nue")),
		str(cambio.get("mensaje_nue", "")),
		str(cambio.get("url", "")),
	]
	var campos: Array = []
	for celda in celdas:
		campos.append(_escapar(str(celda)))
	return ",".join(campos)


static func _escapar(texto: String) -> String:
	return '"%s"' % texto.replace('"', '""')


static func _texto_estado(valido: Variant) -> String:
	if valido == true:
		return "valido"
	if valido == false:
		return "caido"
	return "sin_comprobar"