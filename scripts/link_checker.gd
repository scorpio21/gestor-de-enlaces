extends Node

signal terminado(valido: bool, mensaje: String)

var timeout_s: float = 10.0
var codigo := 0
var intentos := 1
var transitorio := false
var motivo := MOTIVO_OK
var reintentar_transitorios := true
const MAX_RETRY_AFTER := 10.0
const ESPERA_REINTENTOS: PackedFloat32Array = [1.0, 4.0]
const CODIGOS_TRANSITORIOS := [429, 500, 502, 503, 504]
const MOTIVO_OK := "ok"
const MOTIVO_RED := "red"
const MOTIVO_DNS := "dns"
const MOTIVO_TLS := "tls"
const MOTIVO_HTTP := "http"
const MOTIVO_MUERTO := "muerto"
const MOTIVO_URL := "url"
const MESES_HTTP := ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
const MAX_REDIRECTS := 6
const LIMITE_CUERPO := 65536
const ESPERA_CUERPO := 0.4
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
var MARCAS_POR_HOST: Dictionary = {
	"mega.nz": PackedStringArray([
		"this file is no longer available",
		"file not available",
		"no longer available for download",
	]),
	"mediafire.com": PackedStringArray([
		"file cannot be found",
		"has been removed due to inactivity",
		"file has been deleted by the user",
	]),
	"drive.google.com": PackedStringArray([
		"the file you have selected does not exist",
		"the file was deleted",
		"the owner has removed this item",
		"has been removed by the owner",
	]),
	"sites.google.com": PackedStringArray([
		"the requested page could not be found",
	]),
	"dropbox.com": PackedStringArray([
		"file can't be found",
		"there's nothing here",
		"the file or folder has been deleted",
		"link has expired",
	]),
	"wetransfer.com": PackedStringArray([
		"this transfer has expired",
		"link has expired",
		"the transfer link you are looking for is no longer available",
	]),
}

func _marcas_para_host(host: String) -> PackedStringArray:
	for clave in MARCAS_POR_HOST:
		if host.ends_with(String(clave)):
			var marcas := MARCAS_MUERTO.duplicate()
			marcas.append_array(MARCAS_POR_HOST[clave])
			return marcas
	return MARCAS_MUERTO

var _cliente := HTTPClient.new()
var _url := ""
var _transcurrido := 0.0
var _redirects := 0
var _pedido_enviado := false
var _activo := false
var _host_actual := ""
var _cuerpo := ""
var _leidos := 0
var _espera := 0.0
var _reintento_sin_rango := false
var _reintentos := 0
var _espera_reintento := -1.0
var _url_inicial := ""


func comprobar(url: String) -> void:
	_url = url.strip_edges()
	_url_inicial = _url
	_host_actual = str(_parsear_url(_url).get("host", ""))
	_transcurrido = 0.0
	_redirects = 0
	_pedido_enviado = false
	_activo = true
	_reintentos = 0
	_espera_reintento = -1.0
	intentos = 1
	transitorio = false
	motivo = MOTIVO_OK
	set_process(true)
	_conectar(_url)


static func es_transitorio(causa: String, codigo_http := 0) -> bool:
	if causa == MOTIVO_RED or causa == MOTIVO_DNS:
		return true
	if causa == MOTIVO_HTTP:
		return codigo_http in CODIGOS_TRANSITORIOS
	return false


static func espera_reintento(indice: int) -> float:
	if indice < 0 or indice >= ESPERA_REINTENTOS.size():
		return 0.0
	return ESPERA_REINTENTOS[indice]


