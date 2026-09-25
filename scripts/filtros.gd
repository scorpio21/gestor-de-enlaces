extends RefCounted

const EtiquetasScript := preload("res://scripts/etiquetas.gd")


static func filtrar(entradas: Array, texto: String) -> Array:
	var filtro := texto.strip_edges().to_lower()
	if filtro.is_empty():
		return entradas
	var filtradas: Array = []
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		if coincide_busqueda(entrada, filtro):
			filtradas.append(entrada)
	return filtradas


static func coincide_busqueda(entrada: Dictionary, filtro: String) -> bool:
	var haystack := "%s %s %s" % [
		entrada.get("nombre", ""),
		entrada.get("desc", ""),
		entrada.get("url", ""),
	]
	return filtro in haystack.to_lower()


static func fila_visible(valido, categoria: String, modo: int, cat_id: int, clave_cat: String, tags: Array = [], clave_tag: String = "") -> bool:
	var visible_estado := true
	match modo:
		1:
			visible_estado = valido == true
		2:
			visible_estado = valido == false
		3:
			visible_estado = valido == null
	var coincide_tag := clave_tag.is_empty() or EtiquetasScript.coincide(tags, [clave_tag])
	return visible_estado and (cat_id == 0 or categoria == clave_cat) and coincide_tag