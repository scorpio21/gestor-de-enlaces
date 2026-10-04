extends RefCounted

const MODO_FICHEROS := "ficheros"
const MODO_BASE_DATOS := "base_datos"
const MODOS := [MODO_FICHEROS, MODO_BASE_DATOS]
const ESQUEMA_ACTUAL := 1
const RUTA_BD_POR_DEFECTO := "user://gestorao.db"
const SECCIONES := ["entradas", "estados", "borrados", "cola", "config", "capturas", "instantaneas"]
const LIMITES_HISTORIAL := 50

var base := "user://"
var ruta_bd := RUTA_BD_POR_DEFECTO
var esquema := ESQUEMA_ACTUAL
var escrituras := 0
var abierto := false


static func modo_valido(modo: Variant) -> String:
	var m := str(modo)
	return m if MODOS.has(m) else MODO_FICHEROS


static func ruta_de(base_texto: String, nombre: String) -> String:
	return base_texto + nombre if base_texto.ends_with("://") else base_texto + "/" + nombre


static func con_barra(base_texto: String) -> String:
	if base_texto.ends_with("://") or base_texto.ends_with("/"):
		return base_texto
	return base_texto + "/"


static func ruta_ok(ruta: String) -> bool:
	if ruta.is_empty():
		return false
	return ruta.begins_with("user://") or ruta.begins_with("res://") or ruta.is_absolute_path()


