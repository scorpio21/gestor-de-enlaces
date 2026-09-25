extends SceneTree

const EtiquetasScript := preload("res://scripts/etiquetas.gd")

var _fallos := 0


func _initialize() -> void:
	_check(parsear_string(), "parsear separa por coma y punto y coma, recorta y ordena")
	_check(parsear_dedupica(), "parsear deduplica sin distinguir mayúsculas y conserva una mayúscula")
	_check(parsear_vacia(), "parsear con vacío o lista vacía devuelve lista vacía")
	_check(parsear_array(), "parsear acepta un Array")
	_check(unir_lista(), "unir reconstruye el texto separado por coma")
	_check(unir_vacia(), "unir con vacío devuelve texto vacío")
	_check(parsear_unir_roundtrip(), "unir(parsear(texto)) devuelve la forma normalizada")
	_check(frecuentes_ordena(), "frecuentes devuelve las más usadas, ordenadas y limitadas")
	_check(frecuentes_ignora_no_dict(), "frecuentes ignora entradas no diccionario y sin tags")
	_check(frecuentes_sin_limite(), "frecuentes con límite 0 devuelve todas las etiquetas")
	_check(coincide_alguna(), "coincide es true si coincide alguna etiqueta")
	_check(coincide_ninguna(), "coincide es false si no coincide ninguna")
	_check(coincide_sin_seleccion(), "coincide sin selección no filtra")
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func parsear_string() -> bool:
	var lista: Array = EtiquetasScript.parsear("  AO 1.6, español;servidor PVP ,AO 1.4  ")
	return lista == ["AO 1.4", "AO 1.6", "español", "servidor PVP"]


func parsear_dedupica() -> bool:
	return EtiquetasScript.parsear("ao 1.6, AO 1.6, AO 1.6 ") == ["AO 1.6"]


func parsear_vacia() -> bool:
	return EtiquetasScript.parsear("").is_empty() \
		and EtiquetasScript.parsear("  ,  ; ;,,").is_empty() \
		and EtiquetasScript.parsear([]).is_empty() \
		and EtiquetasScript.parsear(null).is_empty()


func parsear_array() -> bool:
	var lista: Array = EtiquetasScript.parsear(["Servidor", "  pvp  ", "SERVIDOR"])
	return lista == ["pvp", "SERVIDOR"]


func unir_lista() -> bool:
	return EtiquetasScript.unir(["AO", "español"]) == "AO, español" and EtiquetasScript.unir([" "]) == ""


func unir_vacia() -> bool:
	return EtiquetasScript.unir([]) == ""


func parsear_unir_roundtrip() -> bool:
	return EtiquetasScript.unir(EtiquetasScript.parsear("AO 1.6, AO 1.6, español")) == "AO 1.6, español"


func frecuentes_ordena() -> bool:
	var entradas: Array = [
		{"tags": ["servidor", "pvP"]},
		{"tags": ["servidor"]},
		{"tags": ["AO"]},
		{"tags": ["servidor", "AO"]},
		{"tags": []},
	]
	var resultado: Array = EtiquetasScript.frecuentes(entradas, 2)
	return resultado == ["servidor", "AO"]


func frecuentes_ignora_no_dict() -> bool:
	var entradas: Array = ["texto", 42, {"nombre": "sin tags"}]
	return EtiquetasScript.frecuentes(entradas, 5).is_empty()


func frecuentes_sin_limite() -> bool:
	var entradas: Array = [
		{"tags": ["servidor"]},
		{"tags": ["servidor", "AO"]},
	]
	return EtiquetasScript.frecuentes(entradas, 0) == ["servidor", "AO"]


func coincide_alguna() -> bool:
	return EtiquetasScript.coincide(["server", "pvp"], ["PvP", "AO"]) \
		and EtiquetasScript.coincide(["AO"], ["ao"])


func coincide_ninguna() -> bool:
	return not EtiquetasScript.coincide(["server"], ["ao", "pvp"]) \
		and not EtiquetasScript.coincide([], ["ao"])


func coincide_sin_seleccion() -> bool:
	return EtiquetasScript.coincide(["server"], []) and EtiquetasScript.coincide([], [])


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)