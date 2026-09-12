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