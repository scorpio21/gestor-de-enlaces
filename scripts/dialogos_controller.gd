extends RefCounted

const SeleccionControllerScript := preload("res://scripts/seleccion_controller.gd")
const RedireccionesScript := preload("res://scripts/redirecciones.gd")

var _borrado_pendiente: Array = []
var _reubicar_pendiente: Array = []
var _limpieza_resultado: Dictionary = {}
var _aviso_modo := ""
var _aviso_version := ""
var _aviso_url := ""


func pedir_borrado(urls: Array, etiqueta := "") -> String:
	if urls.is_empty():
		return ""
	_borrado_pendiente = urls.duplicate()
	return SeleccionControllerScript.texto_eliminar(urls.size(), str(urls[0]), etiqueta)


func cancelar_borrado() -> void:
	_borrado_pendiente = []


func tomar_borrado() -> Array:
	var urls := _borrado_pendiente
	_borrado_pendiente = []
	return urls


func pendientes_borrado() -> Array:
	return _borrado_pendiente.duplicate()


func pedir_reubicar(urls: Array, entradas: Array, estados: Dictionary) -> String:
	_reubicar_pendiente = RedireccionesScript.reubicables_de(urls, estados)
	if _reubicar_pendiente.is_empty():
		return ""
	return RedireccionesScript.texto_confirmar(entradas, estados, _reubicar_pendiente)


func cancelar_reubicar() -> void:
	_reubicar_pendiente = []


func tomar_reubicar() -> Array:
	var urls := _reubicar_pendiente
	_reubicar_pendiente = []
	return urls


func pendientes_reubicar() -> Array:
	return _reubicar_pendiente.duplicate()


func guardar_limpieza(resultado: Dictionary) -> void:
	_limpieza_resultado = resultado


func tomar_limpieza() -> Dictionary:
	var resultado := _limpieza_resultado
	_limpieza_resultado = {}
	return resultado


static func resultado_actualizacion(
	resultado: Dictionary, manual: bool, ultima_vista: String, version_actual: String
) -> Dictionary:
	var nueva: bool = resultado.get("nueva") == true
	var version := str(resultado.get("version", ""))
	if nueva and version != ultima_vista:
		return {"modo": "nueva", "version": version, "url": str(resultado.get("url", ""))}
	if manual and not nueva and str(resultado.get("error", "")).is_empty():
		return {"modo": "al_dia", "version": version_actual, "url": ""}
	if manual:
		return {"modo": "error", "version": "", "url": ""}
	return {}


func aviso_actualizacion(modo: String, version: String, url: String) -> Dictionary:
	_aviso_modo = modo
	_aviso_version = version
	_aviso_url = url if modo == "nueva" else ""
	if modo == "nueva":
		return {
			"titulo": TranslationServer.translate("Nueva versión disponible"),
			"texto": TranslationServer.translate("Hay una nueva versión: %s") % version,
			"ok": TranslationServer.translate("Ver release"),
			"cancelar": true,
		}
	if modo == "al_dia":
		return {
			"titulo": TranslationServer.translate("Comprobar actualizaciones"),
			"texto": TranslationServer.translate("Estás al día (v%s)") % version,
			"ok": TranslationServer.translate("Cerrar"),
			"cancelar": false,
		}
	return {
		"titulo": TranslationServer.translate("Comprobar actualizaciones"),
		"texto": TranslationServer.translate("No se pudo comprobar actualizaciones."),
		"ok": TranslationServer.translate("Cerrar"),
		"cancelar": false,
	}


func con_aviso() -> bool:
	return _aviso_modo == "nueva"


func version_aviso() -> String:
	return _aviso_version


func url_aviso() -> String:
	return _aviso_url


func limpiar_aviso() -> void:
	_aviso_modo = ""
	_aviso_version = ""
	_aviso_url = ""
