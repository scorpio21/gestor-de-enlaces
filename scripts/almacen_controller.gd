extends RefCounted

const AlmacenScript := preload("res://scripts/almacen.gd")
const AlmacenConfigScript := preload("res://scripts/almacen_config.gd")
const AlmacenJsonScript := preload("res://scripts/almacen_json.gd")

var config := {}
var almacen = null
var avisos: Array = []


func _init(argumentos := PackedStringArray(), base_config := "user://", config_inyectada := {}) -> void:
	# El tercer parametro existe para las pruebas: meter la config a mano evita
	# tener que escribir un user://almacenamiento.json de verdad, que tocaria los
	# datos del que esta ejecutando la suite.
	var lector := AlmacenConfigScript.new(base_config)
	config = config_inyectada.duplicate() if not config_inyectada.is_empty() else lector.cargar(argumentos)
	avisos = lector.avisos.duplicate()
	almacen = crear(config)
	if almacen == null:
		avisos.append("No se pudo abrir el almacenamiento elegido.")
		almacen = AlmacenJsonScript.new("user://")
		config["modo"] = AlmacenScript.MODO_FICHEROS
		return
	almacen.ruta_bd = str(config.get("ruta_bd", AlmacenScript.RUTA_BD_POR_DEFECTO))
	if not almacen.abrir():
		avisos.append("No se pudo preparar la carpeta %s." % almacen.rutas().get("base", "?"))
		almacen = AlmacenJsonScript.new("user://")
		config["base"] = "user://"


static func crear(cfg: Dictionary):
	var modo := AlmacenScript.modo_valido(cfg.get("modo", AlmacenScript.MODO_FICHEROS))
	var base_texto := str(cfg.get("base", "user://"))
	if not AlmacenScript.ruta_ok(base_texto):
		return null
	if modo == AlmacenScript.MODO_BASE_DATOS:
		return null
	var json := AlmacenJsonScript.new(base_texto)
	json.ruta_bd = str(cfg.get("ruta_bd", AlmacenScript.RUTA_BD_POR_DEFECTO))
	return json


static func soporta(modo: Variant) -> bool:
	return AlmacenScript.modo_valido(modo) == AlmacenScript.MODO_FICHEROS


func cerrar() -> void:
	if almacen != null:
		almacen.cerrar()


func base_datos() -> String:
	return AlmacenScript.con_barra(str(almacen.rutas().get("base", "user://"))) if almacen != null else "user://"


func aplicar_a(nodo) -> String:
	# Escribe CONFIG_BASE, DATA_USER y ASSETS_BASE en el nodo que se le pase y
	# devuelve la base usada. Vive aqui y no en main.gd para que el criterio sea
	# una sola cosa: el almacenamiento decide donde estan los datos, y main solo
	# obedece (#63).
	var base := base_datos()
	if nodo == null:
		return base
	# Solo se pisa si el almacenamiento apunta a otro sitio. user:// es el valor
	# por defecto y, si alguien lo ha cambiado antes (las suites montan main y
	# luego apuntan sus stores a una carpeta propia), manda quien lo cambio.
	if base != "user://":
		nodo.CONFIG_BASE = base
		nodo.DATA_USER = base + "enlaces.json"
		nodo.ASSETS_BASE = base + "Assets"
	return base


func migrar_a_otro(otro) -> Dictionary:
	if otro == null:
		return {"ok": false, "errores": 1, "detalle": "No hay destino."}
	var origen := recuentos()
	var destino: Dictionary = otro.recuentos()
	if int(destino.get("entradas", 0)) + int(destino.get("estados", 0)) > 0:
		return {"ok": false, "errores": 1, "detalle": "El destino ya tiene datos; no se toca nada."}
	if otro.abrir():
		otro.ruta_bd = str(config.get("ruta_bd", AlmacenScript.RUTA_BD_POR_DEFECTO))
	return almacen.migra_a(otro)


func info() -> Dictionary:
	if almacen == null:
		return {}
	var mapa: Dictionary = almacen.rutas()
	var ficheros: Array = mapa.get("ficheros", [])
	var detalle := []
	for ruta in ficheros:
		detalle.append({"ruta": str(ruta), "bytes": AlmacenScript.tamano_de_ruta(str(ruta))})
	return {
		"modo": almacen.modo(),
		"base": str(mapa.get("base", "")),
		"carpetas": mapa.get("carpetas", []),
		"ficheros": detalle,
		"total": almacen.tamano_total(),
		"recuentos": recuentos(),
		"origen": str(config.get("origen", "")),
		"avisos": avisos.duplicate(),
	}


func recuentos() -> Dictionary:
	return almacen.recuentos() if almacen != null else {}