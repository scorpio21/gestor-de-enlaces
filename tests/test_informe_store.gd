extends SceneTree

const InformeStoreScript := preload("res://scripts/informe_store.gd")
const BASE := "user://__test_informe__"
const RUTA_CSV := BASE + "/informe.csv"
const RUTA_HTML := BASE + "/informe.html"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	var filas := [
		{"nombre": "A", "url": "https://a.test", "estado": "Válido", "fecha": 0, "causa": "Correcto", "mensaje": "OK (200)"},
		{"nombre": "B", "url": "https://b.test", "estado": "Caído", "fecha": 1600000000, "causa": "Página inexistente", "mensaje": "Hola; \"mundo\""},
		{"nombre": "C", "url": "https://c.test", "estado": "Sin comprobar", "fecha": 0, "causa": "Sin respuesta (red)", "mensaje": "<script>alert(1)</script>"},
	]

	var re_csv := InformeStoreScript.exportar_csv(RUTA_CSV, filas)
	_check(re_csv.get("ok", false) and int(re_csv.get("total", -1)) == 3, "exportar_csv escribe y cuenta filas")
	var texto_csv := FileAccess.get_file_as_string(RUTA_CSV)
	_check(texto_csv.begins_with("Nombre;URL;Estado;Fecha;Causa;Mensaje\n"), "CSV tiene la cabecera Nombre;URL;Estado;Fecha;Causa;Mensaje (#54)")
	_check(texto_csv.contains("\nA;https://a.test;Válido;;Correcto;OK (200)\n"), "CSV fila válida con fecha 0 deja Fecha vacío")
	_check(texto_csv.contains("\nB;https://b.test;Caído;2020-09-13 12:26;Página inexistente;"), "CSV fila caída formatea la fecha")
	_check(texto_csv.contains("\"Hola; \"\"mundo\"\"\""), "CSV escapa el separador y las comillas dobles")
	_check(texto_csv.contains("\nC;https://c.test;Sin comprobar;;Sin respuesta (red);<script>alert(1)</script>\n"), "CSV conserva el texto plano del mensaje")
	_check(texto_csv.contains("\n\nResumen por causa\nPágina inexistente;1\nSin respuesta (red);1\n"), "CSV añade el resumen por causa sin contar los válidos (#54)")

	var re_html := InformeStoreScript.exportar_html(RUTA_HTML, filas)
	_check(re_html.get("ok", false) and int(re_html.get("total", -1)) == 3, "exportar_html escribe y cuenta filas")
	var texto_html := FileAccess.get_file_as_string(RUTA_HTML)
	_check(texto_html.contains("<!DOCTYPE html>") and texto_html.contains("<meta charset=\"utf-8\">"), "HTML es un documento autocontenido con charset utf-8")
	_check(texto_html.contains("<table>") and texto_html.contains("</table>"), "HTML contiene una tabla")
	_check(texto_html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"), "HTML escapa etiquetas del mensaje")
	_check(texto_html.contains("class=\"caido\""), "HTML usa la clase de fila caída")
	_check(texto_html.contains("class=\"valido\"") and texto_html.contains("class=\"sincomprobar\""), "HTML usa las clases de válido y sin comprobar")
	_check(texto_html.contains("<th>Estado</th>") and texto_html.contains("<th>Nombre</th>"), "HTML contiene la cabecera de la tabla")
	_check(texto_html.contains("<th>Causa</th>"), "HTML añade la columna Causa (#54)")
	_check(texto_html.contains("<h2>Resumen por causa</h2>") and texto_html.contains("<li>Sin respuesta (red): 1</li>"), "HTML añade el resumen por causa (#54)")
	_check(texto_html.find("<h2>Resumen por causa</h2>") < texto_html.find("<table>"), "el resumen por causa va antes de la tabla (#54)")

	_ayudas()

	var re_err := InformeStoreScript.exportar_csv(BASE + "/nohay/x.csv", [])
	_check(not re_err.get("ok", true) and not str(re_err.get("error", "")).is_empty(), "exportar_csv a una carpeta inexistente falla con error")

	DirAccess.remove_absolute(RUTA_CSV)
	DirAccess.remove_absolute(RUTA_HTML)
	DirAccess.remove_absolute(BASE)
	_cerrar()


func _ayudas() -> void:
	_check(InformeStoreScript.estado_texto({"valido": true}) == "Válido", "estado_texto distingue válido")
	_check(InformeStoreScript.estado_texto({"valido": false}) == "Caído", "estado_texto distingue caído")
	_check(InformeStoreScript.estado_texto({"valido": null}) == "Sin comprobar", "estado_texto distingue sin comprobar (#54)")
	_check(InformeStoreScript.estado_texto({}) == "Sin comprobar", "estado_texto sin datos es sin comprobar")

	_check(InformeStoreScript.causa_texto({"valido": true}) == "Correcto", "causa_texto de un válido es Correcto")
	_check(InformeStoreScript.causa_texto({"valido": true, "motivo": "tls"}) == "Certificado no válido (aceptado)", "causa_texto avisa del certificado aceptado (#56)")
	_check(InformeStoreScript.causa_texto({"valido": false, "motivo": "tls"}) == "Certificado no válido (rechazado)", "causa_texto avisa del certificado rechazado (#56)")
	_check(InformeStoreScript.causa_texto({"valido": null, "motivo": "red"}) == "Sin comprobar", "causa_texto prioriza el estado sin comprobar (#54)")
	_check(InformeStoreScript.causa_texto({"valido": false, "motivo": "red"}) == "Sin respuesta (red)", "causa_texto traduce el motivo de red")
	_check(InformeStoreScript.causa_texto({"valido": false, "motivo": "http", "codigo": 503}) == "Error HTTP 503", "causa_texto añade el código HTTP (#54)")
	_check(InformeStoreScript.causa_texto({"valido": false, "motivo": "muerto"}) == "Página inexistente", "causa_texto traduce el motivo de página inexistente")
	_check(InformeStoreScript.causa_texto({"valido": false, "motivo": "raro"}) == "Otro", "causa_texto cae en Otro para motivos desconocidos")

	var resumen: Array = InformeStoreScript.resumen_por_causa([
		{"estado": "Válido", "causa": "Correcto"},
		{"estado": "Caído", "causa": "Página inexistente"},
		{"estado": "Caído", "causa": "Página inexistente"},
		{"estado": "Sin comprobar", "causa": ""},
		"basura",
	])
	_check(resumen.size() == 2, "resumen_por_causa agrupa y descarta lo que no es fila")
	_check(str(resumen[0]["causa"]) == "Página inexistente" and int(resumen[0]["total"]) == 2, "resumen_por_causa ordena por número de enlaces")
	_check(str(resumen[1]["causa"]) == "Sin comprobar" and int(resumen[1]["total"]) == 1, "resumen_por_causa nombra la causa vacía")
	_check(InformeStoreScript.resumen_por_causa([]) == [], "resumen_por_causa sin filas devuelve lista vacía")


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)