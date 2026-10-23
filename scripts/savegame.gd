extends RefCounted
## Campaign data is saved only after accepted actions. Field cargo is committed
## on extraction; field observations survive a rescue.
const PATH := "user://klax_campaign_v1.json"
const VERSION := 1

static func fresh() -> Dictionary:
	return {"version":VERSION,"science":0,"selected_planet":0,"selected_crew":0,
		"completed":[],"research":{},"upgrades":{},"relays":[],"ending":"",
		"samples":[],"surveys":[],"visited":{},"expeditions":0,"rescues":0,"logs":[],"muted":false}

static func valid(data:Variant) -> bool:
	if not data is Dictionary or data.get("version",0) != VERSION:
		return false
	for key in ["science","selected_planet","selected_crew","expeditions","rescues"]:
		if not data.get(key) is float and not data.get(key) is int:
			return false
		if float(data[key]) < 0 or not is_finite(float(data[key])):
			return false
	if int(data.selected_planet) > 5 or int(data.selected_crew) > 2:
		return false
	for key in ["completed","relays","samples","logs"]:
		if not data.get(key) is Array:
			return false
	for key in ["research","upgrades","visited"]:
		if not data.get(key) is Dictionary:
			return false
	for key in data.research:
		if not str(key).is_valid_int() or int(key) < 0 or int(key) > 11 or not data.research[key] is Dictionary:
			return false
		for flag in ["scanned","sampled","analyzed"]:
			if not data.research[key].get(flag) is bool:
				return false
	if not data.get("surveys",[]) is Array: return false
	for value in data.get("surveys",[]):
		if not (value is int or value is float) or int(value)<0 or int(value)>5: return false
	for key in ["completed","relays"]:
		for value in data[key]:
			if not (value is int or value is float) or int(value)<0 or int(value)>5:
				return false
	for value in data.samples:
		if not (value is int or value is float) or int(value)<0 or int(value)>11:
			return false
	for key in data.upgrades:
		if not str(key) in ["scanner","oxygen","suit","rover","lure","cargo"] or not (data.upgrades[key] is int or data.upgrades[key] is float) or int(data.upgrades[key])<0 or int(data.upgrades[key])>3:
			return false
	for key in data.visited:
		if not data.visited[key] is Array:
			return false
	return data.get("ending") is String

static func load_campaign(path:String=PATH) -> Dictionary:
	for candidate in [path,path+".backup"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed:Variant = _decode(FileAccess.get_file_as_string(candidate))
		if valid(parsed):
			var result:Dictionary = fresh()
			result.merge(parsed,true)
			# JSON numbers are floats in Godot. Array.has uses strict numeric types.
			for key in ["completed","relays","samples","surveys"]:
				var ids:Array = []
				for value in result[key]:
					if not int(value) in ids:
						ids.append(int(value))
				result[key] = ids
			return result
	return fresh()

static func save_campaign(state:Dictionary,path:String=PATH) -> bool:
	if not valid(state):
		return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state,"\t"))
	file.close()
	if FileAccess.file_exists(path):
		var previous:Variant = _decode(FileAccess.get_file_as_string(path))
		if valid(previous):
			DirAccess.copy_absolute(path,path+".backup")
	return DirAccess.rename_absolute(path+".tmp",path) == OK

static func _decode(text:String) -> Variant:
	var parser := JSON.new()
	if parser.parse(text)!=OK:
		return null
	return parser.data
