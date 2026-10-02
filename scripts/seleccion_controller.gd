extends RefCounted

var _urls: Array = []
var _sel: Dictionary = {}
var _ancla := ""

var _barra: FlowContainer = null
var _contador: Label = null
var _filas_visibles := Callable()
var _urls_catalogo := Callable()


func preparar(barra: FlowContainer, contador: Label, filas_visibles: Callable, urls_catalogo: Callable) -> void:
	_barra = barra
	_contador = contador
	_filas_visibles = filas_visibles
	_urls_catalogo = urls_catalogo


func pintar(cambios: Array) -> void:
	if is_instance_valid(_barra):
		for url in cambios:
			for fila in visibles():
				if str(fila.url) == url:
					fila.seleccionar(contiene(url))
					break
		_barra.visible = contar() > 0
	if is_instance_valid(_contador):
		_contador.text = texto_contador(contar())


func visibles() -> Array:
	return _filas_visibles.call() if _filas_visibles.is_valid() else []


func catalogo() -> Array:
	return _urls_catalogo.call() if _urls_catalogo.is_valid() else []


func filas_de(elegidas: Array) -> Array:
	var filas: Array = []
	for fila in visibles():
		if elegidas.has(str(fila.url)):
			filas.append(fila)
	return filas


static func urls_de_filas(filas: Array) -> Array:
	var urls: Array = []
	for fila in filas:
		urls.append(str(fila.url))
	return urls


static func urls_de_entradas(entradas: Array) -> Array:
	var urls: Array = []
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			urls.append(str(entrada.get("url", "")))
	return urls


func contiene(url: String) -> bool:
	return _sel.has(url)


func contar() -> int:
	return _urls.size()


func ancla() -> String:
	return _ancla


func alternar(url: String, ctrl: bool, rango: bool, visibles: Array) -> Array:
	if url.is_empty():
		return []
	if rango and not ctrl and _rango_valido(url, visibles):
		return _marcar_rango(url, visibles)
	var actuales := _urls.duplicate()
	if ctrl:
		var estaba := _sel.has(url)
		_ancla = url
		actuales.erase(url)
		if not estaba:
			actuales.append(url)
		return _aplicar(actuales)
	_ancla = url
	if _urls.size() == 1 and _sel.has(url):
		return []
	return _aplicar([url])


func seleccionar_todo(visibles: Array) -> Array:
	_ancla = str(visibles[0]) if not visibles.is_empty() else ""
	return _aplicar(visibles)


func limpiar() -> Array:
	_ancla = ""
	return _aplicar([])


func conservar(existentes: Array) -> Array:
	var cambios: Array = []
	for url in _urls.duplicate():
		if not existentes.has(url):
			cambios.append(url)
			_urls.erase(url)
			_sel.erase(url)
	if not _sel.has(_ancla):
		_ancla = ""
	return cambios


func intersectar(existentes: Array) -> Array:
	var vivas: Array = []
	for url in _urls:
		if existentes.has(url):
			vivas.append(url)
	return vivas


static func atajo_de(event: InputEvent) -> String:
	if not (event is InputEventKey):
		return ""
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return ""
	var ctrl := k.ctrl_pressed or k.meta_pressed
	if ctrl and not k.shift_pressed:
		if k.keycode == KEY_A:
			return "todo"
		if k.keycode == KEY_C:
			return "copiar"
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			return "comprobar"
	if k.shift_pressed and not ctrl and k.keycode == KEY_DELETE:
		return "eliminar"
	return ""


static func texto_contador(n: int) -> String:
	if n == 1:
		return TranslationServer.translate("1 seleccionado")
	return TranslationServer.translate("%d seleccionados") % n


static func texto_copiadas(n: int) -> String:
	return TranslationServer.translate("%d URLs copiadas") % n


static func texto_urls(urls: Array) -> String:
	return "\n".join(urls)


static func texto_borrados(n: int) -> String:
	if n <= 1:
		return TranslationServer.translate("Enlace eliminado")
	return TranslationServer.translate("%d enlaces eliminados") % n


static func texto_eliminar(n: int, primer_url := "", etiqueta := "") -> String:
	if n <= 1:
		return TranslationServer.translate("¿Eliminar «%s» para siempre?") % (etiqueta if not etiqueta.is_empty() else primer_url)
	return TranslationServer.translate("¿Eliminar %d enlaces para siempre?") % n


func _rango_valido(url: String, visibles: Array) -> bool:
	return not _ancla.is_empty() and visibles.has(_ancla) and visibles.has(url)


func _marcar_rango(url: String, visibles: Array) -> Array:
	var desde := visibles.find(_ancla)
	var hasta := visibles.find(url)
	var rango: Array = []
	for i in range(mini(desde, hasta), maxi(desde, hasta) + 1):
		rango.append(str(visibles[i]))
	return _aplicar(rango)


func _aplicar(nuevas: Array) -> Array:
	var antes := _urls.duplicate()
	_urls.clear()
	_sel.clear()
	for url in nuevas:
		var u := str(url)
		if u.is_empty() or _sel.has(u):
			continue
		_urls.append(u)
		_sel[u] = true
	var cambios: Array = []
	for url in antes:
		if not _sel.has(url):
			cambios.append(url)
	for url in _urls:
		if not antes.has(url):
			cambios.append(url)
	return cambios