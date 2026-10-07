extends RefCounted

const CAUSAS := [
	["ok", "Correcto"],
	["red", "Sin respuesta (red)"],
	["dns", "Dominio no resuelto"],
	["tls", "Certificado no válido (rechazado)"],
	["http", "Error HTTP"],
	["muerto", "Página inexistente"],
	["url", "URL inválida"],
	["", "Sin comprobar"],
]


static func estado_texto(estado: Dictionary) -> String:
	if estado.get("valido") == true:
		return "Válido"
	if estado.get("valido") == false:
		return "Caído"
	return "Sin comprobar"


static func causa_texto(estado: Dictionary) -> String:
	if estado.get("valido") == true:
		return "Certificado no válido (aceptado)" if str(estado.get("motivo", "")) == "tls" else "Correcto"
	if estado.get("valido") == null:
		return "Sin comprobar"
	var motivo := str(estado.get("motivo", ""))
	for c in CAUSAS:
		if str(c[0]) == motivo and not motivo.is_empty():
			if motivo == "http":
				return "%s %d" % [str(c[1]), int(estado.get("codigo", 0))]
			return str(c[1])
	return "Otro"


static func resumen_por_causa(filas: Array) -> Array:
	var cuentas := {}
	for fila in filas:
		if typeof(fila) != TYPE_DICTIONARY:
			continue
		var f := fila as Dictionary
		if str(f.get("estado", "")) == "Válido":
			continue
		var causa := str(f.get("causa", ""))
		if causa.is_empty():
			causa = "Sin comprobar"
		cuentas[causa] = int(cuentas.get(causa, 0)) + 1
	var lista: Array = []
	for causa in cuentas.keys():
		lista.append({"causa": str(causa), "total": int(cuentas[causa])})
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["total"]) == int(b["total"]):
			return str(a["causa"]) < str(b["causa"])
		return int(a["total"]) > int(b["total"])
	)
	return lista


static func exportar_csv(ruta: String, filas: Array) -> Dictionary:
	var lineas := PackedStringArray(["Nombre;URL;Estado;Fecha;Causa;Mensaje"])
	for fila in filas:
		if typeof(fila) != TYPE_DICTIONARY:
			continue
		var f := fila as Dictionary
		lineas.append(
			_escape_csv(str(f.get("nombre", ""))) + ";" +
			_escape_csv(str(f.get("url", ""))) + ";" +
			_escape_csv(str(f.get("estado", ""))) + ";" +
			_escape_csv(_fecha_legible(int(f.get("fecha", 0)))) + ";" +
			_escape_csv(str(f.get("causa", ""))) + ";" +
			_escape_csv(str(f.get("mensaje", "")))
		)
	var resumen := resumen_por_causa(filas)
	if not resumen.is_empty():
		lineas.append("")
		lineas.append("Resumen por causa")
		for r in resumen:
			lineas.append("%s;%d" % [_escape_csv(str(r["causa"])), int(r["total"])])
	return _escribir(ruta, "\n".join(lineas) + "\n", filas.size())


static func exportar_html(ruta: String, filas: Array) -> Dictionary:
	var cuerpo: String = ""
	for fila in filas:
		if typeof(fila) != TYPE_DICTIONARY:
			continue
		var f := fila as Dictionary
		var estado := str(f.get("estado", ""))
		var clase := "sincomprobar"
		if estado == "Válido":
			clase = "valido"
		elif estado == "Caído":
			clase = "caido"
		cuerpo += "<tr class=\"%s\"><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n" % [
			clase,
			_escape_html(str(f.get("nombre", ""))),
			_escape_html(str(f.get("url", ""))),
			_escape_html(estado),
			_escape_html(_fecha_legible(int(f.get("fecha", 0)))),
			_escape_html(str(f.get("causa", ""))),
			_escape_html(str(f.get("mensaje", ""))),
		]
	var resumen := ""
	var causas := resumen_por_causa(filas)
	if not causas.is_empty():
		resumen = "<h2>Resumen por causa</h2>\n<ul>\n"
		for r in causas:
			resumen += "<li>%s: %d</li>\n" % [_escape_html(str(r["causa"])), int(r["total"])]
		resumen += "</ul>\n"
	var html := "<!DOCTYPE html>\n<html lang=\"es\">\n<head>\n<meta charset=\"utf-8\">\n" \
		+ "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" \
		+ "<title>Informe de disponibilidad</title>\n<style>\n" \
		+ "table{border-collapse:collapse;width:100%}\nth,td{border:1px solid #ddd;padding:6px 10px;text-align:left}\n" \
		+ "thead th{background:#eee}\n.valido{background:#e8f5e9}\n.caido{background:#ffebee}\n.sincomprobar{background:#f5f5f5}\n" \
		+ "</style>\n</head>\n<body>\n<h1>Informe de disponibilidad</h1>\n" \
		+ resumen \
		+ "<table>\n<thead><tr><th>Nombre</th><th>URL</th><th>Estado</th><th>Fecha</th><th>Causa</th><th>Mensaje</th></tr></thead>\n<tbody>\n" \
		+ cuerpo + "</tbody>\n</table>\n</body>\n</html>\n"
	return _escribir(ruta, html, filas.size())


static func _escape_csv(valor: String) -> String:
	if valor.contains(";") or valor.contains("\"") or valor.contains("\n") or valor.contains("\r"):
		return "\"" + valor.replace("\"", "\"\"") + "\""
	return valor


static func _escape_html(valor: String) -> String:
	return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


static func _fecha_legible(unix: int) -> String:
	if unix <= 0:
		return ""
	var t := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d %02d:%02d" % [int(t.year), int(t.month), int(t.day), int(t.hour), int(t.minute)]


static func _escribir(ruta: String, contenido: String, total: int) -> Dictionary:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return {"ok": false, "error": "No se pudo escribir el archivo."}
	archivo.store_string(contenido)
	archivo.close()
	return {"ok": true, "total": total}