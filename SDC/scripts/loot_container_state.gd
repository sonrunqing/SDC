extends RefCounted
## A container owns stable records and search progress independently of the bag.
const Grid=preload("res://scripts/inventory_grid.gd")

static func prepare(contents: Dictionary,serial: String,columns: int = 6,rows: int = 5) -> Dictionary:
	var records: Array=[]
	var sequence: int=0
	for id: String in contents:
		var remaining: int=int(contents[id])
		while remaining>0:
			var amount: int=mini(remaining,Grid.stack_limit(id))
			var record: Dictionary={"uid":"loot/"+serial+"/"+str(sequence),"item":id,"qty":amount,"container":"loot","block":"0","rotated":false,"discovered":false}
			var spot: Dictionary=find_spot(record,records,columns,rows)
			if spot.is_empty():
				# Expand the container before play; never silently discard a rolled item.
				rows+=maxi(2,Grid.item_size(id).y)
				spot=find_spot(record,records,columns,rows)
			if spot.is_empty():
				columns=maxi(columns,Grid.item_size(id).x)
				spot=find_spot(record,records,columns,rows)
			Grid.apply_spot(record,spot)
			records.append(record)
			remaining-=amount
			sequence+=1
	return {"records":records,"columns":columns,"rows":rows,"elapsed":0.0,"opening":.45,"visited":false,"paused":false}

static func find_spot(record: Dictionary,records: Array,columns: int,rows: int) -> Dictionary:
	for rotated: bool in [false,true]:
		var size: Vector2i=Grid.footprint(record,rotated)
		for y: int in range(maxi(0,rows-size.y+1)):
			for x: int in range(maxi(0,columns-size.x+1)):
				var area:=Rect2i(Vector2i(x,y),size)
				var free: bool=true
				for other: Dictionary in records:
					if area.intersects(Rect2i(Vector2i(int(other.x),int(other.y)),Grid.footprint(other,bool(other.rotated)))):free=false;break
				if free:return {"x":x,"y":y,"rotated":rotated,"container":"loot","block":"0"}
	return {}

static func current(state: Dictionary) -> Dictionary:
	for record: Dictionary in state.records:
		if int(record.qty)>0 and not bool(record.discovered):return record
	return {}

static func duration(record: Dictionary) -> float:
	var size: Vector2i=Grid.item_size(str(record.item))
	return .6+minf(.8,float(size.x*size.y)*.09)

static func advance(state: Dictionary,delta: float) -> int:
	if bool(state.paused):return 0
	if float(state.opening)>0:
		var used: float=minf(delta,float(state.opening))
		state.opening=maxf(0,float(state.opening)-used)
		delta-=used
		if float(state.opening)<=0:state.visited=true
	var revealed: int=0
	state.elapsed+=delta
	var record: Dictionary=current(state)
	while not record.is_empty() and float(state.elapsed)>=duration(record):
		state.elapsed-=duration(record)
		record.discovered=true
		revealed+=1
		record=current(state)
	if record.is_empty():state.elapsed=0.0
	return revealed

static func remaining(state: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for record: Dictionary in state.records:
		if int(record.qty)>0:result[record.item]=int(result.get(record.item,0))+int(record.qty)
	return result

static func snapshot(state: Dictionary) -> Dictionary:
	var record: Dictionary=current(state)
	var revealed: int=0
	for item: Dictionary in state.records:
		if bool(item.discovered):revealed+=1
	return {"records":state.records.duplicate(true),"columns":state.columns,"rows":state.rows,"active_uid":str(record.get("uid","")),"progress":float(state.elapsed)/duration(record) if not record.is_empty() else 1.0,"opening":float(state.opening),"paused":bool(state.paused),"complete":record.is_empty() and float(state.opening)<=0,"discovered":revealed,"total":state.records.size(),"empty":remaining(state).is_empty()}
