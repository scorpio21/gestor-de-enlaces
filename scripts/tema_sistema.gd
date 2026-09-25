extends RefCounted

const RESOLUCION_DEFAULT := "oscuro"
const MODOS := ["auto", "claro", "oscuro"]


static func soportado() -> bool:
	return DisplayServer.is_dark_mode_supported()


static func oscuro_detectado() -> bool:
	return DisplayServer.is_dark_mode()


static func resolver(modo: String, disponible: bool, oscuro: bool) -> String:
	if modo != "auto":
		return modo if MODOS.has(modo) else RESOLUCION_DEFAULT
	if not disponible:
		return RESOLUCION_DEFAULT
	return "oscuro" if oscuro else "claro"