extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const EtiquetasScript := preload("res://scripts/etiquetas.gd")
const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")
const RutasScript := preload("res://scripts/rutas.gd")


func urls_existentes(entradas: Array) -> Array:
	var urls: Array = []
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			urls.append(str(entrada.get("url", "")))
	return urls


func url_existente(entradas: Array, url: String) -> String:
	var clave := GestorCatalogoScript.clave_unica(url)
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			var c := GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))
			if not c.is_empty() and c == clave:
				return str(entrada.get("url", ""))
	return ""


func buscar_entrada(entradas: Array, url_entrada: String) -> Dictionary:
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("url", "")) == url_entrada:
			return entrada
	return {}


func indice_entrada(entradas: Array, url: String) -> int:
	var clave := GestorCatalogoScript.clave_unica(url)
	if clave.is_empty():
		return -1
	for i in range(entradas.size()):
		if typeof(entradas[i]) != TYPE_DICTIONARY:
			continue
		if GestorCatalogoScript.clave_unica(str(entradas[i].get("url", ""))) == clave:
			return i
	return -1


func cambios_url_validos(entradas: Array, url_original: String, url_nueva: String) -> bool:
	var existentes: Array = []
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("url", "")) != url_original:
			existentes.append(str(entrada.get("url", "")))
	var res := GestorCatalogoScript.separar([url_nueva], existentes)
	return (res.get("repetidas", []) as Array).is_empty()


func normalizar_entrada(datos: Dictionary) -> Dictionary:
	var salida: Dictionary = datos.duplicate(true)
	salida["url"] = GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))
	salida["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", "otro"))
	salida["tags"] = EtiquetasScript.parsear(datos.get("tags", []))
	return salida


func agregar(entradas: Array, datos: Dictionary) -> Dictionary:
	var entrada := normalizar_entrada(datos)
	var existente := url_existente(entradas, str(entrada.get("url", "")))
	if not existente.is_empty():
		return {"ok": false, "mensaje": tr("Ya existe: %s") % existente}
	entradas.append(entrada)
	return {
		"ok": true,
		"mensaje": tr("Enlace agregado: %s") % str(entrada.get("nombre", "")),
		"reutilizada": bool(entrada.get("img_reutilizada", false)),
	}


func agregar_lote(entradas: Array, urls: Array) -> Dictionary:
	var canonicas: Array = []
	for linea in urls:
		var u: String = GestorCatalogoScript.normalizar_url(linea.strip_edges() if typeof(linea) == TYPE_STRING else "")
		if not u.is_empty():
			canonicas.append(u)
	var validas: Array = []
	var invalidas: Array = []
	for u in canonicas:
		if u.begins_with("http://") or u.begins_with("https://"):
			validas.append(u)
		else:
			invalidas.append(u)
	var res := GestorCatalogoScript.separar(validas, urls_existentes(entradas))
	var nuevas: Array = res.get("nuevas", [])
	var repetidas: Array = res.get("repetidas", [])
	if nuevas.is_empty():
		var partes_vacias: Array = [tr("No se añadió ningún enlace.")]
		if not repetidas.is_empty():
			partes_vacias.append(tr("%d repetidas ignoradas.") % repetidas.size())
		if not invalidas.is_empty():
			partes_vacias.append(tr("%d inválidas ignoradas.") % invalidas.size())
		return {"ok": false, "nuevas": 0, "mensaje": " ".join(partes_vacias)}
	for u in nuevas:
		entradas.append({
			"nombre": GestorCatalogoScript.dominio(u),
			"desc": "",
			"url": u,
			"img": "",
			"cat": "otro",
		})
	var partes: Array = [tr("Se añadieron %d enlaces.") % nuevas.size()]
	if not repetidas.is_empty():
		partes.append(tr("%d repetidas ignoradas.") % repetidas.size())
	if not invalidas.is_empty():
		partes.append(tr("%d inválidas ignoradas.") % invalidas.size())
	return {"ok": true, "nuevas": nuevas.size(), "mensaje": " ".join(partes)}


