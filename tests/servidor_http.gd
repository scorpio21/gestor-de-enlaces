extends RefCounted

var puerto := 0
var peticiones: PackedStringArray = PackedStringArray()
var enviados := 0

var _srv := TCPServer.new()
var _peer: StreamPeerTCP = null
var _recibido := ""
var _guion: Array = []
var _servidos := 0
var _espera := 0
var _ritmo := 1
var _ritmo_cont := 0
var _pendientes: Array = []
var _actual := -1


func arrancar() -> bool:
	if _srv.listen(0, "127.0.0.1") != OK:
		return false
	puerto = _srv.get_local_port()
	return puerto > 0


func parar() -> void:
	soltar()
	_srv.stop()


func preparar(guion: Array) -> void:
	_guion = guion.duplicate()
	_servidos = 0
	_actual = -1
	_espera = 0
	_ritmo = 1
	_ritmo_cont = 0
	_pendientes = []
	enviados = 0
	_recibido = ""
	peticiones = PackedStringArray()
	soltar()


func servir() -> int:
	return _servidos


func soltar() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null


func paso() -> void:
	if _peer != null:
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			soltar()
	if _peer == null:
		var c: Variant = _srv.take_connection()
		if c != null:
			_peer = c as StreamPeerTCP
			_recibido = ""
			_actual = -1
			_espera = 0
			_pendientes = []
			if _servidos < _guion.size() and bool(_guion[_servidos].get("corte", false)):
				_servidos += 1
				soltar()
		return
	_pumpar()
	if _actual < 0:
		if not _recibido.contains("\r\n\r\n"):
			return
		peticiones.append(_recibido)
		_recibido = ""
		if _servidos >= _guion.size():
			return
		_actual = _servidos
		_servidos += 1
		var paso: Dictionary = _guion[_actual]
		_espera = int(paso.get("espera", 0))
		_ritmo = maxi(1, int(paso.get("ritmo", 1)))
		_ritmo_cont = 0
		_pendientes = _piezas(paso)
		return
	if _espera > 0:
		_espera -= 1
		return
	if not _pendientes.is_empty():
		if _ritmo > 1:
			if _ritmo_cont > 0:
				_ritmo_cont -= 1
				return
			_ritmo_cont = _ritmo - 1
		var trozo: PackedByteArray = _pendientes[0]
		if _peer.put_data(trozo) != OK:
			soltar()
			return
		_pendientes.pop_front()
		enviados += trozo.size()
		return
	if bool(_guion[_actual].get("cerrar", false)):
		soltar()


func _pumpar() -> void:
	var disponible := _peer.get_available_bytes()
	if disponible <= 0:
		return
	var leido := _peer.get_data(disponible)
	if int(leido[0]) != OK:
		return
	var buf: PackedByteArray = leido[1]
	_recibido += buf.get_string_from_utf8()


func _piezas(paso: Dictionary) -> Array:
	var estado := str(paso.get("estado", "200 OK"))
	var extra := str(paso.get("extra", ""))
	var cuerpo := str(paso.get("cuerpo", ""))
	var trozos := maxi(1, int(paso.get("trozos", 1)))
	var largo := int(paso.get("longitud", cuerpo.length()))
	var chunked := extra.contains("chunked")
	var cabeceras := "HTTP/1.1 %s\r\n" % estado
	if not chunked:
		cabeceras += "Content-Length: %d\r\n" % largo
	cabeceras += "Content-Type: text/html\r\n" + extra
	if bool(paso.get("cerrar", false)):
		cabeceras += "Connection: close\r\n"
	cabeceras += "\r\n"

	var piezas: Array = [cabeceras.to_utf8_buffer()]
	var tamano := maxi(1, int(ceil(float(cuerpo.length()) / float(trozos))))
	while cuerpo.length() > 0:
		var trozo := cuerpo.substr(0, tamano)
		cuerpo = cuerpo.substr(trozo.length())
		if chunked:
			piezas.append(("%x\r\n%s\r\n" % [trozo.to_utf8_buffer().size(), trozo]).to_utf8_buffer())
		else:
			piezas.append(trozo.to_utf8_buffer())
	if chunked:
		piezas.append("0\r\n\r\n".to_utf8_buffer())
	return piezas