func _process(delta: float) -> void:
	if not _activo:
		return

	if _espera_reintento >= 0.0:
		_espera_reintento -= delta
		if _espera_reintento <= 0.0:
			_reintentar()
		return

	_transcurrido += delta
	if _transcurrido >= timeout_s:
		_cerrar(tr("Sin respuesta (tiempo agotado)"), false, MOTIVO_RED)
		return

	_cliente.poll()
	match _cliente.get_status():
		HTTPClient.STATUS_CANT_RESOLVE:
			_cerrar(tr("No existe el dominio"), false, MOTIVO_DNS)
		HTTPClient.STATUS_CANT_CONNECT:
			_cerrar(tr("No se pudo conectar"), false, MOTIVO_RED)
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_cerrar(tr("Error TLS/HTTPS"), false, MOTIVO_TLS)
		HTTPClient.STATUS_CONNECTION_ERROR:
			_tras_cuerpo("Error de conexión", MOTIVO_RED)
		HTTPClient.STATUS_DISCONNECTED:
			_tras_cuerpo("Conexión cerrada", MOTIVO_RED)
		HTTPClient.STATUS_CONNECTED:
			if not _pedido_enviado:
				_enviar_pedido()
			else:
				_tras_cuerpo("", MOTIVO_RED)
		HTTPClient.STATUS_REQUESTING:
			_tras_cuerpo("", MOTIVO_RED)
		HTTPClient.STATUS_BODY:
			_leer_respuesta()


func _reintentar() -> void:
	_espera_reintento = -1.0
	_url = _url_inicial
	_host_actual = str(_parsear_url(_url).get("host", ""))
	_transcurrido = 0.0
	_redirects = 0
	_pedido_enviado = false
	_reintento_sin_rango = false
	_conectar(_url)


func _tras_cuerpo(sin_codigo: String, causa := MOTIVO_RED) -> void:
	if not _pedido_enviado:
		return
	_actualizar_codigo()
	if codigo != 0:
		_veredicto(true)
		return
	if not sin_codigo.is_empty():
		_cerrar(tr(sin_codigo), false, causa)


func _actualizar_codigo() -> void:
	if codigo == 0:
		codigo = _cliente.get_response_code()
	if codigo == 206:
		codigo = 200


func _conectar(url: String) -> void:
	var partes := _parsear_url(url)
	if partes.is_empty():
		_cerrar(tr("URL inválida"), false, MOTIVO_URL)
		return

	_cliente.close()
	_pedido_enviado = false
	codigo = 0
	_cuerpo = ""
	_leidos = 0
	_espera = 0.0
	_reintento_sin_rango = false
	motivo = MOTIVO_OK
	var tls: TLSOptions = TLSOptions.client() if partes.tls else null
	var err := _cliente.connect_to_host(partes.host, partes.port, tls)
	if err != OK:
		_cerrar(tr("No se pudo iniciar la conexión"), false, MOTIVO_RED)


func _enviar_pedido() -> void:
	var partes := _parsear_url(_url)
	if partes.is_empty():
		_cerrar(tr("URL inválida"), false, MOTIVO_URL)
		return

	var cabeceras := PackedStringArray([
		"User-Agent: Mozilla/5.0 (compatible; GestorAO/1.0)",
		"Accept: text/html,*/*",
	])
	if not _reintento_sin_rango:
		cabeceras.append("Range: bytes=0-%d" % (LIMITE_CUERPO - 1))
	var err := _cliente.request(HTTPClient.METHOD_GET, partes.path, cabeceras)
	if err != OK:
		_cerrar(tr("No se pudo enviar la petición"), false, MOTIVO_RED)
		return
	_pedido_enviado = true


func _leer_respuesta() -> void:
	_actualizar_codigo()
	if codigo in [301, 302, 303, 307, 308]:
		var destino := _cabecera("Location")
		if destino.is_empty() or _redirects >= MAX_REDIRECTS:
			_cerrar(tr("Redirección inválida (%d)") % codigo, false, MOTIVO_HTTP)
			return
		_redirects += 1
		_url = _resolver_redirect(_url, destino)
		_host_actual = str(_parsear_url(_url).get("host", ""))
		_transcurrido = 0.0
		_conectar(_url)
		return

	if codigo == 416 and not _reintento_sin_rango:
		_transcurrido = 0.0
		_conectar(_url)
		_reintento_sin_rango = true
		return

	_acumular_cuerpo()
	_veredicto()


func _acumular_cuerpo() -> void:
	var nuevos := 0
	while _leidos < LIMITE_CUERPO and _cliente.get_status() == HTTPClient.STATUS_BODY:
		var trozo := _cliente.read_response_body_chunk()
		if trozo.is_empty():
			break
		var utiles := mini(trozo.size(), LIMITE_CUERPO - _leidos)
		_leidos += utiles
		_cuerpo += trozo.slice(0, utiles).get_string_from_utf8().to_lower()
		nuevos += 1
		if _parece_muerto(codigo, _cuerpo):
			break
	_espera = 0.0 if nuevos > 0 else _espera + get_process_delta_time()


