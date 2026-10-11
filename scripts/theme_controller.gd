extends RefCounted

const TemaStoreScript := preload("res://scripts/tema_store.gd")

var _raiz: Node = null
var _dashboard: Node = null


func _init(raiz: Node = null, dashboard: Node = null) -> void:
	_raiz = raiz
	_dashboard = dashboard


func aplicar_tema(cfg_tema: String) -> void:
	if _raiz == null:
		return
	TemaStoreScript.aplicar(cfg_tema, _raiz)
	if _dashboard != null:
		_dashboard.aplicar_paleta()


func conectar_cambio_tema(callback: Callable) -> void:
	if DisplayServer.is_dark_mode_supported():
		DisplayServer.set_system_theme_change_callback(callback)
