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


static func normalizar_url(url: String) -> String:
	var uri := url.strip_edges()
	var pos := uri.find("://")
	if pos == -1:
		return uri
	var esquema := uri.substr(0, pos).to_lower()
	if esquema != "http" and esquema != "https":
		return uri
	var resto := uri.substr(pos + 3)
	if resto.is_empty():
		return uri
	var hash := resto.find("#")
	if hash != -1:
		resto = resto.substr(0, hash)
	var host := resto
	var path := ""
	var barra := resto.find("/")
	if barra != -1:
		host = resto.substr(0, barra)
		path = resto.substr(barra)
	host = host.to_lower()
	if host.is_empty():
		return uri
	var dos := host.rfind(":")
	if dos != -1 and not host.begins_with("["):
		var puerto := host.substr(dos + 1)
		var por_defecto := (esquema == "http" and puerto == "80") or (esquema == "https" and puerto == "443")
		if por_defecto:
			host = host.substr(0, dos)
	if path == "/":
		path = ""
	return "%s://%s%s" % [esquema, host, path]


static func clave_unica(url: String) -> String:
	var normal := normalizar_url(url)
	var pos := normal.find("://")
	if pos == -1:
		return normal
	return normal.substr(pos + 3)


static func separar(urls: Array, existentes: Array) -> Dictionary:
	var vistos := {}
	for u in existentes:
		if typeof(u) == TYPE_STRING:
			var c: String = normalizar_url(u)
			if not c.is_empty():
				vistos[clave_unica(c)] = true
	var nuevas: Array = []
	var repetidas: Array = []
	for u in urls:
		var nu: String = normalizar_url(u) if typeof(u) == TYPE_STRING else ""
		if nu.is_empty():
			continue
		if vistos.has(clave_unica(nu)):
			repetidas.append(nu)
		else:
			vistos[clave_unica(nu)] = true
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