extends RefCounted


static func comparar(nueva: String, actual: String) -> int:
	var a := _componentes(nueva)
	var b := _componentes(actual)
	var n := maxi(a.size(), b.size())
	for i in range(n):
		var da := a[i] if i < a.size() else 0
		var db := b[i] if i < b.size() else 0
		if da > db:
			return 1
		if da < db:
			return -1
	return 0


static func parsear_release(json_texto: String) -> Dictionary:
	if not json_texto.strip_edges().begins_with("{"):
		return {}
	var json := JSON.new()
	if json.parse(json_texto) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var tag := manejar_tag(str(json.data.get("tag_name", "")))
	var url := str(json.data.get("html_url", ""))
	if tag.is_empty() or url.is_empty():
		return {}
	return {"version": tag, "url": url}


static func manejar_tag(tag: String) -> String:
	var t := tag.strip_edges()
	if t.begins_with("v"):
		t = t.substr(1)
	return t.strip_edges()


static func _componentes(v: String) -> Array[int]:
	var partes := manejar_tag(v).split(".")
	var res: Array[int] = []
	for parte in partes:
		if parte.is_valid_int():
			res.append(int(parte))
		else:
			res.append(0)
	return res