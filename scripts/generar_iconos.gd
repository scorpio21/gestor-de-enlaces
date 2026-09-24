extends SceneTree

const CONST_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 120 120">
<defs>
<linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#ffc46b"/>
<stop offset="1" stop-color="#e8862a"/>
</linearGradient>
</defs>
<rect x="6" y="6" width="108" height="108" rx="24" fill="#10141c"/>
<rect x="26" y="30" width="34" height="20" rx="6" fill="none" stroke="url(#g)" stroke-width="6"/>
<rect x="56" y="56" width="34" height="20" rx="6" fill="none" stroke="url(#g)" stroke-width="6"/>
<path d="M60 40 H78 a9 9 0 0 1 0 18l-6-20z" fill="url(#g)" opacity="0.9"/>
<path d="M50 76 a9 9 0 0 1-8-18h4" stroke="url(#g)" stroke-width="6" fill="none" stroke-linecap="round"/>
<circle cx="93" cy="92" r="8" fill="none" stroke="#3ddc84" stroke-width="5"/>
<path d="M90 92 l2.5 2.5 l4-4" stroke="#3ddc84" stroke-width="3" fill="none"/>
</svg>
"""


const _SVG_FLAG_ES := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<rect width="64" height="64" fill="#f5b301"/>
<rect y="6" width="64" height="14" fill="#c8102e"/>
<rect y="44" width="64" height="14" fill="#c8102e"/>
<rect x="26" y="10" width="12" height="44" fill="#c8102e"/>
</svg>
"""

const _SVG_FLAG_GB := """<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<rect width="64" height="64" fill="#012169"/>
<path d="M32 0v64M0 32h64" stroke="#ffffff" stroke-width="12"/>
<path d="M32 0v64M0 32h64" stroke="#c8102e" stroke-width="6"/>
<path d="M32 0L0 32M32 0L64 32M32 64L0 32M32 64L64 32" stroke="#ffffff" stroke-width="12"/>
<path d="M32 0L0 32M32 0L64 32M32 64L0 32M32 64L64 32" stroke="#c8102e" stroke-width="5"/>
</svg>
"""


static func generar(destino := "res://Assets/icon") -> Dictionary:
	DirAccess.make_dir_recursive_absolute(destino)
	var svg_bytes := CONST_SVG.to_utf8_buffer()
	var im := Image.new()
	var err := im.load_svg_from_buffer(svg_bytes, 4.0)
	if err != OK:
		return {"ok": false, "total": 0}
	im.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	Var.write_bytes(destino + "/icon.svg", svg_bytes)
	Var.write_bytes(destino + "/icon_256.png", im.save_png_to_buffer())
	Var.write_bytes(destino + "/icon.ico", _fichero_ico(im))
	Var.write_bytes(destino + "/icon.icns", _fichero_icns(im))
	Var.write_bytes(destino + "/flag_es.svg", _SVG_FLAG_ES.to_utf8_buffer())
	Var.write_bytes(destino + "/flag_gb.svg", _SVG_FLAG_GB.to_utf8_buffer())
	return {"ok": true, "total": 6}


class Var:
	static func write_bytes(ruta: String, data: PackedByteArray) -> void:
		var f := FileAccess.open(ruta, FileAccess.WRITE)
		if f != null:
			f.store_buffer(data)


static func _png_en(tam: int) -> PackedByteArray:
	var base := Image.new()
	var err := base.load_svg_from_buffer(CONST_SVG.to_utf8_buffer(), float(tam) / 256.0)
	if err != OK:
		return PackedByteArray()
	return base.save_png_to_buffer()


static func _fichero_ico(im: Image) -> PackedByteArray:
	var tam := PackedInt32Array([16, 32, 48, 256])
	var blobs: Array[PackedByteArray] = []
	for t in tam:
		var capa := Image.new()
		capa.copy_from(im)
		capa.resize(t, t, Image.INTERPOLATE_LANCZOS)
		blobs.append(capa.save_png_to_buffer())
	var salida := PackedByteArray([0, 0, 1, 0])
	salida.append(tam.size()); salida.append(0)
	var offset: int = 6 + tam.size() * 16
	for i in range(tam.size()):
		var t := tam[i]
		salida.append(0 if t >= 256 else t)
		salida.append(0 if t >= 256 else t)
		salida.append(0)
		salida.append(0)
		salida.append(1); salida.append(0)
		salida.append(32); salida.append(0)
		salida.append(blobs[i].size() & 0xFF); salida.append((blobs[i].size() >> 8) & 0xFF)
		salida.append((blobs[i].size() >> 16) & 0xFF); salida.append((blobs[i].size() >> 24) & 0xFF)
		salida.append(offset & 0xFF); salida.append((offset >> 8) & 0xFF)
		salida.append((offset >> 16) & 0xFF); salida.append((offset >> 24) & 0xFF)
		offset += blobs[i].size()
	for b in blobs:
		salida.append_array(b)
	return salida


static func _fichero_icns(im: Image) -> PackedByteArray:
	var entradas := [
		["icp4", 16], ["icp5", 32], ["ic07", 128], ["ic08", 256], ["ic09", 512],
	]
	var salida := "icns".to_ascii_buffer()
	var tam_total := PackedByteArray([0, 0, 0, 0])
	salida.append_array(tam_total)
	var acumulado: int = 8
	for e in entradas:
		var png := _png_en(e[1])
		salida.append_array(e[0].to_ascii_buffer())
		var largo := 8 + png.size()
		salida.append((largo >> 24) & 0xFF); salida.append((largo >> 16) & 0xFF)
		salida.append((largo >> 8) & 0xFF); salida.append(largo & 0xFF)
		salida.append_array(png)
		acumulado += largo
	salida[4] = (acumulado >> 24) & 0xFF
	salida[5] = (acumulado >> 16) & 0xFF
	salida[6] = (acumulado >> 8) & 0xFF
	salida[7] = acumulado & 0xFF
	return salida


func _initialize() -> void:
	var res := generar()
	if not res.get("ok", false):
		push_error("No se pudieron generar los iconos")
		quit(1)
		return
	print("Iconos generados (%d)." % int(res.get("total", 0)))
	quit(0)