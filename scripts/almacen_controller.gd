extends RefCounted

const AlmacenScript := preload("res://scripts/almacen.gd")
const AlmacenConfigScript := preload("res://scripts/almacen_config.gd")
const AlmacenJsonScript := preload("res://scripts/almacen_json.gd")
const AlmacenUnoScript := preload("res://scripts/almacen_uno.gd")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")

var config := {}
var almacen = null
var avisos: Array = []

# El orden en que los ofrece Preferencias, que no es el de MODOS: el que se usa
# es el ultimo, porque todavia no hay backend de base de datos que lo atienda.
const MODOS_SELECCION := [
	AlmacenScript.MODO_FICHEROS,
	AlmacenScript.MODO_UNICO,
	AlmacenScript.MODO_BASE_DATOS,
]


func _init(argumentos := PackedStringArray(), base_config := "user://", config_inyectada := {}, ruta_config := "") -> void:
	# El tercer parametro existe para las pruebas: meter la config a mano evita
	# tener que escribir un user://almacenamiento.json de verdad, que tocaria los
	# datos del que esta ejecutando la suite. El cuarto apunta ese mismo fichero
	# a otro sitio por lo mismo: Preferencias lo re-apunta antes de migrar (#63).
	var lector := AlmacenConfigScript.new(base_config, ruta_config)
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
		return
	if almacen.bloqueado():
		avisos.append("Los datos los escribió una versión más nueva del gestor. No se van a tocar hasta que se abra con ella.")


static func crear(cfg: Dictionary):
	var modo := AlmacenScript.modo_valido(cfg.get("modo", AlmacenScript.MODO_FICHEROS))
	var base_texto := str(cfg.get("base", "user://"))
	if not AlmacenScript.ruta_ok(base_texto):
		return null
	if modo == AlmacenScript.MODO_BASE_DATOS:
		return null
	if modo == AlmacenScript.MODO_UNICO:
		return AlmacenUnoScript.new(base_texto)
	var json := AlmacenJsonScript.new(base_texto)
	json.ruta_bd = str(cfg.get("ruta_bd", AlmacenScript.RUTA_BD_POR_DEFECTO))
	return json


static func crear_en(modo: String, base_texto: String):
	# El backend que guarda en esa carpeta en ese modo. Preferencias lo necesita
	# al cambiar de sitio y al cambiar de modo: si eligiera el backend a mano se
	# le olvidaria uno de los dos casos y la migracion acabaria escribiendo en un
	# formato que luego nadie lee, con la preferencia apuntando al otro (#63).
	return crear({"modo": modo, "base": base_texto})


static func soporta(modo: Variant) -> bool:
	var m := AlmacenScript.modo_valido(modo)
	return m == AlmacenScript.MODO_FICHEROS or m == AlmacenScript.MODO_UNICO


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


func migrar_a_otro(otro, pisar := false) -> Dictionary:
	if otro == null:
		return {"ok": false, "errores": 1, "detalle": "No hay destino."}
	var origen := recuentos()
	var destino: Dictionary = otro.recuentos()
	# "El destino ya tiene datos" es para un sitio distinto: es lo que evita
	# montar una migracion encima del trabajo de otra sesion. Al cambiar de modo
	# en la misma carpeta, en cambio, el destino es la otra version de estos
	# mismos datos (los ocho ficheros de antes o el gestorao.json de antes), y
	# negarse dejaria el selector sin poder volver atras nunca (#63).
	if not pisar and int(destino.get("entradas", 0)) + int(destino.get("estados", 0)) > 0:
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


func para_stores():
	# Los stores reciben el almacenamiento solo cuando no es el de ficheros. En
	# modo ficheros el store ya sabe guardarse solo en su base, y las pruebas que
	# apuntan un store a una carpeta propia (s._config_store = ...new(BASE)) siguen
	# mandando sobre donde escribe. En cualquier otro backend el store tiene que
	# escribir por la interfaz o se quedaria haciendo su cuenta con los ficheros
	# de siempre mientras el catalogo se va a otro sitio (#63).
	return almacen if almacen != null and almacen.modo() != AlmacenScript.MODO_FICHEROS else null


func recuentos() -> Dictionary:
	return almacen.recuentos() if almacen != null else {}


func entradas_de(ruta: String) -> Array:
	# El catalogo del usuario va por el almacenamiento, no por un fichero suelto:
	# es la unica parte de los datos que escribe main.gd en vez de un store, y en
	# un backend de fichero unico no existe enlaces.json.
	#
	# Solo cuando el almacenamiento no es el de ficheros. En modo ficheros manda la
	# ruta que le pasa quien llama, porque main y las suites reapuntan DATA_USER a su
	# carpeta: si aqui se ignorara, una suite leeria el catalogo real del usuario y
	# al limpiar capturas huerfanas le borraria sus imagenes (#63).
	if not _por_interfaz():
		return GestorDatosScript.cargar(ruta)
	return almacen.entradas()


func guardar_entradas_en(ruta: String, lista: Array) -> bool:
	if not _por_interfaz():
		return GestorDatosScript.guardar(ruta, lista)
	return almacen.guardar_entradas(lista)


func hay_copia(ruta := "") -> bool:
	if not _por_interfaz():
		return GestorDatosScript.hay_copia(ruta)
	return almacen.hay_copia()


func restaurar_copia(ruta := "") -> bool:
	if not _por_interfaz():
		return GestorDatosScript.restaurar_copia(ruta)
	return almacen.restaurar_copia()


func _por_interfaz() -> bool:
	return almacen != null and almacen.modo() != AlmacenScript.MODO_FICHEROS