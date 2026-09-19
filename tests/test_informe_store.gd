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
		{"nombre": "A", "url": "https://a.test", "estado": "Válido", "fecha": 0, "mensaje": "OK (200)"},
		{"nombre": "B", "url": "https://b.test", "estado": "Caído", "fecha": 1600000000, "mensaje": "Hola; \"mundo\""},
		{"nombre": "C", "url": "https://c.test", "estado": "Sin comprobar", "fecha": 0, "mensaje": "<script>alert(1)</script>"},
	]

	var re_csv := InformeStoreScript.exportar_csv(RUTA_CSV, filas)
	_check(re_csv.get("ok", false) and int(re_csv.get("total", -1)) == 3, "exportar_csv escribe y cuenta filas")
	var texto_csv := FileAccess.get_file_as_string(RUTA_CSV)
	_check(texto_csv.begins_with("Nombre;URL;Estado;Fecha;Mensaje\n"), "CSV tiene la cabecera Nombre;URL;Estado;Fecha;Mensaje")
	_check(texto_csv.contains("\nA;https://a.test;Válido;;OK (200)\n"), "CSV fila válida con fecha 0 deja Fecha vacío")
	_check(texto_csv.contains("\nB;https://b.test;Caído;2020-09-13 12:26;"), "CSV fila caída formatea la fecha")
	_check(texto_csv.contains("\"Hola; \"\"mundo\"\"\""), "CSV escapa el separador y las comillas dobles")
	_check(texto_csv.contains("\nC;https://c.test;Sin comprobar;;<script>alert(1)</script>\n"), "CSV conserva el texto plano del mensaje")

	var re_html := InformeStoreScript.exportar_html(RUTA_HTML, filas)
	_check(re_html.get("ok", false) and int(re_html.get("total", -1)) == 3, "exportar_html escribe y cuenta filas")
	var texto_html := FileAccess.get_file_as_string(RUTA_HTML)
	_check(texto_html.contains("<!DOCTYPE html>") and texto_html.contains("<meta charset=\"utf-8\">"), "HTML es un documento autocontenido con charset utf-8")
	_check(texto_html.contains("<table>") and texto_html.contains("</table>"), "HTML contiene una tabla")
	_check(texto_html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"), "HTML escapa etiquetas del mensaje")
	_check(texto_html.contains("class=\"caido\""), "HTML usa la clase de fila caída")
	_check(texto_html.contains("class=\"valido\"") and texto_html.contains("class=\"sincomprobar\""), "HTML usa las clases de válido y sin comprobar")
	_check(texto_html.contains("<th>Estado</th>") and texto_html.contains("<th>Nombre</th>"), "HTML contiene la cabecera de la tabla")

	var re_err := InformeStoreScript.exportar_csv(BASE + "/nohay/x.csv", [])
	_check(not re_err.get("ok", true) and not str(re_err.get("error", "")).is_empty(), "exportar_csv a una carpeta inexistente falla con error")

	DirAccess.remove_absolute(RUTA_CSV)
	DirAccess.remove_absolute(RUTA_HTML)
	DirAccess.remove_absolute(BASE)
	_cerrar()


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