extends RefCounted

const CambiosStoreScript := preload("res://scripts/cambios_store.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")

const PENDIENTES := "user://cambios_pendientes.json"

var ruta := PENDIENTES
var _claves := {}
var _vistos := false


func registrar(cambios: Array) -> Array:
	_claves = {}
	for cambio in cambios:
		if typeof(cambio) != TYPE_DICTIONARY:
			continue
		var clave := str(cambio.get("clave", ""))
		if not clave.is_empty():
			_claves[clave] = str(cambio.get("tipo", ""))
	return cambios


func marcar_vistos() -> void:
	_vistos = true
	borrar_pendientes()


func vistos() -> bool:
	return _vistos


func marca_de(clave: String) -> String:
	match str(_claves.get(clave, "")):
		CambiosStoreScript.TIPO_NUEVO_CAIDO:
			return "caido"
		CambiosStoreScript.TIPO_RECUPERADO:
			return "valido"
		CambiosStoreScript.TIPO_REUBICADO:
			return "aviso"
	return ""


func nombres_de(entradas: Array) -> Dictionary:
	var nombres := {}
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			nombres[GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))] = str(entrada.get("nombre", ""))
	return nombres


func claves() -> Dictionary:
	return _claves


func cobertura_de(estados: Dictionary) -> int:
	return CambiosStoreScript.cobertura(estados)


func pendientes_al_salir() -> Array:
	var cambios: Array = []
	for clave in _claves.keys():
		cambios.append({"clave": clave, "tipo": str(_claves[clave])})
	return cambios


func nuevo_delta(antes: Dictionary, despues: Dictionary) -> Array:
	return registrar(CambiosStoreScript.cambios_de(CambiosStoreScript.delta(antes, despues)))


func leer_pendientes() -> Array:
	if not FileAccess.file_exists(ruta):
		return []
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	return datos if typeof(datos) == TYPE_ARRAY else []


func guardar_pendientes(cambios: Array) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify(cambios))
	archivo.close()
	return true


func borrar_pendientes() -> bool:
	if not FileAccess.file_exists(ruta):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta)) == OK