static func leer_json(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return null
	var json := JSON.new()
	if json.parse(archivo.get_as_text()) != OK:
		return null
	return json.data


static func escribir_json(ruta: String, dato: Variant, con_copia := true) -> bool:
	var texto := JSON.stringify(dato, "\t")
	if texto.is_empty():
		return false
	var abs := ProjectSettings.globalize_path(ruta)
	var abs_tmp := ProjectSettings.globalize_path(ruta + ".tmp")
	var archivo := FileAccess.open(ruta + ".tmp", FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(texto)
	archivo.close()
	if archivo.get_error() != OK:
		DirAccess.remove_absolute(abs_tmp)
		return false
	if FileAccess.file_exists(ruta):
		if con_copia:
			if FileAccess.file_exists(ruta + ".bak"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta + ".bak"))
			if DirAccess.rename_absolute(abs, ProjectSettings.globalize_path(ruta + ".bak")) != OK:
				DirAccess.remove_absolute(abs_tmp)
				return false
		else:
			DirAccess.remove_absolute(abs)
	if DirAccess.rename_absolute(abs_tmp, abs) != OK:
		DirAccess.remove_absolute(abs_tmp)
		return false
	return true


static func tamano_de_ruta(ruta: String) -> int:
	var abs := ProjectSettings.globalize_path(ruta)
	if DirAccess.dir_exists_absolute(abs):
		var total := 0
		var dir := DirAccess.open(abs)
		if dir == null:
			return 0
		for f in dir.get_files():
			total += tamano_de_ruta("%s/%s" % [ruta, f])
		for d in dir.get_directories():
			total += tamano_de_ruta("%s/%s" % [ruta, d])
		return total
	if not FileAccess.file_exists(abs):
		return 0
	var archivo := FileAccess.open(abs, FileAccess.READ)
	if archivo == null:
		return 0
	var bytes := archivo.get_length()
	archivo.close()
	return int(bytes)


func abrir() -> bool:
	abierto = true
	return true


func cerrar() -> void:
	abierto = false


func modo() -> String:
	return MODO_FICHEROS


func entradas() -> Array:
	return []


func guardar_entradas(_entradas: Array) -> bool:
	return false


func estados() -> Dictionary:
	return {}


func estado(_clave: String) -> Dictionary:
	return {}


func guardar_estado(_clave: String, _datos: Dictionary) -> bool:
	return false


func historial(_clave: String) -> Array:
	return []


func borrar_estado(_clave: String) -> bool:
	return false


func borrados() -> Array:
	return []


func marcar_borrado(_url: String) -> bool:
	return false


func cola() -> Array:
	return []


func guardar_cola(_urls: Array) -> bool:
	return false


func limpiar_cola() -> bool:
	return true


func config() -> Dictionary:
	return {}


func guardar_config(_datos: Dictionary) -> bool:
	return false


func capturas() -> Dictionary:
	return {}


func guardar_captura(_nombre: String, _origen: String) -> Dictionary:
	return {"ok": false, "error": "Sin implementar."}


func borrar_captura(_nombre: String) -> bool:
	return false


func instantaneas() -> Array:
	return []


func guardar_instantaneas(_filas: Array) -> bool:
	return false


func presets() -> Dictionary:
	return {}


func guardar_presets(_datos: Dictionary) -> bool:
	return false


func cambios() -> Array:
	return []


func guardar_cambios(_lista: Array) -> bool:
	return false


func guardar_estados(_todos: Dictionary) -> bool:
	return false


func guardar_borrados(_lista: Array) -> bool:
	return false


func ruta_de_nombre(nombre: String) -> String:
	return ruta_de(base, nombre)


func rutas() -> Dictionary:
	return {"modo": modo(), "base": base, "ficheros": [], "carpetas": [base]}


func tamano_total() -> int:
	var total := 0
	var mapa := rutas()
	for nombre in mapa.get("carpetas", []):
		total += tamano_de_ruta(str(nombre))
	return total


func volcado() -> Dictionary:
	return {
		"entradas": entradas(),
		"estados": estados(),
		"borrados": borrados(),
		"cola": cola(),
		"config": config(),
		"capturas": capturas(),
		"instantaneas": instantaneas(),
		"presets": presets(),
		"cambios": cambios(),
	}


func recuentos() -> Dictionary:
	var st := estados()
	var hist := 0
	for clave in st.keys():
		hist += historial(str(clave)).size()
	return {
		"entradas": entradas().size(),
		"estados": st.size(),
		"historial": hist,
		"borrados": borrados().size(),
		"cola": cola().size(),
		"capturas": capturas().size(),
		"instantaneas": instantaneas().size(),
		"presets": presets().size(),
		"cambios": cambios().size(),
	}


func importar(datos: Dictionary) -> Dictionary:
	var errores := 0
	if datos.has("entradas") and not guardar_entradas(datos.get("entradas", [])):
		errores += 1
	if datos.has("estados") and not guardar_estados(datos.get("estados", {})):
		errores += 1
	if datos.has("borrados") and not guardar_borrados(datos.get("borrados", [])):
		errores += 1
	if datos.has("cola") and not guardar_cola(datos.get("cola", [])):
		errores += 1
	if datos.has("config") and not guardar_config(datos.get("config", {})):
		errores += 1
	if datos.has("capturas"):
		for nombre in (datos.get("capturas", {}) as Dictionary).keys():
			if not guardar_captura(str(nombre), str((datos.get("capturas", {}) as Dictionary)[nombre])).get("ok", false):
				errores += 1
	if datos.has("instantaneas") and not guardar_instantaneas(datos.get("instantaneas", [])):
		errores += 1
	if datos.has("presets") and not guardar_presets(datos.get("presets", {})):
		errores += 1
	if datos.has("cambios") and not guardar_cambios(datos.get("cambios", [])):
		errores += 1
	return {"ok": errores == 0, "errores": errores}


func migra_a(otro) -> Dictionary:
	if otro == null:
		return {"ok": false, "errores": 1, "detalle": "No hay destino."}
	var origen := recuentos()
	var escrito: Dictionary = otro.importar(volcado())
	if not escrito.get("ok", false):
		return {"ok": false, "errores": int(escrito.get("errores", 1)), "origen": origen, "destino": {}, "detalle": "La escritura fallo."}
	var destino: Dictionary = otro.recuentos()
	var iguales := origen == destino
	return {"ok": iguales, "errores": 0 if iguales else 1, "origen": origen, "destino": destino, "detalle": "" if iguales else "Los recuentos no coinciden."}


func migra_de(otro) -> Dictionary:
	if otro == null:
		return {"ok": false, "errores": 1, "detalle": "No hay origen."}
	var res: Dictionary = otro.migra_a(self)
	res["invertida"] = true
	return res