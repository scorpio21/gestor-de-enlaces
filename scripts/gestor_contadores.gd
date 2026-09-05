extends RefCounted


static func contar(entradas: Array, estados: Dictionary) -> Dictionary:
	var total := 0
	var activos := 0
	var rotos := 0
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		total += 1
		var estado: Dictionary = estados.get(str(entrada.get("url", "")), {})
		if estado.get("valido") == true:
			activos += 1
		elif estado.get("valido") == false:
			rotos += 1
	return {"total": total, "activos": activos, "rotos": rotos}
