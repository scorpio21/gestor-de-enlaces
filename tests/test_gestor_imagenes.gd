extends SceneTree

const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")
const BASE := "user://__test_gestor_imagenes__"
const CARPETA_PNG := "res://Assets/png"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)

	var origen := BASE + "/origen.png"
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.GREEN)
	img.save_png(origen)

	var r1: Dictionary = GestorImagenesScript.copiar(origen)
	_check(r1.get("ok", false), "copiar una imagen válida devuelve ok")
	var destino := str(r1.get("destino", ""))
	_check(destino.begins_with(CARPETA_PNG + "/img_") and destino.ends_with(".png"), "el destino es un png en Assets/png")
	_check(FileAccess.file_exists(destino), "el archivo destino existe en disco")
	if FileAccess.file_exists(destino):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino))

	var r2: Dictionary = GestorImagenesScript.copiar(BASE + "/no-existe.png")
	_check(not r2.get("ok", true), "copiar un origen inexistente falla")

	var r3: Dictionary = GestorImagenesScript.copiar("")
	_check(r3.get("ok", false) and str(r3.get("destino", "X")) == "", "sin imagen devuelve ok con destino vacío")

	var a_borrar := BASE + "/a-borrar.png"
	var img_b := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img_b.fill(Color.RED)
	img_b.save_png(a_borrar)
	var rb := GestorImagenesScript.borrar(a_borrar)
	_check(rb.get("ok", false) and not FileAccess.file_exists(a_borrar), "borrar elimina el archivo real")
	_check(FileAccess.file_exists(BASE + "/origen.png"), "borrar no afecta a otros archivos")
	_check(not GestorImagenesScript.borrar("").get("ok", true), "borrar con ruta vacía devuelve fallo")

	var origen_grande := BASE + "/grande.png"
	var img_g := Image.create_empty(1200, 600, false, Image.FORMAT_RGBA8)
	img_g.fill(Color.CYAN)
	img_g.save_png(origen_grande)
	var rg := GestorImagenesScript.copiar(origen_grande)
	var leida_g: Image = Image.load_from_file(str(rg.get("destino", "")))
	_check(rg.get("ok", false) and not leida_g.is_empty() and leida_g.get_width() <= 800 and leida_g.get_width() > 0, "copiar reduce la imagen a máximo 800 px de ancho")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(rg.get("destino", ""))))

	var rs := GestorImagenesScript.copiar(BASE + "/origen.png")
	var leida_s: Image = Image.load_from_file(str(rs.get("destino", "")))
	_check(rs.get("ok", false) and leida_s.get_width() == 4, "copiar conserva el tamaño de imágenes pequeñas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(rs.get("destino", ""))))

	var img_t := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img_t.fill(Color.ORANGE)
	var lt1 := "res://Assets/png/img_test_lt1.png"
	var lt2 := "res://Assets/png/img_test_lt2.png"
	img_t.save_png(ProjectSettings.globalize_path(lt1))
	img_t.save_png(ProjectSettings.globalize_path(lt2))
	var rl := GestorImagenesScript.limpiar_huerfanas([lt1])
	_check(rl.get("ok", false) and int(rl.get("borradas", -1)) == 1 and int(rl.get("errores", -1)) == 0 and not FileAccess.file_exists(ProjectSettings.globalize_path(lt2)) and FileAccess.file_exists(ProjectSettings.globalize_path(lt1)), "limpiar_huerfanas borra solo las no referidas")
	img_t.save_png(ProjectSettings.globalize_path(lt2))
	var rl2 := GestorImagenesScript.limpiar_huerfanas([lt1, lt2])
	_check(rl2.get("ok", false) and int(rl2.get("borradas", -1)) == 0 and FileAccess.file_exists(ProjectSettings.globalize_path(lt1)) and FileAccess.file_exists(ProjectSettings.globalize_path(lt2)), "limpiar_huerfanas conserva las referidas")
	var txt := ProjectSettings.globalize_path("res://Assets/png/nota_limpieza.txt")
	var f := FileAccess.open(txt, FileAccess.WRITE)
	if f:
		f.store_string("x")
		f.close()
	var rl3 := GestorImagenesScript.limpiar_huerfanas([lt1, lt2])
	_check(rl3.get("ok", false) and FileAccess.file_exists(txt) and int(rl3.get("borradas", -1)) == 0 and int(rl3.get("errores", -1)) == 0, "limpiar_huerfanas ignora no-img_ y reporta contadores enteros")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lt1))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lt2))
	DirAccess.remove_absolute(txt)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Assets/jpg"))
	var origen_jpg := BASE + "/origen.jpg"
	var img_j := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img_j.fill(Color.VIOLET)
	img_j.save_jpg(origen_jpg, 0.9)
	var rj: Dictionary = GestorImagenesScript.copiar(origen_jpg)
	var destino_j := str(rj.get("destino", ""))
	_check(rj.get("ok", false) and destino_j.begins_with("res://Assets/jpg/img_") and destino_j.ends_with(".jpg"), "copiar jpg guarda en Assets/jpg con extensión .jpg")
	_check(FileAccess.file_exists(destino_j) and not Image.load_from_file(destino_j).is_empty(), "el jpg copiado existe y se decodifica")
	if FileAccess.file_exists(destino_j):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_j))

	var origen_jpeg := BASE + "/origen.jpeg"
	img_j.save_jpg(origen_jpeg, 0.9)
	var rjpeg: Dictionary = GestorImagenesScript.copiar(origen_jpeg)
	_check(str(rjpeg.get("destino", "")).begins_with("res://Assets/jpg/img_") and str(rjpeg.get("destino", "")).ends_with(".jpg"), "copiar jpeg también termina en .jpg")
	var destino_jp := str(rjpeg.get("destino", ""))
	if FileAccess.file_exists(destino_jp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_jp))

	var origen_webp := BASE + "/origen.webp"
	img_j.save_webp(origen_webp, false)
	var rw: Dictionary = GestorImagenesScript.copiar(origen_webp)
	var destino_w := str(rw.get("destino", ""))
	_check(rw.get("ok", false) and destino_w.begins_with("res://Assets/png/img_") and destino_w.ends_with(".png") and not Image.load_from_file(destino_w).is_empty(), "copiar webp lo reconvierte a png en Assets/png")
	if FileAccess.file_exists(destino_w):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_w))

	var r_ext: Dictionary = GestorImagenesScript.copiar(BASE + "/origen.gif")
	_check(not r_ext.get("ok", true) and str(r_ext.get("error", "")).contains("Formato no soportado."), "extensión desconocida no se copia")

	var jpg_ref := "res://Assets/jpg/img_test_ref.jpg"
	var jpg_huerfana := "res://Assets/jpg/img_test_huerfana.jpg"
	img_j.save_jpg(ProjectSettings.globalize_path(jpg_ref), 0.9)
	img_j.save_jpg(ProjectSettings.globalize_path(jpg_huerfana), 0.9)
	var rl_j := GestorImagenesScript.limpiar_huerfanas([jpg_ref])
	_check(rl_j.get("ok", false) and int(rl_j.get("borradas", -1)) == 1 and FileAccess.file_exists(ProjectSettings.globalize_path(jpg_ref)) and not FileAccess.file_exists(ProjectSettings.globalize_path(jpg_huerfana)), "limpiar_huerfanas elimina la jpg no referida y conserva la referida")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(jpg_ref))

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
