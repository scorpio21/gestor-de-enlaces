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
