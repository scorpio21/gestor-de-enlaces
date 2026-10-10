extends SceneTree

const Actualizador := preload("res://scripts/actualizador.gd")

func _initialize() -> void:
	var a := Actualizador.new()
	root.add_child(a)
	
	# Verifica estado inicial
	assert(not a.is_processing())
	a.comprobar()
	
	# Detiene
	a.set_process(false)
	var _e := a.terminado
	root.remove_child(a)
	a.queue_free()
	
	print("TESTS OK")
	quit(0)
