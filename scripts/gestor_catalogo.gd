extends RefCounted


static func dominio(url: String) -> String:
	var sin_esquema := url.strip_edges()
	if "://" in sin_esquema:
		sin_esquema = sin_esquema.get_slice("://", 1)
	var host := sin_esquema.get_slice("/", 0)
	host = host.get_slice("?", 0)
	host = host.get_slice("#", 0)
	if host.begins_with("www."):
		host = host.substr(4)
	return host


static func separar(urls: Array, existentes: Array) -> Dictionary:
	var vistos := {}
	for u in existentes:
		if typeof(u) == TYPE_STRING:
			vistos[u.strip_edges()] = true
	var nuevas: Array = []
	var repetidas: Array = []
	for u in urls:
		var nu: String = u.strip_edges() if typeof(u) == TYPE_STRING else ""
		if nu.is_empty():
			continue
		if vistos.has(nu):
			repetidas.append(nu)
		else:
			vistos[nu] = true
			nuevas.append(nu)
	return {"nuevas": nuevas, "repetidas": repetidas}


const CATEGORIAS := ["otro", "cliente", "servidor", "codigos", "parche"]


static func normalizar_categoria(valor: Variant) -> String:
	var texto: String = String(valor).strip_edges().to_lower()
	var limpio: String = texto.replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n")
	var equivalencias := {
		"otro": "otro",
		"cliente": "cliente",
		"servidor": "servidor",
		"codigos": "codigos",
		"codigo fuente": "codigos",
		"codigos fuente": "codigos",
		"parche": "parche",
		"patch": "parche",
	}
	return equivalencias.get(limpio, "otro")


static func categoria_display(cat: String) -> String:
	var etiquetas := {
		"otro": "Otro",
		"cliente": "Cliente",
		"servidor": "Servidor",
		"codigos": "Códigos fuente",
		"parche": "Parche",
	}
	return etiquetas.get(normalizar_categoria(cat), "Otro")