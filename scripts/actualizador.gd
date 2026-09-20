extends Node

signal terminado(resultado: Dictionary)

const VersionesScript := preload("res://scripts/versiones.gd")
const URL_API := "https://api.github.com/repos/scorpio21/gestor-de-enlaces/releases/latest"
const TIMEOUT := 8.0
const USER_AGENT := "GestorAO/1.0 (comprobacion de versión)"

var _cliente := HTTPClient.new()
var _url := ""
var _transcurrido := 0.0
var _activo := false
var _pedido_enviado := false
var _codigo := 0
var _cuerpo := PackedByteArray()
var _longitud_esperada := 0


func comprobar() -> void:
	if _activo:
		return
	_activo = true
	_url = URL_API
	_transcurrido = 0.0
	_pedido_enviado = false
	_cuerpo = PackedByteArray()
	_longitud_esperada = 0
	_conectar(_url)


func _process(delta: float) -> void:
	if not _activo:
		return

	_transcurrido += delta
	if _transcurrido >= TIMEOUT:
		_cerrar_error("Tiempo agotado al comprobar actualizaciones.")
		return

	_cliente.poll()
	match _cliente.get_status():
		HTTPClient.STATUS_DISCONNECTED:
			if _pedido_enviado:
				_cerrar_error("Se cerró la conexión al comprobar actualizaciones.")
		HTTPClient.STATUS_CANT_RESOLVE:
			_cerrar_error("No se pudo resolver el dominio.")
		HTTPClient.STATUS_CANT_CONNECT:
			_cerrar_error("No se pudo conectar.")
		HTTPClient.STATUS_CONNECTION_ERROR:
			_cerrar_error("Error de conexión.")
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_cerrar_error("Error TLS/HTTPS.")
		HTTPClient.STATUS_CONNECTED:
			if not _pedido_enviado:
				_enviar_pedido()
		HTTPClient.STATUS_BODY:
			_leer_respuesta()


func _conectar(url: String) -> void:
	var partes := _parsear_url(url)
	if partes.is_empty():
		_cerrar_error("URL inválida al comprobar actualizaciones.")
		return
	_cliente.close()
	_pedido_enviado = false
	var tls: TLSOptions = TLSOptions.client() if partes.tls else null
	var err := _cliente.connect_to_host(partes.host, partes.port, tls)
	if err != OK:
		_cerrar_error("No se pudo iniciar la conexión.")


func _enviar_pedido() -> void:
	var partes := _parsear_url(_url)
	if partes.is_empty():
		_cerrar_error("URL inválida al comprobar actualizaciones.")
		return
	var err := _cliente.request(
		HTTPClient.METHOD_GET,
		partes.path,
		PackedStringArray([
			"User-Agent: %s" % USER_AGENT,
			"Accept: application/vnd.github+json",
		])
	)
	if err != OK:
		_cerrar_error("No se pudo enviar la petición.")
		return
	_pedido_enviado = true


func _leer_respuesta() -> void:
	_codigo = _cliente.get_response_code()
	if _codigo != 200:
		_cerrar_error("Respuesta del servidor: %d" % _codigo)
		return
	if _longitud_esperada == 0:
		_longitud_esperada = _cliente.get_response_body_length()
	while _cliente.get_status() == HTTPClient.STATUS_BODY:
		var trozo := _cliente.read_response_body_chunk()
		if trozo.is_empty():
			break
		_cuerpo.append_array(trozo)
	if _longitud_esperada > 0 and _cuerpo.size() < _longitud_esperada:
		return
	if _cuerpo.is_empty():
		return
	_finalizar()


func _finalizar() -> void:
	var datos := VersionesScript.parsear_release(_cuerpo.get_string_from_utf8())
	if datos.is_empty():
		_cerrar_error("Respuesta inválida al comprobar actualizaciones.")
		return
	var version := str(datos.get("version", ""))
	var url := str(datos.get("url", ""))
	var actual := str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	var nueva := VersionesScript.comparar(version, actual) == 1
	_terminar({"nueva": nueva, "version": version, "url": url, "error": ""})


func _cerrar_error(mensaje: String) -> void:
	_terminar({"nueva": false, "version": "", "url": "", "error": mensaje})


func _terminar(resultado: Dictionary) -> void:
	if not _activo:
		return
	_activo = false
	set_process(false)
	_cliente.close()
	terminado.emit(resultado)
	queue_free()


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