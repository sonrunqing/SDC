extends RefCounted
## Shared geometry for the live HUD and its layout editor. Positions are normalized
## inside the display safe area, not stored as device-specific pixel coordinates.
const IDS: Array[String] = ["move","aim","fire","reload","interact","heal","weapon_primary","weapon_secondary","weapon_sidearm","menu"]
const REQUIRED: Array[String] = ["move","aim","fire","menu"]
const CIRCLES: Array[String] = ["move","aim","fire","menu","interact"]
const TITLES: Dictionary = {"move":"移动摇杆","aim":"瞄准摇杆","fire":"开火","reload":"换弹","interact":"搜索 / 拾取","heal":"治疗","weapon_primary":"主武器","weapon_secondary":"副武器","weapon_sidearm":"手枪","menu":"菜单"}
const SIZES: Dictionary = {"move":Vector2(152,152),"aim":Vector2(152,152),"fire":Vector2(94,94),"reload":Vector2(112,72),"interact":Vector2(64,64),"heal":Vector2(104,72),"weapon_primary":Vector2(148,64),"weapon_secondary":Vector2(148,64),"weapon_sidearm":Vector2(148,64),"menu":Vector2(44,44)}

static func usable_rect(view_size: Vector2,safe: Vector4) -> Rect2:
	return Rect2(Vector2(safe.x,safe.y),Vector2(maxf(1,view_size.x-safe.x-safe.z),maxf(1,view_size.y-safe.y-safe.w)))

static func _number(value: Variant,fallback: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):return float(value)
	return fallback

static func sanitize(raw: Variant) -> Dictionary:
	var result: Dictionary={}
	if not raw is Dictionary:return result
	for id: String in IDS:
		var entry: Variant=raw.get(id)
		if not entry is Dictionary:continue
		if not (entry.get("x") is float or entry.get("x") is int) or not (entry.get("y") is float or entry.get("y") is int):continue
		if not is_finite(float(entry.x)) or not is_finite(float(entry.y)):continue
		result[id]={"x":clampf(float(entry.x),0,1),"y":clampf(float(entry.y),0,1),"scale":clampf(_number(entry.get("scale"),1),.65,1.8),"opacity":clampf(_number(entry.get("opacity"),.8),.2,1),"visible":true if id in REQUIRED else (entry.get("visible",true) if entry.get("visible",true) is bool else true)}
	return result

static func defaults(view_size: Vector2,safe: Vector4,legacy_scale: float = 1,opacity: float = .8) -> Dictionary:
	var area: Rect2=usable_rect(view_size,safe)
	var left: float=area.position.x
	var right: float=area.end.x
	var bottom: float=area.end.y
	var middle: float=left+area.size.x*.46
	var scale_value: float=clampf(legacy_scale,.8,1.25)
	var centers: Dictionary={
		"move":Vector2(left+118*scale_value,bottom-maxf(area.size.y*.25,76*scale_value+80)),
		"aim":Vector2(right-154*scale_value,bottom-maxf(area.size.y*.32,76*scale_value+100)),
		"fire":Vector2(left+26+47*scale_value,area.position.y+maxf(104+47*scale_value,area.size.y*.24)),
		"reload":Vector2(maxf(right-354,middle+238)+56,bottom-56),
		"interact":Vector2(right-52,area.position.y+maxf(228,area.size.y*.45)),
		"heal":Vector2(right-52,bottom-56),
		"weapon_primary":Vector2(middle-156,bottom-44),
		"weapon_secondary":Vector2(middle,bottom-44),
		"weapon_sidearm":Vector2(middle+156,bottom-44),
		"menu":Vector2(right-24,area.position.y+128)}
	var output: Dictionary={}
	for id: String in IDS:
		var point: Vector2=(centers[id]-area.position)/area.size
		output[id]={"x":clampf(point.x,0,1),"y":clampf(point.y,0,1),"scale":scale_value if id in CIRCLES else 1.0,"opacity":clampf(opacity,.2,1),"visible":true}
	return output

