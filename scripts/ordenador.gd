extends RefCounted


static func direccion_por_defecto(columna: String) -> int:
	return 1 if columna == "nombre" or columna == "imagen" else -1


static func peso_estado(valido) -> int:
	if valido == null:
		return 0
	return 1 if valido == true else 2


static func comparar(a, b, columna: String, direccion: int) -> bool:
	match columna:
		"nombre":
			var na: String = a.nombre if a.nombre != "" else a.url
			var nb: String = b.nombre if b.nombre != "" else b.url
			if na == nb:
				return a.url < b.url
			return na < nb if direccion == 1 else na > nb
		"estado":
			var ea := peso_estado(a.valido)
			var eb := peso_estado(b.valido)
			if ea == eb:
				return a.url < b.url
			return ea > eb if direccion == -1 else ea < eb
		"fecha":
			var fa := int(a.fecha)
			var fb := int(b.fecha)
			if fa == fb:
				return a.url < b.url
			if fa == 0:
				return false
			if fb == 0:
				return true
			return fa > fb if direccion == -1 else fa < fb
		"imagen":
			var ia := 1 if a.img != "" else 0
			var ib := 1 if b.img != "" else 0
			if ia == ib:
				return a.url < b.url
			return ia > ib if direccion == 1 else ia < ib
	return a.url < b.url