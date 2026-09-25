extends RefCounted


static func parsear(valor: Variant) -> Array:
	var crudas: Array = []
	if typeof(valor) == TYPE_ARRAY:
		crudas = valor
	elif typeof(valor) == TYPE_STRING:
		crudas = (valor as String).replace(";", ",").split(",")
	var unicas := {}
	for cruda in crudas:
		var texto: String = str(cruda).strip_edges()
		if not texto.is_empty():
			unicas[texto.to_lower()] = texto
	var lista: Array = unicas.values()
	lista.sort_custom(func(a: String, b: String) -> bool: return a.to_lower() < b.to_lower())
	return lista


static func unir(etiquetas: Array) -> String:
	var textos: Array = []
	for etiqueta in etiquetas:
		var texto := str(etiqueta).strip_edges()
		if not texto.is_empty():
			textos.append(texto)
	return ", ".join(textos)


static func frecuentes(entradas: Array, limite: int) -> Array:
	var conteo := {}
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		for etiqueta in parsear(entrada.get("tags", [])):
			var clave: String = str(etiqueta).to_lower()
			conteo[clave] = int(conteo.get(clave, 0)) + 1
	var ordenadas: Array = conteo.keys()
	ordenadas.sort_custom(func(a: String, b: String) -> bool:
		var na := int(conteo[a])
		var nb := int(conteo[b])
		if na != nb:
			return na > nb
		return a < b
	)
	return ordenadas.slice(0, limite)


static func coincide(etiquetas: Array, seleccion: Array) -> bool:
	if seleccion.is_empty():
		return true
	for seleccionada in seleccion:
		var clave: String = str(seleccionada).to_lower()
		if clave.is_empty():
			continue
		for etiqueta in etiquetas:
			if str(etiqueta).to_lower() == clave:
				return true
	return false