static func resolve(raw: Dictionary,view_size: Vector2,safe: Vector4,legacy_scale: float = 1,opacity: float = .8) -> Dictionary:
	var entries: Dictionary=defaults(view_size,safe,legacy_scale,opacity)
	entries.merge(sanitize(raw),true)
	return entries

static func rectangles(entries: Dictionary,view_size: Vector2,safe: Vector4) -> Dictionary:
	var area: Rect2=usable_rect(view_size,safe)
	var fit: float=minf(1,minf(area.size.x/960,area.size.y/500))
	var result: Dictionary={}
	for id: String in IDS:
		var entry: Dictionary=entries[id]
		var dimensions: Vector2=SIZES[id]*float(entry.scale)*fit
		var minimum:=Vector2(86,86) if id in ["move","aim"] else (Vector2(64,64) if id in ["fire","interact"] else (Vector2(44,44) if id=="menu" else Vector2(64,44)))
		dimensions=dimensions.max(minimum).min(area.size)
		var half: Vector2=dimensions*.5
		var center: Vector2=area.position+area.size*Vector2(float(entry.x),float(entry.y))
		center.x=clampf(center.x,area.position.x+half.x,area.end.x-half.x)
		center.y=clampf(center.y,area.position.y+half.y,area.end.y-half.y)
		result[id]=Rect2(center-half,dimensions)
	return result

static func visible(entries: Dictionary,id: String) -> bool:
	return bool(entries.get(id,{}).get("visible",true))

static func contains(id: String,rectangle: Rect2,point: Vector2) -> bool:
	if id in CIRCLES:return point.distance_to(rectangle.get_center())<=rectangle.size.x*.5
	return rectangle.has_point(point)

static func pick(entries: Dictionary,rects: Dictionary,point: Vector2,preferred: String = "") -> String:
	if rects.has(preferred) and visible(entries,preferred) and contains(preferred,rects[preferred],point):return preferred
	for id: String in ["menu","fire","reload","interact","heal","weapon_primary","weapon_secondary","weapon_sidearm","move","aim"]:
		if visible(entries,id) and contains(id,rects[id],point):return id
	return ""

static func set_center(entries: Dictionary,id: String,point: Vector2,view_size: Vector2,safe: Vector4) -> void:
	var area: Rect2=usable_rect(view_size,safe)
	var rect: Rect2=rectangles(entries,view_size,safe)[id]
	var half: Vector2=rect.size*.5
	point.x=clampf(point.x,area.position.x+half.x,area.end.x-half.x)
	point.y=clampf(point.y,area.position.y+half.y,area.end.y-half.y)
	entries[id].x=(point.x-area.position.x)/area.size.x
	entries[id].y=(point.y-area.position.y)/area.size.y

static func _overlap(first_id: String,first: Rect2,second_id: String,second: Rect2) -> bool:
	var first_circle: bool=first_id in CIRCLES
	var second_circle: bool=second_id in CIRCLES
	if first_circle and second_circle:return first.get_center().distance_to(second.get_center())<(first.size.x+second.size.x)*.5+3
	if first_circle or second_circle:
		var circle: Rect2=first if first_circle else second
		var box: Rect2=second if first_circle else first
		var center: Vector2=circle.get_center()
		var closest:=Vector2(clampf(center.x,box.position.x,box.end.x),clampf(center.y,box.position.y,box.end.y))
		return center.distance_to(closest)<circle.size.x*.5+3
	return first.grow(1.5).intersects(second.grow(1.5))

static func collisions(entries: Dictionary,rects: Dictionary) -> Array[String]:
	var output: Array[String]=[]
	for first: int in range(IDS.size()):
		var first_id: String=IDS[first]
		if not visible(entries,first_id):continue
		for second: int in range(first+1,IDS.size()):
			var second_id: String=IDS[second]
			if visible(entries,second_id) and _overlap(first_id,rects[first_id],second_id,rects[second_id]):
				if not output.has(first_id):output.append(first_id)
				if not output.has(second_id):output.append(second_id)
	return output
