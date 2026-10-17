extends RefCounted
## Geometry and packing authority shared by all inventory gestures and persistence.
static func item_size(id: String) -> Vector2i:
	var item: Dictionary = Catalog.get_item(id)
	if item.has("grid_size"): return Vector2i(int(item.grid_size[0]),int(item.grid_size[1]))
	match str(item.get("kind","")):
		"weapon":
			match str(item.get("category","")):
				"pistol":return Vector2i(2,2)
				"smg":return Vector2i(4,2)
				"sniper","machine_gun":return Vector2i(6,2)
			return Vector2i(5,2)
		"armor":
			match str(item.get("category","")):
				"helmet":return Vector2i(2,2)
				"visor":return Vector2i(2,1)
				"backpack","armored_rig":return Vector2i(3,3)
			return Vector2i(3,3)
		"attachment":
			match str(item.get("slot","")):
				"magazine":return Vector2i(1,2)
				"stock","handguard":return Vector2i(2,1)
				"muzzle":return Vector2i(2,1) if str(item.get("category",""))=="suppressor" else Vector2i.ONE
	return Vector2i.ONE

static func stack_limit(id: String) -> int:
	return 60 if str(Catalog.get_item(id).get("kind",""))=="ammo" else 1

static func blocks(container: String, loadout: Dictionary) -> Array:
	if container=="stash":return [{"id":"0","w":10,"h":50}]
	if container=="pockets":return [{"id":"0","w":1,"h":1},{"id":"1","w":1,"h":1},{"id":"2","w":1,"h":1},{"id":"3","w":1,"h":1}]
	var slot: String = "armored_rig" if container=="rig" else "backpack"
	var item: Dictionary = Catalog.get_item(str(loadout.get(slot,"")))
	if item.is_empty():return []
	if container=="backpack":
		var capacity: int = int(item.get("capacity",12))
		var width: int = 3 if capacity<=12 else (4 if capacity<=20 else (5 if capacity<=30 else 6))
		return [{"id":"0","w":width,"h":ceili(float(capacity)/width)}]
	var capacity: int = int(item.get("capacity",8))
	var sizes: Array = []
	if capacity==8:sizes=[[1,2],[1,2],[1,2],[1,2]]
	elif capacity==12:sizes=[[1,2],[1,2],[1,2],[1,2],[1,1],[1,1],[1,1],[1,1]]
	elif capacity==18:sizes=[[1,2],[1,2],[1,2],[1,2],[2,2],[2,2],[1,1],[1,1]]
	else:sizes=[[1,3],[1,3],[1,3],[1,3],[2,2],[2,2],[2,2]]
	var result: Array = []
	for i: int in range(sizes.size()):result.append({"id":str(i),"w":sizes[i][0],"h":sizes[i][1]})
	return result

static func footprint(record: Dictionary, rotated: bool = false) -> Vector2i:
	var size: Vector2i = item_size(str(record.item))
	return Vector2i(size.y,size.x) if rotated else size

static func find_record(records: Array, uid: String) -> Dictionary:
	for record: Dictionary in records:
		if str(record.uid)==uid:return record
	return {}

static func can_place(record: Dictionary, container: String, block: String, at: Vector2i, rotated: bool, records: Array, loadout: Dictionary) -> bool:
	var size: Vector2i = footprint(record,rotated)
	var found: bool = false
	for definition: Dictionary in blocks(container,loadout):
		if str(definition.id)==block:
			found=at.x>=0 and at.y>=0 and at.x+size.x<=int(definition.w) and at.y+size.y<=int(definition.h)
	if not found:return false
	var rectangle:=Rect2i(at,size)
	for other: Dictionary in records:
		if str(other.uid)==str(record.uid) or str(other.get("container",""))!=container or str(other.get("block","0"))!=block:continue
		var other_size: Vector2i = footprint(other,bool(other.get("rotated",false)))
		if rectangle.intersects(Rect2i(Vector2i(int(other.get("x",0)),int(other.get("y",0))),other_size)):return false
	return true

