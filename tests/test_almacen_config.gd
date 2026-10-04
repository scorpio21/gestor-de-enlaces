extends SceneTree

const AlmacenConfig := preload("res://scripts/almacen_config.gd")
const AlmacenScript := preload("res://scripts/almacen.gd")

const BASE := "user://__test_almacen_cfg__"

var _fallos := 0


func _initialize() -> void:
	_limpiar()
	_check(sin_fichero_usa_defecto(), "sin almacenamiento.json se usan los valores por defecto (#63)")
	_check(lectura_de_fichero(), "se lee modo, base y ruta_bd del fichero (#63)")
	_check(modo_desconocido_cae_a_ficheros(), "un modo desconocido cae a ficheros y avisa (#63)")
	_check(json_roto_no_rompe(), "un almacenamiento.json corrupto no rompe y avisa (#63)")
	_check(ruta_invalida_cae_a_defecto(), "una base que no es ruta se ignora (#63)")
	_limpiar()
	_check(guardar_y_releer(), "guardar() deja el fichero y cargar() lo relee (#63)")
	_check(guardar_rechaza_modo_malo(), "guardar() con un modo inválido no escribe nada (#63)")
	_check(el_argumento_manda(), "--almacen=<ruta> manda sobre el fichero (#63)")
	_check(el_argumento_acepta_modo(), "--almacen=ficheros se acepta como modo (#63)")
	_check(argumento_ruta_mala_avisa(), "--almacen con una ruta imposible avisa y sigue (#63)")
	_check(barras_al_final(), "la base se normaliza con barra final (#63)")
	_check(el_fichero_no_se_muda(), "el fichero de configuración no va donde los datos (#63)")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _limpiar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	for sufijo in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s%s" % [BASE, AlmacenConfig.NOMBRE, sufijo]))


func _escribir(texto: String) -> void:
	var f := FileAccess.open("%s/%s" % [BASE, AlmacenConfig.NOMBRE], FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func _lector() -> AlmacenConfig:
	return AlmacenConfig.new(BASE, "%s/%s" % [BASE, AlmacenConfig.NOMBRE])


func sin_fichero_usa_defecto() -> bool:
	var cfg := _lector().cargar()
	return str(cfg["modo"]) == AlmacenScript.MODO_FICHEROS and str(cfg["base"]) == "user://" \
		and str(cfg["ruta_bd"]) == AlmacenScript.RUTA_BD_POR_DEFECTO \
		and int(cfg["esquema"]) == AlmacenConfig.ESQUEMA_ACTUAL \
		and str(cfg["origen"]) == "por defecto"


func lectura_de_fichero() -> bool:
	_escribir('{"modo": "ficheros", "base": "user://datos_mios", "ruta_bd": "user://mio.db", "esquema": 1}')
	var cfg := _lector().cargar()
	return str(cfg["base"]) == "user://datos_mios/" and str(cfg["ruta_bd"]) == "user://mio.db" \
		and str(cfg["origen"]) == "fichero"


func modo_desconocido_cae_a_ficheros() -> bool:
	_escribir('{"modo": "postgres", "base": "user://datos_mios"}')
	var lector := _lector()
	var cfg := lector.cargar()
	return str(cfg["modo"]) == AlmacenScript.MODO_FICHEROS \
		and str(cfg["base"]) == "user://datos_mios/" \
		and not lector.avisos.is_empty()


func json_roto_no_rompe() -> bool:
	_escribir("{esto no es json")
	var lector := _lector()
	var cfg := lector.cargar()
	return str(cfg["modo"]) == AlmacenScript.MODO_FICHEROS and str(cfg["base"]) == "user://" \
		and not lector.avisos.is_empty()


func ruta_invalida_cae_a_defecto() -> bool:
	_escribir('{"base": "no/es/una/ruta", "ruta_bd": ""}')
	var cfg := _lector().cargar()
	return str(cfg["base"]) == "user://" and str(cfg["ruta_bd"]) == AlmacenScript.RUTA_BD_POR_DEFECTO


func guardar_y_releer() -> bool:
	var res := _lector().guardar(AlmacenScript.MODO_FICHEROS, "user://otro.db")
	if not res.get("ok", false):
		return false
	var cfg := _lector().cargar()
	return str(cfg["ruta_bd"]) == "user://otro.db" \
		and int(cfg["esquema"]) == AlmacenConfig.ESQUEMA_ACTUAL


func guardar_rechaza_modo_malo() -> bool:
	_limpiar()
	var lector := _lector()
	var res := lector.guardar("inventado", "user://otro.db")
	return not res.get("ok", true) and str(res.get("error", "")) != "" \
		and not FileAccess.file_exists(lector.ruta)


func el_argumento_manda() -> bool:
	_escribir('{"base": "user://desde_fichero", "modo": "ficheros"}')
	var cfg := _lector().cargar(PackedStringArray(["--smoke", "--almacen=user://portable"]))
	return str(cfg["base"]) == "user://portable/" and str(cfg["origen"]) == "argumento"


func el_argumento_acepta_modo() -> bool:
	_escribir('{"base": "user://desde_fichero", "modo": "ficheros"}')
	var cfg := _lector().cargar(PackedStringArray(["--almacen=ficheros"]))
	return str(cfg["modo"]) == AlmacenScript.MODO_FICHEROS and str(cfg["origen"]) == "argumento"


func argumento_ruta_mala_avisa() -> bool:
	# "no/es/una/ruta" no vale: ni es user:// ni es absoluta. Ojo con una cosa
	# que parece obvious y no lo es: "\\algo" SI la acepta is_absolute_path(),
	# porque en Windows es drive-relativa.
	_escribir('{"base": "user://desde_fichero", "modo": "ficheros"}')
	var lector := _lector()
	var cfg := lector.cargar(PackedStringArray(["--almacen=no/es/una/ruta"]))
	return str(cfg["base"]) == "user://desde_fichero/" and not lector.avisos.is_empty()


func barras_al_final() -> bool:
	_escribir('{"base": "C:/datos", "ruta_bd": "C:/datos/x.db"}')
	var cfg := _lector().cargar()
	return str(cfg["base"]) == "C:/datos/" and str(cfg["ruta_bd"]) == "C:/datos/x.db"


func el_fichero_no_se_muda() -> bool:
	# El fichero que dice donde estan los datos tiene que quedarse en user://.
	# Si se moviera con ellos, al cambiar de sitio dejaria de haber forma de
	# saber cual era el sitio viejo, y los datos quedarian huerfanos.
	var lector := AlmacenConfig.new("user://otro_lugar")
	return str(lector.ruta) == "user://almacenamiento.json" and str(lector.base) == "user://otro_lugar"


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)