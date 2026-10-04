extends RefCounted

const AlmacenScript := preload("res://scripts/almacen.gd")

const NOMBRE := "almacenamiento.json"
const ESQUEMA_ACTUAL := 1
const ARGUMENTO := "--almacen="
const ENV_ALMACEN := "GESTORAO_ALMACEN"
const ENV_BASE := "GESTORAO_BASE"
const MODOS := AlmacenScript.MODOS

var base := "user://"
var ruta := "user://" + NOMBRE
var avisos: Array = []


func _init(base_config := "user://", ruta_config := "") -> void:
	# El fichero que dice donde estan los datos SIEMPRE vive en user://, aunque
	# los datos se muden: si se moviera con ellos, al cambiar de sitio dejaria
	# de haber forma de saber cual era el sitio viejo, y los datos quedarian
	# huerfanos. El segundo parametro existe solo para las pruebas.
	base = base_config
	ruta = ruta_config if not ruta_config.is_empty() else "user://" + NOMBRE


static func por_defecto() -> Dictionary:
	return {
		"modo": AlmacenScript.MODO_FICHEROS,
		"base": "user://",
		"ruta_bd": AlmacenScript.RUTA_BD_POR_DEFECTO,
		"esquema": ESQUEMA_ACTUAL,
		"origen": "por defecto",
	}


static func normalizar(bruto: Variant) -> Dictionary:
	var d := por_defecto()
	if typeof(bruto) != TYPE_DICTIONARY:
		return d
	var dato := bruto as Dictionary
	d["modo"] = AlmacenScript.modo_valido(dato.get("modo", d["modo"]))
	var base_bruta := str(dato.get("base", d["base"])).strip_edges()
	if AlmacenScript.ruta_ok(base_bruta):
		d["base"] = con_barra(base_bruta)
	var ruta_bd := str(dato.get("ruta_bd", d["ruta_bd"])).strip_edges()
	if AlmacenScript.ruta_ok(ruta_bd):
		d["ruta_bd"] = ruta_bd
	d["esquema"] = int(dato.get("esquema", d["esquema"]))
	d["origen"] = "fichero"
	return d


static func desde_argumentos(argumentos: PackedStringArray) -> Dictionary:
	for arg in argumentos:
		var texto := str(arg)
		if not texto.begins_with(ARGUMENTO):
			continue
		var valor := texto.substr(ARGUMENTO.length()).strip_edges()
		if valor.is_empty():
			continue
		if valor in MODOS:
			return {"modo": valor, "origen": "argumento"}
		if not AlmacenScript.ruta_ok(valor):
			return {"modo": "", "origen": "argumento", "error": "Ruta no valida: %s" % valor}
		return {"modo": AlmacenScript.MODO_FICHEROS, "base": con_barra(valor), "origen": "argumento"}
	return {}


static func desde_entorno() -> Dictionary:
	var modo := OS.get_environment(ENV_ALMACEN).strip_edges()
	var base_texto := OS.get_environment(ENV_BASE).strip_edges()
	if modo.is_empty() and base_texto.is_empty():
		return {}
	var res := {"origen": "entorno"}
	if not modo.is_empty():
		if not (modo in MODOS):
			res["modo"] = ""
			res["error"] = "GESTORAO_ALMACEN no es un modo valido: %s" % modo
		else:
			res["modo"] = modo
	if not base_texto.is_empty():
		res["base"] = con_barra(base_texto) if AlmacenScript.ruta_ok(base_texto) else ""
		if str(res.get("base", "")) == "":
			res["error"] = "GESTORAO_BASE no es una ruta: %s" % base_texto
	return res


static func con_barra(base_texto: String) -> String:
	return AlmacenScript.con_barra(base_texto)


func cargar(argumentos := PackedStringArray()) -> Dictionary:
	var config := por_defecto()
	if FileAccess.file_exists(ruta):
		var dato: Variant = AlmacenScript.leer_json(ruta)
		if typeof(dato) == TYPE_DICTIONARY:
			_avisa_modo(dato.get("modo", AlmacenScript.MODO_FICHEROS))
			config = normalizar(dato)
		else:
			avisos.append("%s ilegible; se usan los valores por defecto." % NOMBRE)
	for fuente in [desde_entorno(), desde_argumentos(argumentos)]:
		if fuente.is_empty():
			continue
		if str(fuente.get("error", "")) != "":
			avisos.append(str(fuente["error"]))
			continue
		if str(fuente.get("modo", "")) != "":
			_avisa_modo(fuente["modo"])
		for clave in ["modo", "base", "ruta_bd"]:
			if fuente.has(clave) and str(fuente[clave]) != "":
				config[clave] = fuente[clave]
		config["origen"] = str(fuente["origen"])
	if not (str(config["modo"]) in MODOS):
		config["modo"] = AlmacenScript.MODO_FICHEROS
	return config


func _avisa_modo(modo: Variant) -> void:
	# El aviso va aqui y no dentro de normalizar(): esa existe para devolver algo
	# utilizable siempre, y un default silencioso es justo lo que hay que evitar.
	# Si alguien pone "postgres" en el fichero y no se le dice nada, creera que
	# esta usando una base de datos cuando sigue con ficheros.
	if str(modo).is_empty() or str(modo) in MODOS:
		return
	avisos.append("Modo desconocido (%s); se usa ficheros." % str(modo))


func guardar(modo: Variant, ruta_bd: Variant, base_nueva := "") -> Dictionary:
	# Se valida el valor crudo, no el de normalizar(): guardar("inventado")
	# tiene que decir que no, no guardarse como "ficheros" en silencio y dejar
	# al usuario creyendo que ha configurado algo que no existe.
	if not (str(modo) in MODOS):
		return {"ok": false, "error": "Modo no valido."}
	if not base_nueva.is_empty() and not AlmacenScript.ruta_ok(base_nueva):
		return {"ok": false, "error": "La ruta de la carpeta no es valida: %s" % str(base_nueva)}
	var actual := cargar()
	var limpio := normalizar({
		"modo": modo,
		"base": base_nueva if not base_nueva.is_empty() else actual["base"],
		"ruta_bd": ruta_bd if not str(ruta_bd).is_empty() else actual["ruta_bd"],
	})
	var ok := AlmacenScript.escribir_json(ruta, {
		"modo": limpio["modo"],
		"base": limpio["base"],
		"ruta_bd": limpio["ruta_bd"],
		"esquema": ESQUEMA_ACTUAL,
	})
	if not ok:
		return {"ok": false, "error": "No se pudo escribir el almacenamiento."}
	return {"ok": true, "config": limpio}


func rutas() -> Array:
	return [ruta]