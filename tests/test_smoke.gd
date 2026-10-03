extends SceneTree

const SmokeScript := preload("res://scripts/smoke.gd")
const BASE := "user://__test_smoke__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_pedido()
	_paso()
	_recursos()
	_escenas()
	_stores()
	_sonda()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _pedido() -> void:
	_check(not SmokeScript.pedido(PackedStringArray(["--headless"])), "sin el argumento no se arranca el smoke")
	_check(not SmokeScript.pedido(PackedStringArray()), "sin argumentos de usuario no se arranca el smoke")
	_check(SmokeScript.pedido(PackedStringArray(["--smoke"])), "con --smoke el binario se arranca a si mismo")
	_check(SmokeScript.pedido(PackedStringArray(["--otro", "--smoke", "--mas"])), "el argumento se busca en cualquier posicion")
	_check(SmokeScript.ARGUMENTO == "--smoke", "el argumento del smoke es --smoke")


func _paso() -> void:
	var res: Dictionary = SmokeScript.ejecutar()
	_check(bool(res.get("ok", false)), "el smoke pasa en un proyecto completo: %s" % str(res.get("fallos", [])))
	_check((res.get("lineas", []) as Array).size() >= 1, "el smoke dice algo aunque pase")


func _recursos() -> void:
	_check(SmokeScript.RECURSOS.size() >= 5, "el smoke mira varios recursos declarados")
	var res: Dictionary = SmokeScript.ejecutar(SmokeScript.ESCENAS, ["res://Assets/icon/icon.svg", "res://Assets/icon/que-no-existe.png"], SmokeScript.STORES)
	_check(not bool(res.get("ok", false)), "un recurso que no esta en el export tumba el smoke")
	var texto := str(res.get("fallos", []))
	_check(texto.contains("que-no-existe.png"), "el smoke dice que recurso falta: %s" % texto)


func _escenas() -> void:
	var res: Dictionary = SmokeScript.ejecutar(["res://scenes/Main.tscn", "res://scenes/NoExiste.tscn"], SmokeScript.RECURSOS, SmokeScript.STORES)
	_check(not bool(res.get("ok", false)), "una escena que no esta en el export tumba el smoke")
	# El mensaje importa: "falta la escena" viene del exists() previo, "no carga"
	# del load() posterior. Sin el exists() el smoke diria lo segundo y el que lee
	# el log no sabria si es que no entró en el pck o si se rompió al cargarlo.
	_check(str(res.get("fallos", [])).contains("falta la escena res://scenes/NoExiste.tscn"), "el smoke dice que escena falta y no que no carga: %s" % str(res.get("fallos", [])))
	_check(not str(res.get("fallos", [])).contains("Main.tscn"), "una escena que si esta bien no se cuenta como fallo")
	for ruta in SmokeScript.ESCENAS:
		_check(ResourceLoader.exists(ruta), "la escena que el smoke comprueba existe de verdad: %s" % ruta)


func _stores() -> void:
	var res: Dictionary = SmokeScript.ejecutar()
	_check(bool(res.get("ok", false)), "los stores que mira el smoke cargan de verdad")
	var nombres: Array = []
	for entrada in SmokeScript.STORES:
		nombres.append(str(entrada[0]))
	_check(nombres.has("estado") and nombres.has("config") and nombres.has("instantaneas"), "el smoke mira los stores con datos (#61)")
	for entrada in SmokeScript.STORES:
		var script = entrada[1]
		var store = script.new(BASE + "/" + str(entrada[0]))
		_check(store.has_method("cargar"), "el store %s se puede construir con base propia" % str(entrada[0]))
		_check(store.cargar() is Dictionary or store.cargar() is Array, "el store %s devuelve datos" % str(entrada[0]))
	# Un store que no se puede construir tiene que tumbar el smoke. Si _stores()
	# dejara de ejecutarse, este fallo pasaria desapercibido.
	var res_roto: Dictionary = SmokeScript.ejecutar(SmokeScript.ESCENAS, SmokeScript.RECURSOS, [["no-es-un-script", 42]])
	_check(not bool(res_roto.get("ok", false)), "un store que no existe tumba el smoke")
	_check(str(res_roto.get("fallos", [])).contains("no-es-un-script"), "el smoke dice que store falla: %s" % str(res_roto.get("fallos", [])))


func _sonda() -> void:
	# Una sonda en una carpeta que no existe no se puede escribir, y eso es justo
	# el sintoma de un user:// de solo lectura o metido dentro del pck.
	var res: Dictionary = SmokeScript.ejecutar(SmokeScript.ESCENAS, SmokeScript.RECURSOS, SmokeScript.STORES, "user://__no_existe__/%s" % SmokeScript.SONDA)
	_check(not bool(res.get("ok", false)), "una sonda que no se puede escribir tumba el smoke")
	_check(str(res.get("fallos", [])).contains("no se puede escribir en user://"), "el smoke dice que user:// no se puede escribir: %s" % str(res.get("fallos", [])))
	var ok: Dictionary = SmokeScript.ejecutar()
	_check(bool(ok.get("ok", false)), "el smoke vuelve a pasar con la sonda de verdad")
	_check(not FileAccess.file_exists(SmokeScript.SONDA), "la sonda de user:// se borra al terminar")


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("OK   %s" % etiqueta)
		return
	_fallos += 1
	print("FALLO: %s" % etiqueta)
