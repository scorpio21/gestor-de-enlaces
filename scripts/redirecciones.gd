extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")

const NINGUNA := ""
const NORMALIZADA := "normalizada"
const REUBICADO := "reubicado"

const PAGINAS_DE_SERVICIO: PackedStringArray = [
	"login",
	"signin",
	"sign-in",
	"signup",
	"sign-up",
	"register",
	"registro",
	"home",
	"index",
	"default",
	"raiz",
	"aviso",
	"anuncio",
	"error",
	"404",
	"maintenance",
	"aviso-de-mantenimiento",
]


static func partes(url: String) -> Dictionary:
	var limpia := url.strip_edges()
	var tls := limpia.begins_with("https://")
	if not tls and not limpia.begins_with("http://"):
		return {}
	var resto := limpia.substr(8 if tls else 7)
	var corte := resto.find("/")
	var hostpuerto := resto if corte == -1 else resto.substr(0, corte)
	var path := "/" if corte == -1 else resto.substr(corte)
	var host := hostpuerto
	var puerto := 443 if tls else 80
	var colon := hostpuerto.rfind(":")
	if colon != -1 and not hostpuerto.begins_with("["):
		host = hostpuerto.substr(0, colon)
		puerto = int(hostpuerto.substr(colon + 1))
	return {"host": host, "port": puerto, "path": path, "tls": tls}


static func sin_www(host: String) -> String:
	return host.substr(4) if host.begins_with("www.") else host


static func _puerto_neutro(parte: Dictionary) -> int:
	var puerto := int(parte.get("port", 0))
	var por_defecto := 443 if bool(parte.get("tls", false)) else 80
	return 0 if puerto == por_defecto else puerto


static func normalizada(original: String, final: String) -> bool:
	if original.is_empty() or final.is_empty() or original == final:
		return false
	var a := partes(original)
	var b := partes(final)
	if a.is_empty() or b.is_empty():
		return false
	if str(a.get("path", "")) != str(b.get("path", "")):
		return false
	if _puerto_neutro(a) != _puerto_neutro(b):
		return false
	return sin_www(str(a.get("host", ""))).to_lower() == sin_www(str(b.get("host", ""))).to_lower()


static func reubicable(original: String, final: String) -> bool:
	if original.is_empty() or final.is_empty() or original == final:
		return false
	if normalizada(original, final):
		return false
	var a := partes(original)
	var b := partes(final)
	if a.is_empty() or b.is_empty():
		return false
	var ruta_a := str(a.get("path", ""))
	var ruta_b := str(b.get("path", ""))
	var base_b := ruta_b.get_file().get_basename().to_lower()
	if base_b in PAGINAS_DE_SERVICIO:
		return false
	var extension_b := ruta_b.get_extension().to_lower()
	if extension_b.is_empty():
		return false
	if extension_b == ruta_a.get_extension().to_lower():
		return true
	var base_a := ruta_a.get_file().get_basename()
	return not base_a.is_empty() and base_a == ruta_b.get_file().get_basename()


static func clasificar(original: String, final: String) -> String:
	if reubicable(original, final):
		return REUBICADO
	if normalizada(original, final):
		return NORMALIZADA
	return NINGUNA


static func explicar(original: String, final: String) -> String:
	match clasificar(original, final):
		REUBICADO:
			return TranslationServer.translate("Redirige a: %s") % final
		NORMALIZADA:
			return TranslationServer.translate("Solo cambia el dominio o el https: %s") % final
	return ""


static func aviso_destino(original: String, final: String) -> String:
	return TranslationServer.translate("Cambiar la URL de %s por %s.") % [original, final]


static func texto_actualizar_uno(nombre: String, original: String, final: String) -> String:
	return TranslationServer.translate("¿Actualizar «%s» a %s?") % [nombre, final]


static func texto_actualizar_varios(n: int) -> String:
	return TranslationServer.translate("¿Actualizar la URL de %d enlaces a la nueva?") % n


static func texto_actualizadas(n: int) -> String:
	if n == 1:
		return TranslationServer.translate("1 URL actualizada")
	return TranslationServer.translate("%d URLs actualizadas") % n


static func destino_de(estados: Dictionary, url: String) -> String:
	var estado: Dictionary = estados.get(GestorCatalogoScript.clave_unica(url), {})
	return str(estado.get("url_final", ""))


static func reubicables_de(urls: Array, estados: Dictionary) -> Array:
	var lista: Array = []
	for url in urls:
		var texto := str(url)
		if reubicable(texto, destino_de(estados, texto)):
			lista.append(texto)
	return lista


static func texto_confirmar(entradas: Array, estados: Dictionary, urls: Array) -> String:
	if urls.size() == 1:
		var url := str(urls[0])
		return texto_actualizar_uno(_nombre_de(entradas, url), url, destino_de(estados, url))
	return texto_actualizar_varios(urls.size())


static func _nombre_de(entradas: Array, url: String) -> String:
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("url", "")) == url:
			return str(entrada.get("nombre", url))
	return url


static func reubicados_de(entradas: Array, estados: Dictionary, tope := 0) -> Array:
	var lista: Array = []
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var url := str(entrada.get("url", ""))
		var estado: Dictionary = estados.get(GestorCatalogoScript.clave_unica(url), {})
		var final := str(estado.get("url_final", ""))
		if not reubicable(url, final):
			continue
		lista.append({
			"nombre": str(entrada.get("nombre", "")),
			"url": url,
			"destino": final,
			"fecha": int(estado.get("fecha", 0)),
		})
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("fecha", 0)) == int(b.get("fecha", 0)):
			return str(a.get("nombre", "")) < str(b.get("nombre", ""))
		return int(a.get("fecha", 0)) > int(b.get("fecha", 0))
	)
	if tope > 0 and lista.size() > tope:
		lista.resize(tope)
	return lista