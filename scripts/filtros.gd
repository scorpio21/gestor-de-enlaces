extends RefCounted

const EtiquetasScript := preload("res://scripts/etiquetas.gd")


static func filtrar(entradas: Array, texto: String, modo := "and") -> Array:
	var filtro := texto.strip_edges().to_lower()
	if filtro.is_empty():
		return entradas
	var filtradas: Array = []
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		if coincide_busqueda(entrada, filtro, modo):
			filtradas.append(entrada)
	return filtradas


static func coincide_busqueda(entrada: Dictionary, filtro: String, modo := "and") -> bool:
	var haystack := ("%s %s %s" % [
		entrada.get("nombre", ""),
		entrada.get("desc", ""),
		entrada.get("url", ""),
	]).to_lower()
	var terminos := filtro.to_lower().split(" ", false)
	if modo == "or":
		for termino in terminos:
			if termino in haystack:
				return true
		return false
	for termino in terminos:
		if not termino in haystack:
			return false
	return true


static func fila_visible(valido, categoria: String, modo: int, cat_id: int, clave_cat: String, tags: Array = [], clave_tag: String = "", codigo := 0, clave_codigo := "", fecha := 0, fecha_minima := 0) -> bool:
	var visible_estado := true
	match modo:
		1:
			visible_estado = valido == true
		2:
			visible_estado = valido == false
		3:
			visible_estado = valido == null
	var coincide_tag := clave_tag.is_empty() or EtiquetasScript.coincide(tags, [clave_tag])
	var coincide_codigo := clave_codigo.is_empty() or codigo == int(clave_codigo)
	var en_fecha := fecha_minima <= 0 or fecha >= fecha_minima
	return visible_estado and (cat_id == 0 or categoria == clave_cat) and coincide_tag and coincide_codigo and en_fecha


static func fecha_desde_dias(dias: int, ahora := 0) -> int:
	if dias <= 0:
		return 0
	if ahora <= 0:
		ahora = int(Time.get_unix_time_from_system())
	return ahora - int(dias) * 86400