static func find_spot(record: Dictionary, container: String, records: Array, loadout: Dictionary, block: String = "", at: Vector2i = Vector2i(-1,-1)) -> Dictionary:
	var definitions: Array = blocks(container,loadout)
	var occupied: Dictionary = {}
	for other: Dictionary in records:
		if str(other.uid)==str(record.uid) or str(other.get("container",""))!=container:continue
		var key: String = str(other.get("block","0"))
		if not occupied.has(key):occupied[key]={}
		var dimensions: Vector2i = footprint(other,bool(other.get("rotated",false)))
		for oy: int in range(dimensions.y):
			for ox: int in range(dimensions.x):occupied[key][Vector2i(int(other.get("x",0))+ox,int(other.get("y",0))+oy)]=true
	var rotations: Array = [bool(record.get("rotated",false)),not bool(record.get("rotated",false))]
	if not block.is_empty() and at.x>=0:
		for rotated: bool in rotations:
			if can_place(record,container,block,at,rotated,records,loadout):return {"container":container,"block":block,"x":at.x,"y":at.y,"rotated":rotated}
	var best: Dictionary = {}
	var score: float = INF
	for definition: Dictionary in definitions:
		if not block.is_empty() and str(definition.id)!=block:continue
		for rotated: bool in rotations:
			var size: Vector2i = footprint(record,rotated)
			for y: int in range(maxi(0,int(definition.h)-size.y+1)):
				for x: int in range(maxi(0,int(definition.w)-size.x+1)):
					var point:=Vector2i(x,y)
					var free: bool = true
					var cells: Dictionary = occupied.get(str(definition.id),{})
					for sy: int in range(size.y):
						for sx: int in range(size.x):
							if cells.has(point+Vector2i(sx,sy)):free=false
					if not free:continue
					var candidate: float = float(y*int(definition.w)+x)*.001 if at.x<0 else Vector2(point-at).length_squared()
					if candidate<score:
						score=candidate
						best={"container":container,"block":str(definition.id),"x":x,"y":y,"rotated":rotated}
					if at.x<0:return best
	return best

static func apply_spot(record: Dictionary, spot: Dictionary) -> void:
	for key: String in spot:record[key]=spot[key]

static func reconcile(records: Array, counts: Dictionary, loadout: Dictionary) -> Array:
	var remaining: Dictionary = counts.duplicate(true)
	var output: Array = []
	var displaced: Array = []
	var identifiers: Dictionary = {}
	for raw: Variant in records:
		if not raw is Dictionary or not raw.get("uid",null) is String or not raw.get("item",null) is String:continue
		var record: Dictionary = raw.duplicate(true)
		var id: String = str(record.item)
		if identifiers.has(record.uid) or Catalog.get_item(id).is_empty():continue
		identifiers[record.uid]=true
		var quantity: int = mini(maxi(0,int(record.get("qty",0))),int(remaining.get(id,0)))
		if quantity<=0:continue
		record.qty=quantity
		remaining[id]=int(remaining.get(id,0))-quantity
		var container: String = str(record.get("container","stash"))
		if container!="overflow" and can_place(record,container,str(record.get("block","0")),Vector2i(int(record.get("x",0)),int(record.get("y",0))),bool(record.get("rotated",false)),output,loadout):output.append(record)
		else:displaced.append(record)
	for id: String in remaining:
		var quantity: int = int(remaining[id])
		while quantity>0:
			var amount: int = mini(quantity,stack_limit(id))
			var record: Dictionary = {"uid":"i%d_%d"%[Time.get_ticks_usec(),displaced.size()],"item":id,"qty":amount,"rotated":false}
			displaced.append(record)
			quantity-=amount
			# Preserve an exceptionally large legacy stack without creating 100k nodes.
			if displaced.size()>1000 and quantity>0:
				displaced.append({"uid":"legacy%d"%Time.get_ticks_usec(),"item":id,"qty":quantity,"rotated":false})
				break
	var used_cells: int = 0
	for record: Dictionary in output:
		if str(record.container)=="stash":
			var size: Vector2i=footprint(record,bool(record.get("rotated",false)))
			used_cells+=size.x*size.y
	for record: Dictionary in displaced:
		var size: Vector2i=footprint(record,bool(record.get("rotated",false)))
		var spot: Dictionary = {}
		if used_cells+size.x*size.y<=500 and int(record.qty)<=stack_limit(str(record.item)):spot=find_spot(record,"stash",output,loadout)
		if spot.is_empty():record.container="overflow"
		else:
			apply_spot(record,spot)
			used_cells+=size.x*size.y
		output.append(record)
	return output

static func remove_quantity(records: Array, id: String, quantity: int, preferred: String = "", carried_first: bool = false) -> void:
	var candidates: Array = []
	for record: Dictionary in records:
		if str(record.item)==id:candidates.append(record)
	if not preferred.is_empty():
		var record: Dictionary = find_record(records,preferred)
		if candidates.has(record):
			candidates.erase(record)
			candidates.push_front(record)
	elif carried_first:
		candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return str(a.container)!="stash" and str(b.container)=="stash")
	for record: Dictionary in candidates:
		var taken: int = mini(quantity,int(record.qty))
		record.qty=int(record.qty)-taken
		quantity-=taken
		if int(record.qty)<=0:records.erase(record)
		if quantity<=0:break

static func overflow_count(records: Array) -> int:
	var total: int = 0
	for record: Dictionary in records:
		if str(record.get("container",""))=="overflow":total+=int(record.qty)
	return total
