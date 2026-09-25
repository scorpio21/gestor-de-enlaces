extends SceneTree

const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")
const BASE := "user://__test_gestor_imagenes__"
const ASSETS := BASE + "/Assets"
const CARPETA_PNG := ASSETS + "/png"
const CARPETA_JPG := ASSETS + "/jpg"

var _fallos := 0


func _initialize() -> void:
	_limpiar_base()
	_arrancar()
	_limpiar_base()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)

	var origen := BASE + "/origen.png"
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.GREEN)
	img.save_png(origen)

	var r1: Dictionary = GestorImagenesScript.copiar(origen, "", ASSETS)
	_check(r1.get("ok", false), "copiar una imagen válida devuelve ok")
	var destino := str(r1.get("destino", ""))
	_check(destino.begins_with(CARPETA_PNG + "/img_") and destino.ends_with(".png"), "el destino es un png en Assets/png")
	_check(FileAccess.file_exists(destino), "el archivo destino existe en disco")
	if FileAccess.file_exists(destino):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino))

	var d1: Dictionary = GestorImagenesScript.copiar(origen, "", ASSETS)
	var dest_d1 := str(d1.get("destino", ""))
	var fichas_antes := _contar_img(CARPETA_PNG, ".png")
	var d2: Dictionary = GestorImagenesScript.copiar(origen, "", ASSETS)
	_check(d1.get("ok", false) and not d1.get("reutilizada", false), "copiar crea la captura sin marcar reutilizada")
	_check(d2.get("ok", false) and d2.get("reutilizada", false) and str(d2.get("destino", "")) == dest_d1, "copiar la misma imagen reutiliza la captura existente")
	_check(_contar_img(CARPETA_PNG, ".png") == fichas_antes, "reutilizar no añade un archivo duplicado")
	if FileAccess.file_exists(dest_d1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dest_d1))
	var origen_otra := BASE + "/otra.png"
	var img_otra := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img_otra.fill(Color.BLUE)
	img_otra.save_png(origen_otra)
	var d3: Dictionary = GestorImagenesScript.copiar(origen_otra, "", ASSETS)
	_check(d3.get("ok", false) and not d3.get("reutilizada", true) and _contar_img(CARPETA_PNG, ".png") == fichas_antes, "una imagen distinta crea su propia captura")
	if FileAccess.file_exists(str(d3.get("destino", ""))):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(d3.get("destino", ""))))

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
	var rg := GestorImagenesScript.copiar(origen_grande, "", ASSETS)
	var leida_g: Image = Image.load_from_file(str(rg.get("destino", "")))
	_check(rg.get("ok", false) and not leida_g.is_empty() and leida_g.get_width() <= 800 and leida_g.get_width() > 0, "copiar reduce la imagen a máximo 800 px de ancho")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(rg.get("destino", ""))))

	var rs := GestorImagenesScript.copiar(origen, "", ASSETS)
	var leida_s: Image = Image.load_from_file(str(rs.get("destino", "")))
	_check(rs.get("ok", false) and leida_s.get_width() == 4, "copiar conserva el tamaño de imágenes pequeñas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(rs.get("destino", ""))))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA_PNG))
	var lt1 := CARPETA_PNG + "/img_test_lt1.png"
	var lt2 := CARPETA_PNG + "/img_test_lt2.png"
	var img_t := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img_t.fill(Color.ORANGE)
	img_t.save_png(ProjectSettings.globalize_path(lt1))
	img_t.save_png(ProjectSettings.globalize_path(lt2))
	var rl := GestorImagenesScript.limpiar_huerfanas([lt1], ASSETS)
	_check(rl.get("ok", false) and int(rl.get("borradas", -1)) == 1 and int(rl.get("errores", -1)) == 0 and not FileAccess.file_exists(ProjectSettings.globalize_path(lt2)) and FileAccess.file_exists(ProjectSettings.globalize_path(lt1)), "limpiar_huerfanas borra solo las no referidas")
	img_t.save_png(ProjectSettings.globalize_path(lt2))
	var rl2 := GestorImagenesScript.limpiar_huerfanas([lt1, lt2], ASSETS)
	_check(rl2.get("ok", false) and int(rl2.get("borradas", -1)) == 0 and FileAccess.file_exists(ProjectSettings.globalize_path(lt1)) and FileAccess.file_exists(ProjectSettings.globalize_path(lt2)), "limpiar_huerfanas conserva las referidas")
	var txt := ProjectSettings.globalize_path(CARPETA_PNG + "/nota_limpieza.txt")
	var f := FileAccess.open(txt, FileAccess.WRITE)
	if f:
		f.store_string("x")
		f.close()
	var rl3 := GestorImagenesScript.limpiar_huerfanas([lt1, lt2], ASSETS)
	_check(rl3.get("ok", false) and FileAccess.file_exists(txt) and int(rl3.get("borradas", -1)) == 0 and int(rl3.get("errores", -1)) == 0, "limpiar_huerfanas ignora no-img_ y reporta contadores enteros")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lt1))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lt2))
	DirAccess.remove_absolute(txt)

	# Capturas con el nombre del enlace (#47)
	var rn1: Dictionary = GestorImagenesScript.copiar(origen, "BowAO (Cliente)", ASSETS)
	var destino_n1 := str(rn1.get("destino", ""))
	_check(rn1.get("ok", false) and destino_n1 == CARPETA_PNG + "/BowAO (Cliente).png", "copiar con nombre guarda la captura con el nombre del enlace")
	_check(FileAccess.file_exists(destino_n1), "la captura nombrada existe en disco")

	var rn2: Dictionary = GestorImagenesScript.copiar(origen_otra, "Bow/AO*Infernus?", ASSETS)
	_check(str(rn2.get("destino", "")) == CARPETA_PNG + "/Bow_AO_Infernus.png", "copiar limpia los caracteres no válidos del nombre")

	var rn_reuso: Dictionary = GestorImagenesScript.copiar(origen, "Otro Nombre", ASSETS)
	_check(rn_reuso.get("reutilizada", false) and str(rn_reuso.get("destino", "")) == destino_n1, "copiar la misma imagen con otro nombre reutiliza la captura existente")

	var origen_colision := BASE + "/colision.png"
	var img_c := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img_c.fill(Color.YELLOW)
	img_c.save_png(origen_colision)
	var rc1: Dictionary = GestorImagenesScript.copiar(origen_colision, "BowAO (Cliente)", ASSETS)
	_check(str(rc1.get("destino", "")) == CARPETA_PNG + "/BowAO (Cliente)-1.png", "mismo nombre con otra imagen añade sufijo numérico")

	var origen_sin := BASE + "/sin-nombre.png"
	var img_sn := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img_sn.fill(Color.MAGENTA)
	img_sn.save_png(origen_sin)
	var rvacio: Dictionary = GestorImagenesScript.copiar(origen_sin, "   ", ASSETS)
	var destino_vacio := str(rvacio.get("destino", ""))
	_check(destino_vacio.begins_with(CARPETA_PNG + "/img_") and destino_vacio.ends_with(".png"), "sin nombre útil se cae al patrón img_<ts>")

	var origen_largo := BASE + "/largo.png"
	var img_lg := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img_lg.fill(Color.PURPLE)
	img_lg.save_png(origen_largo)
	var rlargo: Dictionary = GestorImagenesScript.copiar(origen_largo, "Titulo" + "Largo".repeat(20), ASSETS)
	_check(str(rlargo.get("destino", "")).get_file().get_basename().length() <= 60, "un nombre largo se recorta a 60 caracteres")

	# Limpieza con archivos con nombre (#47)
	var basura := CARPETA_PNG + "/Basura.png"
	var img_bas := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img_bas.fill(Color.WHITE)
	img_bas.save_png(ProjectSettings.globalize_path(basura))
	var fijo := CARPETA_PNG + "/no-disponible.png"
	var img_fijo := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img_fijo.fill(Color.BLACK)
	img_fijo.save_png(ProjectSettings.globalize_path(fijo))
	var rl_n: Dictionary = GestorImagenesScript.limpiar_huerfanas([destino_n1], ASSETS)
	_check(rl_n.get("ok", false) and not FileAccess.file_exists(basura) and FileAccess.file_exists(fijo) and FileAccess.file_exists(destino_n1), "limpiar_huerfanas borra capturas con nombre no referidas, conserva las referidas y los fijos")
	if FileAccess.file_exists(destino_n1):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_n1))
	if FileAccess.file_exists(fijo):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fijo))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA_JPG))
	var origen_jpg := BASE + "/origen.jpg"
	var img_j := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img_j.fill(Color.VIOLET)
	img_j.save_jpg(origen_jpg, 0.9)
	var rj: Dictionary = GestorImagenesScript.copiar(origen_jpg, "", ASSETS)
	var destino_j := str(rj.get("destino", ""))
	_check(rj.get("ok", false) and destino_j.begins_with(CARPETA_JPG + "/img_") and destino_j.ends_with(".jpg"), "copiar jpg guarda en Assets/jpg con extensión .jpg")
	_check(FileAccess.file_exists(destino_j) and not Image.load_from_file(destino_j).is_empty(), "el jpg copiado existe y se decodifica")
	if FileAccess.file_exists(destino_j):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_j))

	var origen_jpeg := BASE + "/origen.jpeg"
	img_j.save_jpg(origen_jpeg, 0.9)
	var rjpeg: Dictionary = GestorImagenesScript.copiar(origen_jpeg, "", ASSETS)
	_check(str(rjpeg.get("destino", "")).begins_with(CARPETA_JPG + "/img_") and str(rjpeg.get("destino", "")).ends_with(".jpg"), "copiar jpeg también termina en .jpg")
	var destino_jp := str(rjpeg.get("destino", ""))
	if FileAccess.file_exists(destino_jp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_jp))

	var origen_webp := BASE + "/origen.webp"
	img_j.save_webp(origen_webp, false)
	var rw: Dictionary = GestorImagenesScript.copiar(origen_webp, "", ASSETS)
	var destino_w := str(rw.get("destino", ""))
	_check(rw.get("ok", false) and destino_w.begins_with(CARPETA_PNG + "/img_") and destino_w.ends_with(".png") and not Image.load_from_file(destino_w).is_empty(), "copiar webp lo reconvierte a png en Assets/png")
	if FileAccess.file_exists(destino_w):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_w))

	var r_ext: Dictionary = GestorImagenesScript.copiar(BASE + "/origen.gif")
	_check(not r_ext.get("ok", true) and str(r_ext.get("error", "")).contains("Formato no soportado."), "extensión desconocida no se copia")

	var jpg_ref := CARPETA_JPG + "/img_test_ref.jpg"
	var jpg_huerfana := CARPETA_JPG + "/img_test_huerfana.jpg"
	img_j.save_jpg(ProjectSettings.globalize_path(jpg_ref), 0.9)
	img_j.save_jpg(ProjectSettings.globalize_path(jpg_huerfana), 0.9)
	var rl_j := GestorImagenesScript.limpiar_huerfanas([jpg_ref], ASSETS)
	_check(rl_j.get("ok", false) and int(rl_j.get("borradas", -1)) == 1 and FileAccess.file_exists(ProjectSettings.globalize_path(jpg_ref)) and not FileAccess.file_exists(ProjectSettings.globalize_path(jpg_huerfana)), "limpiar_huerfanas elimina la jpg no referida y conserva la referida")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(jpg_ref))

	var rj_named: Dictionary = GestorImagenesScript.copiar(origen_jpg, "Juego", ASSETS)
	_check(str(rj_named.get("destino", "")) == CARPETA_JPG + "/Juego.jpg", "copiar jpg con nombre guarda Juego.jpg")

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _limpiar_base() -> void:
	var abs := ProjectSettings.globalize_path(BASE)
	if not DirAccess.dir_exists_absolute(abs):
		return
	var dir := DirAccess.open(abs)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	for s in dir.get_directories():
		_borrar_arbol(abs.path_join(s))
	DirAccess.remove_absolute(abs)


func _borrar_arbol(abs: String) -> void:
	var dir := DirAccess.open(abs)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	for s in dir.get_directories():
		_borrar_arbol(abs.path_join(s))
	DirAccess.remove_absolute(abs)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _contar_img(carpeta: String, sufijo: String) -> int:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return 0
	var n := 0
	for f in dir.get_files():
		if f.begins_with("img_") and f.ends_with(sufijo):
			n += 1
	return n