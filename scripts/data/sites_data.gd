class_name SitesData
extends RefCounted
## Tessere dei siti di scavo (da data/siti.json).

static var _data := {}


static func load_all() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/siti.json", FileAccess.READ)
		if f != null:
			_data = JSON.parse_string(f.get_as_text())
	return _data


static func get_tiles(large: bool) -> Array:
	return load_all().get("grandi" if large else "piccole", [])
