extends RefCounted

const InformeStoreScript := preload("res://scripts/informe_store.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")


static func filas(entradas: Array, estados: Dictionary, solo_urls := []) -> Array:
	var filtro: Array = []
	var hay_filtro := not solo_urls.is_empty()
	for url in solo_urls:
		filtro.append(str(url))
	var resultado: Array = []
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var url := str(entrada.get("url", ""))
		if url.is_empty():
			continue
		if hay_filtro and not filtro.has(url):
			continue
		var estado: Dictionary = estados.get(GestorCatalogoScript.clave_unica(url), {})
		var fila := {
			"nombre": str(entrada.get("nombre", "")),
			"url": url,
			"estado": TranslationServer.translate("Sin comprobar"),
			"fecha": 0,
			"mensaje": "",
			"causa": "",
		}
		if not estado.is_empty():
			fila["estado"] = InformeStoreScript.estado_texto(estado)
			fila["fecha"] = int(estado.get("fecha", 0))
			fila["mensaje"] = str(estado.get("mensaje", ""))
			fila["causa"] = InformeStoreScript.causa_texto(estado)
		resultado.append(fila)
	return resultado


static func exportar(ruta: String, formato: String, filas: Array) -> Dictionary:
	var final := ruta
	if not final.to_lower().ends_with(".csv") and not final.to_lower().ends_with(".html"):
		final += ".csv"
	var res: Dictionary = InformeStoreScript.exportar_html(final, filas) \
		if formato == "html" else InformeStoreScript.exportar_csv(final, filas)
	res["ruta"] = final
	return res


static func formato_de(ruta: String) -> String:
	return "html" if ruta.to_lower().ends_with(".html") else "csv"