func _cuerpo_completo() -> bool:
	if _leidos >= LIMITE_CUERPO:
		return true
	var largo := _cliente.get_response_body_length()
	if largo >= 0 and _leidos >= largo:
		return true
	return _espera >= ESPERA_CUERPO


func _veredicto(forzar := false) -> void:
	if not forzar and codigo >= 200 and codigo < 400 and not _cuerpo_completo():
		return
	if _parece_muerto(codigo, _cuerpo):
		_cerrar(tr("No existe (%d)") % codigo, false, MOTIVO_MUERTO)
		return

	if codigo >= 200 and codigo < 400:
		_cerrar(tr("OK (%d)") % codigo, true, MOTIVO_OK)
		return
	if codigo == 401 or codigo == 403:
		_cerrar(tr("Existe, acceso restringido (%d)") % codigo, true, MOTIVO_OK)
		return

	_cerrar(tr("Error HTTP %d") % codigo, false, MOTIVO_HTTP)


func _parece_muerto(codigo: int, html: String) -> bool:
	if codigo == 404 or codigo == 410:
		return true
	if html.is_empty():
		return false
	for marca in _marcas_para_host(_host_actual):
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


func _cerrar(mensaje: String, valido: bool, causa := MOTIVO_HTTP) -> void:
	if not _activo:
		return
	motivo = causa
	transitorio = not valido and es_transitorio(causa, codigo)
	if not valido and transitorio and _programar_reintento():
		return
	_activo = false
	set_process(false)
	_cliente.close()
	terminado.emit(valido, mensaje)
	queue_free()


func _programar_reintento() -> bool:
	if not reintentar_transitorios:
		return false
	if _reintentos >= ESPERA_REINTENTOS.size():
		return false
	_espera_reintento = _espera_reintento_calculada()
	_reintentos += 1
	intentos = _reintentos + 1
	return true


func _espera_reintento_calculada() -> float:
	return espera_con_retry_after(espera_reintento(_reintentos), _retry_after())


static func espera_con_retry_after(base: float, indicada: float) -> float:
	if indicada >= 0.0:
		return clampf(indicada, 0.0, MAX_RETRY_AFTER)
	return base


func _retry_after() -> float:
	if motivo != MOTIVO_HTTP:
		return -1.0
	var valor := _cabecera("Retry-After")
	if valor.is_empty():
		return -1.0
	if valor.is_valid_int():
		return clampf(float(valor.to_int()), 0.0, MAX_RETRY_AFTER)
	var marca := fecha_http_unix(valor)
	if marca < 0:
		return -1.0
	return clampf(float(marca - int(Time.get_unix_time_from_system())), 0.0, MAX_RETRY_AFTER)


static func fecha_http_unix(valor: String) -> int:
	var limpio := valor.replace(",", " ").replace("-", " ").strip_edges()
	var numeros: Array[int] = []
	var mes := -1
	var reloj := ""
	for pieza in limpio.split(" ", false):
		var minus := pieza.to_lower()
		if minus.length() == 3 and MESES_HTTP.has(minus):
			mes = int(MESES_HTTP.find(minus))
		elif reloj.is_empty() and pieza.contains(":"):
			reloj = pieza
		elif minus.is_valid_int():
			numeros.append(minus.to_int())
	if mes < 0 or reloj.is_empty() or numeros.size() < 2:
		return -1
	var dia := 0
	var anio := 0
	for n in numeros:
		if anio == 0 and n > 31:
			anio = n
		elif dia == 0 and n <= 31:
			dia = n
	if anio == 0:
		for n in numeros:
			if n != dia:
				anio = n
				break
	if anio < 100:
		anio += 2000
	if anio < 100 or dia < 1:
		return -1
	var partes := reloj.split(":")
	if partes.size() < 2:
		return -1
	var marca := Time.get_unix_time_from_datetime_dict({
		"year": anio,
		"month": mes + 1,
		"day": dia,
		"hour": int(partes[0]),
		"minute": int(partes[1]),
		"second": int(partes[2]) if partes.size() > 2 else 0,
	})
	return -1 if marca < 0 else int(marca)
