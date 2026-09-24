extends SceneTree

const OrdenadorScript := preload("res://scripts/ordenador.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_check(OrdenadorScript.direccion_por_defecto("nombre") == 1, "nombre ordena ascendente por defecto")
	_check(OrdenadorScript.direccion_por_defecto("imagen") == 1, "imagen ordena ascendente por defecto")
	_check(OrdenadorScript.direccion_por_defecto("estado") == -1, "estado ordena descendente por defecto")
	_check(OrdenadorScript.direccion_por_defecto("fecha") == -1, "fecha ordena descendente por defecto")
	_check(OrdenadorScript.direccion_por_defecto("otra") == -1, "columna desconocida ordena descendente por defecto")

	_check(OrdenadorScript.peso_estado(null) == 0, "peso_estado null → 0")
	_check(OrdenadorScript.peso_estado(true) == 1, "peso_estado true → 1")
	_check(OrdenadorScript.peso_estado(false) == 2, "peso_estado false → 2")

	var por_nombre := [
		_fila({"nombre": "Beta", "url": "b.com"}),
		_fila({"nombre": "Alfa", "url": "a.com"}),
		_fila({"nombre": "Gamma", "url": "c.com"}),
	]
	_check(_nombres(por_nombre, "nombre", 1) == ["Alfa", "Beta", "Gamma"], "nombre asc")
	_check(_nombres(por_nombre, "nombre", -1) == ["Gamma", "Beta", "Alfa"], "nombre desc")

	var empatadas := [
		_fila({"nombre": "Mismo", "url": "z.com"}),
		_fila({"nombre": "Mismo", "url": "a.com"}),
	]
	var nombre_empatado := _ordenadas(empatadas, "nombre", 1)
	_check(nombre_empatado[0].url == "a.com" and nombre_empatado[1].url == "z.com", "nombre igual se desempata por url")

	var por_estado := [
		_fila({"url": "nula.com", "valido": null}),
		_fila({"url": "roto.com", "valido": false}),
		_fila({"url": "ok.com", "valido": true}),
	]
	_check(_urls(por_estado, "estado", -1) == ["roto.com", "ok.com", "nula.com"], "estado desc: rotos primero, sin comprobar al final")
	_check(_urls(por_estado, "estado", 1) == ["nula.com", "ok.com", "roto.com"], "estado asc: sin comprobar primero, rotos al final")

	var por_fecha := [
		_fila({"url": "fecha0.com", "fecha": 0}),
		_fila({"url": "viejo.com", "fecha": 100}),
		_fila({"url": "nuevo.com", "fecha": 200}),
	]
	_check(_urls(por_fecha, "fecha", -1) == ["nuevo.com", "viejo.com", "fecha0.com"], "fecha desc: más reciente primero y sin fecha al final")
	_check(_urls(por_fecha, "fecha", 1) == ["viejo.com", "nuevo.com", "fecha0.com"], "fecha asc: más antigua primero y sin fecha al final")

	var por_imagen := [
		_fila({"url": "con.com", "img": "x.png"}),
		_fila({"url": "sin.com"}),
	]
	_check(_urls(por_imagen, "imagen", 1) == ["con.com", "sin.com"], "imagen asc: con captura primero")
	_check(_urls(por_imagen, "imagen", -1) == ["sin.com", "con.com"], "imagen desc: sin captura primero")

	var desconocida := [
		_fila({"url": "b.com"}),
		_fila({"url": "a.com"}),
	]
	_check(_urls(desconocida, "otra", 1) == ["a.com", "b.com"], "columna desconocida ordena por url")

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


class Fila:
	var nombre := ""
	var url := ""
	var valido = null
	var fecha := 0
	var img := ""


func _fila(p: Dictionary) -> Fila:
	var f := Fila.new()
	f.nombre = str(p.get("nombre", ""))
	f.url = str(p.get("url", ""))
	f.valido = p.get("valido", null)
	f.fecha = int(p.get("fecha", 0))
	f.img = str(p.get("img", ""))
	return f


func _ordenadas(filas: Array, columna: String, direccion: int) -> Array:
	var copia: Array = filas.duplicate()
	copia.sort_custom(func(a, b) -> bool:
		return OrdenadorScript.comparar(a, b, columna, direccion)
	)
	return copia


func _urls(filas: Array, columna: String, direccion: int) -> Array:
	var salida: Array = []
	for f in _ordenadas(filas, columna, direccion):
		salida.append(f.url)
	return salida


func _nombres(filas: Array, columna: String, direccion: int) -> Array:
	var salida: Array = []
	for f in _ordenadas(filas, columna, direccion):
		salida.append(f.nombre)
	return salida


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)