func editar(entradas: Array, estados: Dictionary, borrados: Array, datos: Dictionary, url_original: String, assets_base: String) -> Dictionary:
	var url_nueva := GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))
	var indice := -1
	for i in range(entradas.size()):
		if typeof(entradas[i]) == TYPE_DICTIONARY and str(entradas[i].get("url", "")) == url_original:
			indice = i
			break
	if indice == -1:
		return {"ok": false, "mensaje": tr("No se encontró el enlace.")}
	var entrada: Dictionary = entradas[indice]
	var img_anterior := str(entrada.get("img", ""))
	if url_nueva != url_original and not cambios_url_validos(entradas, url_original, url_nueva):
		var datos_reabrir := datos.duplicate(true)
		datos_reabrir["img"] = img_anterior
		datos_reabrir.erase("img_pendiente")
		return {"ok": false, "reabrir": datos_reabrir, "mensaje": tr("Ya existe: %s") % url_nueva}
	var destino := str(datos.get("img", ""))
	var captura_reutilizada := false
	if datos.has("img_pendiente"):
		var resultado := GestorImagenesScript.copiar(str(datos["img_pendiente"]), str(datos.get("nombre", "")), assets_base)
		if not resultado.get("ok", false):
			return {"ok": false, "mensaje": tr("No se pudo procesar la imagen.")}
		destino = str(resultado.get("destino", ""))
		captura_reutilizada = bool(resultado.get("reutilizada", false))
	var renombrar: Array = []
	if url_nueva != url_original:
		renombrar = _renombrar_clave(estados, borrados, url_original, url_nueva)
	entrada["nombre"] = str(datos.get("nombre", ""))
	entrada["desc"] = str(datos.get("desc", ""))
	entrada["url"] = url_nueva
	entrada["img"] = destino
	entrada["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", entrada.get("cat", "otro")))
	entrada["tags"] = EtiquetasScript.parsear(datos.get("tags", entrada.get("tags", [])))
	return {
		"ok": true,
		"mensaje": tr("Enlace actualizado: %s") % str(datos.get("nombre", "")),
		"reutilizada": captura_reutilizada,
		"img_anterior": img_anterior,
		"img": destino,
		"renombrar": renombrar,
	}


func actualizar_url(entradas: Array, estados: Dictionary, borrados: Array, url_original: String, url_nueva: String) -> Dictionary:
	var entrada := buscar_entrada(entradas, url_original)
	if entrada.is_empty():
		return {"ok": false, "mensaje": tr("No se encontró el enlace.")}
	if url_nueva.is_empty() or url_nueva == url_original:
		return {"ok": false, "mensaje": tr("La URL nueva es la misma.")}
	var copia: Dictionary = entrada.duplicate(true)
	copia["url"] = url_nueva
	return editar(entradas, estados, borrados, copia, url_original, "")


func eliminar(entradas: Array, url: String) -> Dictionary:
	var clave := GestorCatalogoScript.clave_unica(url)
	var img := ""
	var primera := -1
	for i in range(entradas.size()):
		if not _coincide(entradas[i], url, clave):
			continue
		if primera == -1:
			primera = i
			img = str(entradas[i].get("img", ""))
	if primera == -1:
		return {"ok": false, "img": "", "clave": clave}
	var removidas := 0
	for i in range(entradas.size() - 1, -1, -1):
		if not _coincide(entradas[i], url, clave):
			continue
		entradas.remove_at(i)
		removidas += 1
	return {"ok": true, "img": img, "clave": clave, "eliminadas": removidas}


func _coincide(entrada: Variant, url: String, clave: String) -> bool:
	if typeof(entrada) != TYPE_DICTIONARY:
		return false
	return str(entrada.get("url", "")) == url or GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))) == clave


func es_captura_propia(ruta: String, assets_base: String) -> bool:
	return RutasScript.en_base(ruta, assets_base)


func borrar_captura_si_huerfana(entradas: Array, ruta: String, assets_base: String) -> bool:
	if ruta.is_empty() or not es_captura_propia(ruta, assets_base):
		return false
	if ruta.get_file() in GestorImagenesScript.ARCHIVOS_FIJOS:
		return false
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("img", "")) == ruta:
			return false
	GestorImagenesScript.borrar(ruta)
	return true


func _renombrar_clave(estados: Dictionary, borrados: Array, url_original: String, url_nueva: String) -> Array:
	var clave_original := GestorCatalogoScript.clave_unica(url_original)
	var clave_nueva := GestorCatalogoScript.clave_unica(url_nueva)
	if estados.has(clave_original):
		estados[clave_nueva] = estados[clave_original]
		estados.erase(clave_original)
	for i in range(borrados.size()):
		if str(borrados[i]) == clave_original:
			borrados[i] = clave_nueva
	return [clave_original, clave_nueva]
