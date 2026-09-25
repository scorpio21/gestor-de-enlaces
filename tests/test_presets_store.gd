extends SceneTree

const PresetsStore := preload("res://scripts/presets_store.gd")
const BASE := "user://__test_presets_store__"

var _fallos := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	_limpiar()
	_check(sin_fichero(), "sin fichero devuelve dict vacío")
	_check(json_roto(), "JSON roto devuelve dict vacío")
	_check(config_faltante_defaults(), "config con claves faltantes rellena defaults")
	_check(config_desconocidas_descartadas(), "claves desconocidas se descartan")
	_check(config_tipos_incorrectos(), "tipos incorrectos normalizan a defaults")
	_check(nombre_ok_vacio(), "nombre vacío o de espacios no es válido")
	_check(nombre_ok_largo(), "nombre muy largo no es válido")
	_check(guardar_y_recuperar(), "guardar y cargar hacen roundtrip")
	_check(guardar_preset_nuevo(), "guardar_preset añade un preset")
	_check(guardar_preset_sobrescribe(), "guardar_preset sobrescribe el mismo nombre")
	_check(guardar_preset_invalido_no_cambia(), "guardar_preset inválido deja la lista intacta")
	_check(aplicar_preset_existe(), "aplicar_preset devuelve la config normalizada")
	_check(aplicar_preset_faltante(), "aplicar_preset con nombre desconocido devuelve vacío")
	_check(borrar_preset(), "borrar_preset elimina el preset")
	_check(borrar_preset_faltante(), "borrar_preset con nombre desconocido no cambia")
	_check(nombres_ordenados(), "nombres devuelve la lista ordenada")
	_check(max_presets_limite(), "no se añaden presets más allá del máximo")
	_check(cargar_filtra_nombres_invalidos(), "cargar descarta nombres inválidos")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func sin_fichero() -> bool:
	return PresetsStore.new(BASE).cargar().is_empty()


func json_roto() -> bool:
	FileAccess.open(BASE + "/presets_filtros.json", FileAccess.WRITE).store_string("{no es json")
	return PresetsStore.new(BASE).cargar().is_empty()


func config_faltante_defaults() -> bool:
	var n := PresetsStore.new(BASE).normalizar_config(_config_basica())
	return n.get("filtro_estado") == 2 and n.get("filtro_categoria") == 1 \
		and n.get("filtro_etiqueta") == "glaciar" and n.get("busqueda") == "srv" \
		and n.get("filtro_codigo") == "404" and n.get("filtro_dias") == 30 \
		and n.get("busqueda_modo") == "or"


func config_desconocidas_descartadas() -> bool:
	var n := PresetsStore.new(BASE).normalizar_config({"filtro_estado": 1, "otra": "x"})
	return not n.has("otra") and n.get("filtro_estado") == 1 \
		and n.get("filtro_dias") == 0 and n.get("busqueda") == ""


func config_tipos_incorrectos() -> bool:
	var n := PresetsStore.new(BASE).normalizar_config({"filtro_estado": "malo", "filtro_dias": -4, "busqueda_modo": "xor"})
	return n.get("filtro_estado") == 0 and n.get("filtro_dias") == 0 \
		and n.get("busqueda_modo") == "and" and n.get("filtro_codigo") == ""


func nombre_ok_vacio() -> bool:
	var store := PresetsStore.new(BASE)
	return not store.nombre_ok("") and not store.nombre_ok("   ") \
		and store.nombre_ok("Solo 404")


func nombre_ok_largo() -> bool:
	return not PresetsStore.new(BASE).nombre_ok("x".repeat(41))


func guardar_y_recuperar() -> bool:
	var store := PresetsStore.new(BASE)
	var presets := {"Solo 404": {"filtro_estado": 2, "filtro_codigo": "404", "filtro_dias": 30}}
	if not store.guardar(presets):
		return false
	var c := store.cargar()
	return c.has("Solo 404") and c.get("Solo 404").get("filtro_codigo") == "404" \
		and c.get("Solo 404").get("filtro_estado") == 2


func guardar_preset_nuevo() -> bool:
	var store := PresetsStore.new(BASE)
	var p := store.guardar_preset({}, "Nuevo", _config_basica())
	return p.has("Nuevo") and p.size() == 1 \
		and p.get("Nuevo").get("filtro_estado") == 2


func guardar_preset_sobrescribe() -> bool:
	var store := PresetsStore.new(BASE)
	var p := store.guardar_preset(store.guardar_preset({}, "A", {"filtro_estado": 1}), "A", {"filtro_estado": 3})
	return p.size() == 1 and p.get("A").get("filtro_estado") == 3


func guardar_preset_invalido_no_cambia() -> bool:
	var store := PresetsStore.new(BASE)
	var v := store.guardar_preset({}, "", _config_basica())
	var e := store.guardar_preset({}, "   ", _config_basica())
	return v.is_empty() and e.is_empty()


func aplicar_preset_existe() -> bool:
	var store := PresetsStore.new(BASE)
	var presets := store.guardar_preset({}, "Solo 404", {"filtro_codigo": "404"})
	var c := store.aplicar_preset(presets, "Solo 404")
	return not c.is_empty() and c.get("filtro_codigo") == "404" and c.get("filtro_estado") == 0 \
		and c.get("busqueda_modo") == "and"


func aplicar_preset_faltante() -> bool:
	return PresetsStore.new(BASE).aplicar_preset({}, "Nada").is_empty()


func borrar_preset() -> bool:
	var store := PresetsStore.new(BASE)
	var p := store.guardar_preset({}, "A", _config_basica())
	var q := store.borrar_preset(p, "A")
	return not q.has("A") and q.is_empty()


func borrar_preset_faltante() -> bool:
	var store := PresetsStore.new(BASE)
	var p := store.guardar_preset({}, "A", _config_basica())
	return store.borrar_preset(p, "Z") == p


func nombres_ordenados() -> bool:
	var store := PresetsStore.new(BASE)
	var p := store.guardar_preset({}, "zeta", _config_basica())
	p = store.guardar_preset(p, "alfa", _config_basica())
	p = store.guardar_preset(p, "medio", _config_basica())
	var lista := store.nombres(p)
	return lista == ["alfa", "medio", "zeta"]


func max_presets_limite() -> bool:
	var store := PresetsStore.new(BASE)
	var p := {}
	for i in range(store.MAX_PRESETS):
		p = store.guardar_preset(p, "P%d" % i, _config_basica())
	var antes := p.size()
	p = store.guardar_preset(p, "ultimo", _config_basica())
	return antes == store.MAX_PRESETS and p.size() == store.MAX_PRESETS \
		and not p.has("ultimo")


func cargar_filtra_nombres_invalidos() -> bool:
	FileAccess.open(BASE + "/presets_filtros.json", FileAccess.WRITE).store_string(
		'{"a": {"filtro_estado": 1}, " ": {"filtro_estado": 1}, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx": {"otra": 1}}'
	)
	var c := PresetsStore.new(BASE).cargar()
	return c.size() == 1 and c.has("a") and c.get("a").get("busqueda") == ""


func _config_basica() -> Dictionary:
	return {
		"filtro_estado": 2,
		"filtro_categoria": 1,
		"filtro_etiqueta": "glaciar",
		"busqueda": "srv",
		"filtro_codigo": "404",
		"filtro_dias": 30,
		"busqueda_modo": "or",
	}


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE + "/presets_filtros.json")