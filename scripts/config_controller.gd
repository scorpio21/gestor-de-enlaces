extends RefCounted

const CLAVES := [
	"paralelismo",
	"timeout",
	"auto_abrir",
	"intervalo",
	"tema",
	"ultima_version_vista",
	"orden_columna",
	"orden_direccion",
	"idioma",
	"filtro_estado",
	"filtro_categoria",
	"filtro_etiqueta",
	"busqueda",
	"filtro_codigo",
	"filtro_dias",
	"busqueda_modo",
	"vista",
	"reintentar_transitorios",
	"red_sin_comprobar",
	"aceptar_certificados",
]

func fusionar(base: Dictionary, cambios: Dictionary) -> Dictionary:
	var salida := base.duplicate()
	for clave in cambios:
		if not CLAVES.has(clave):
			continue
		salida[clave] = cambios[clave]
	return salida


func guardar(store, cambios: Dictionary) -> bool:
	if store == null:
		return false
	var cfg := fusionar(store.cargar(), cambios)
	var args: Array = []
	for clave in CLAVES:
		args.append(cfg.get(clave))
	return store.callv("guardar", args)
