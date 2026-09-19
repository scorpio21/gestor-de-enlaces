class_name InformeStore
extends RefCounted


static func exportar_csv(ruta: String, filas: Array) -> Dictionary:
	var lineas := PackedStringArray(["Nombre;URL;Estado;Fecha;Mensaje"])
	for fila in filas:
		if typeof(fila) != TYPE_DICTIONARY:
			continue
		var f := fila as Dictionary
		lineas.append(
			_escape_csv(str(f.get("nombre", ""))) + ";" +
			_escape_csv(str(f.get("url", ""))) + ";" +
			_escape_csv(str(f.get("estado", ""))) + ";" +
			_escape_csv(_fecha_legible(int(f.get("fecha", 0)))) + ";" +
			_escape_csv(str(f.get("mensaje", "")))
		)
	return _escribir(ruta, "\n".join(lineas) + "\n", lineas.size() - 1)


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
		cuerpo += "<tr class=\"%s\"><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n" % [
			clase,
			_escape_html(str(f.get("nombre", ""))),
			_escape_html(str(f.get("url", ""))),
			_escape_html(estado),
			_escape_html(_fecha_legible(int(f.get("fecha", 0)))),
			_escape_html(str(f.get("mensaje", ""))),
		]
	var html := "<!DOCTYPE html>\n<html lang=\"es\">\n<head>\n<meta charset=\"utf-8\">\n" \
		+ "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" \
		+ "<title>Informe de disponibilidad</title>\n<style>\n" \
		+ "table{border-collapse:collapse;width:100%}\nth,td{border:1px solid #ddd;padding:6px 10px;text-align:left}\n" \
		+ "thead th{background:#eee}\n.valido{background:#e8f5e9}\n.caido{background:#ffebee}\n.sincomprobar{background:#f5f5f5}\n" \
		+ "</style>\n</head>\n<body>\n<h1>Informe de disponibilidad</h1>\n" \
		+ "<table>\n<thead><tr><th>Nombre</th><th>URL</th><th>Estado</th><th>Fecha</th><th>Mensaje</th></tr></thead>\n<tbody>\n" \
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