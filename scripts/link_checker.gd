extends Node

signal terminado(valido: bool, mensaje: String)

var timeout_s: float = 10.0
const MAX_REDIRECTS := 6
const MARCAS_MUERTO: PackedStringArray = [
	"file not found",
	"has been deleted",
	"no longer available",
	"the file has been removed",
	"this file is no longer",
	"link you have requested is not valid",
	"the file you are looking for is no longer",
	"page not found",
]

var _cliente := HTTPClient.new()
var _url := ""
var _transcurrido := 0.0
var _redirects := 0
var _pedido_enviado := false
var _activo := false


func comprobar(url: String) -> void:
	_url = url.strip_edges()
	_transcurrido = 0.0
	_redirects = 0
	_pedido_enviado = false
	_activo = true
	set_process(true)
	_conectar(_url)


func _process(delta: float) -> void:
	if not _activo:
		return

	_transcurrido += delta
	if _transcurrido >= timeout_s:
		_cerrar("Sin respuesta (tiempo agotado)", false)
		return

	_cliente.poll()
	match _cliente.get_status():
		HTTPClient.STATUS_DISCONNECTED:
			if _pedido_enviado:
				_cerrar("Conexión cerrada", false)
		HTTPClient.STATUS_CANT_RESOLVE:
			_cerrar("No existe el dominio", false)
		HTTPClient.STATUS_CANT_CONNECT:
			_cerrar("No se pudo conectar", false)
		HTTPClient.STATUS_CONNECTION_ERROR:
			_cerrar("Error de conexión", false)
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_cerrar("Error TLS/HTTPS", false)
		HTTPClient.STATUS_CONNECTED:
			if not _pedido_enviado:
				_enviar_pedido()
		HTTPClient.STATUS_BODY:
			_leer_respuesta()


func _conectar(url: String) -> void:
	var partes := _parsear_url(url)
	if partes.is_empty():
		_cerrar("URL inválida", false)
		return

	_cliente.close()
	_pedido_enviado = false
	var tls: TLSOptions = TLSOptions.client() if partes.tls else null
	var err := _cliente.connect_to_host(partes.host, partes.port, tls)
	if err != OK:
		_cerrar("No se pudo iniciar la conexión", false)


func _enviar_pedido() -> void:
	var partes := _parsear_url(_url)
	if partes.is_empty():
		_cerrar("URL inválida", false)
		return

	var err := _cliente.request(
		HTTPClient.METHOD_GET,
		partes.path,
		PackedStringArray([
			"User-Agent: Mozilla/5.0 (compatible; GestorAO/1.0)",
			"Accept: text/html,*/*",
		])
	)
	if err != OK:
		_cerrar("No se pudo enviar la petición", false)
		return
	_pedido_enviado = true


func _leer_respuesta() -> void:
	var codigo := _cliente.get_response_code()
	if codigo in [301, 302, 303, 307, 308]:
		var destino := _cabecera("Location")
		if destino.is_empty() or _redirects >= MAX_REDIRECTS:
			_cerrar("Redirección inválida (%d)" % codigo, false)
			return
		_redirects += 1
		_url = _resolver_redirect(_url, destino)
		_transcurrido = 0.0
		_conectar(_url)
		return

	var fragmento := _cliente.read_response_body_chunk().get_string_from_utf8().to_lower()
	if _parece_muerto(codigo, fragmento):
		_cerrar("No existe (%d)" % codigo, false)
		return

	if codigo >= 200 and codigo < 400:
		_cerrar("OK (%d)" % codigo, true)
		return
	if codigo == 401 or codigo == 403:
		_cerrar("Existe, acceso restringido (%d)" % codigo, true)
		return
	if codigo == 404 or codigo == 410:
		_cerrar("No existe (%d)" % codigo, false)
		return

	_cerrar("Error HTTP %d" % codigo, false)


func _parece_muerto(codigo: int, html: String) -> bool:
	if codigo == 404 or codigo == 410:
		return true
	if html.is_empty():
		return false
	for marca in MARCAS_MUERTO:
		if marca in html:
			return true
	return false


func _cabecera(nombre: String) -> String:
	for linea in _cliente.get_response_headers():
		var sep := linea.find(":")
		if sep == -1:
			continue
		if linea.substr(0, sep).strip_edges().to_lower() == nombre.to_lower():
			return linea.substr(sep + 1).strip_edges()
	return ""


func _resolver_redirect(actual: String, destino: String) -> String:
	if destino.begins_with("http://") or destino.begins_with("https://"):
		return destino
	var partes := _parsear_url(actual)
	if partes.is_empty():
		return destino
	var esquema := "https" if partes.tls else "http"
	if destino.begins_with("/"):
		return "%s://%s:%d%s" % [esquema, partes.host, partes.port, destino]
	return "%s://%s:%d%s" % [esquema, partes.host, partes.port, destino]


func _parsear_url(url: String) -> Dictionary:
	var uri := url.strip_edges()
	var tls := uri.begins_with("https://")
	if not tls and not uri.begins_with("http://"):
		return {}

	var resto := uri.substr(8 if tls else 7)
	var corte := resto.find("/")
	var hostpuerto := resto if corte == -1 else resto.substr(0, corte)
	var path := "/" if corte == -1 else resto.substr(corte)
	if path.is_empty():
		path = "/"

	var host := hostpuerto
	var puerto := 443 if tls else 80
	var colon := hostpuerto.rfind(":")
	if colon != -1 and not hostpuerto.begins_with("["):
		host = hostpuerto.substr(0, colon)
		puerto = int(hostpuerto.substr(colon + 1))

	return {host = host, port = puerto, path = path, tls = tls}


func _cerrar(mensaje: String, valido: bool) -> void:
	if not _activo:
		return
	_activo = false
	set_process(false)
	_cliente.close()
	terminado.emit(valido, mensaje)
	queue_free()
