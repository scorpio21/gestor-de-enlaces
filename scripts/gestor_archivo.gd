extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const CAMPOS := ["nombre", "desc", "url", "img", "cat"]


static func exportar(ruta: String, entradas: Array) -> Dictionary:
	var res: Array = []
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var sub := {}
		for campo in CAMPOS:
			sub[campo] = str(entrada.get(campo, ""))
		res.append(sub)

	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return {"ok": false, "error": "No se pudo escribir el archivo."}
	archivo.store_string(JSON.stringify(res, "\t"))
	archivo.close()
	return {"ok": true, "total": res.size()}


static func importar(ruta: String, existentes: Array) -> Dictionary:
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {"ok": false, "error": "El archivo no es un catálogo válido."}
	var parseado: Variant = JSON.parse_string(archivo.get_as_text())
	if typeof(parseado) != TYPE_ARRAY:
		return {"ok": false, "error": "El archivo no es un catálogo válido."}

	var vistos := {}
	for u in existentes:
		if typeof(u) == TYPE_STRING:
			var c: String = GestorCatalogoScript.clave_unica(str(u))
			if not c.is_empty():
				vistos[c] = true

	var entradas: Array = []
	var omitidas := 0
	for item in parseado:
		if typeof(item) != TYPE_DICTIONARY:
			omitidas += 1
			continue
		var url := GestorCatalogoScript.normalizar_url(str(item.get("url", "")))
		if url.is_empty():
			omitidas += 1
			continue
		var clave := GestorCatalogoScript.clave_unica(url)
		if vistos.has(clave):
			omitidas += 1
			continue
		vistos[clave] = true
		var sub := {}
		for campo in CAMPOS:
			sub[campo] = str(item.get(campo, ""))
		sub["url"] = url
		sub["cat"] = GestorCatalogoScript.normalizar_categoria(item.get("cat", "otro"))
		entradas.append(sub)

	return {"ok": true, "entradas": entradas, "omitidas": omitidas}
