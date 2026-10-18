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

static func find_spot(record: Dictionary,records: Array,columns: int,rows: int,at: Vector2i = Vector2i(-1,-1)) -> Dictionary:
	var best: Dictionary={}
	var score: float=INF
	for rotated: bool in [bool(record.get("rotated",false)),not bool(record.get("rotated",false))]:
		var size: Vector2i=Grid.footprint(record,rotated)
		for y: int in range(maxi(0,rows-size.y+1)):
			for x: int in range(maxi(0,columns-size.x+1)):
				var area:=Rect2i(Vector2i(x,y),size)
				var free: bool=true
				for other: Dictionary in records:
					if int(other.qty)<=0 or str(other.uid)==str(record.uid):continue
					if area.intersects(Rect2i(Vector2i(int(other.x),int(other.y)),Grid.footprint(other,bool(other.rotated)))):free=false;break
				if not free:continue
				var candidate: float=float(y*columns+x)*.001 if at.x<0 else Vector2(Vector2i(x,y)-at).length_squared()
				if candidate<score:
					score=candidate
					best={"x":x,"y":y,"rotated":rotated,"container":"loot","block":"0"}
				if at.x<0:return best
	return best

static func plan_deposit(state: Dictionary,record: Dictionary,quantity: int,at: Vector2i = Vector2i(-1,-1)) -> Dictionary:
	# Player deposits never expand a finite container or change an unknown item.
	if quantity<1 or quantity>int(record.get("qty",0)):return {}
	var proposed: Dictionary=state.duplicate(true)
	var id: String=str(record.item)
	var left: int=quantity
	var limit: int=Grid.stack_limit(id)
	for other: Dictionary in proposed.records:
		if left<=0:break
		if not bool(other.discovered) or str(other.item)!=id or int(other.qty)<=0 or int(other.qty)>=limit:continue
		if at.x>=0 and not Rect2i(Vector2i(int(other.x),int(other.y)),Grid.footprint(other,bool(other.rotated))).has_point(at):continue
		var amount: int=mini(left,limit-int(other.qty))
		other.qty=int(other.qty)+amount
		left-=amount
	var sequence: int=0
	while left>0:
		var amount: int=mini(left,limit)
		var incoming: Dictionary={"uid":"loot/returned/%d/%d"%[Time.get_ticks_usec(),sequence],"item":id,"qty":amount,"rotated":bool(record.get("rotated",false)),"discovered":true}
		var spot: Dictionary=find_spot(incoming,proposed.records,int(proposed.columns),int(proposed.rows),at)
		if spot.is_empty():return {}
		Grid.apply_spot(incoming,spot)
		proposed.records.append(incoming)
		left-=amount
		sequence+=1
	return proposed

static func current(state: Dictionary) -> Dictionary:
	for record: Dictionary in state.records:
		if int(record.qty)>0 and not bool(record.discovered):return record
	return {}

static func duration(record: Dictionary) -> float:
	var size: Vector2i=Grid.item_size(str(record.item))
	return .95+minf(1.1,float(size.x*size.y)*.18)

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
