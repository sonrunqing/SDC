extends RefCounted
const Grid = preload("res://scripts/inventory_grid.gd")
const FIELDS := ["credits","stash","loadout","weapon_builds","weapon_ammo","ammo_carry_plan","active_weapon_slot","inventory_items"]
static func packed_count(state: Node,id: String) -> int:
	var count: int = 0
	for record: Dictionary in state.inventory_items:
		if str(record.item)==id and str(record.container) in ["rig","pockets","backpack"]:count+=int(record.qty)
	return count
static func initial_pack(state: Node) -> void:
	state.inventory_items=Grid.reconcile(state.inventory_items,state.stash,state.loadout)
	for id: String in state.ammo_carry_plan:pack_amount(state,id,mini(int(state.ammo_carry_plan[id]),int(state.stash.get(id,0))))
	for id: String in state.stash:
		if str(Catalog.get_item(id).get("kind",""))=="consumable":
			pack_amount(state,id,mini(3,int(state.stash.get(id,0))))
			break
static func pack_amount(state: Node,id: String,quantity: int) -> void:
	for raw: Dictionary in state.inventory_items.duplicate():
		if quantity<=0:break
		if str(raw.item)!=id or str(raw.container)!="stash":continue
		var amount: int = mini(quantity,int(raw.qty))
		var candidate: Dictionary = raw.duplicate(true)
		candidate.qty=amount
		candidate.uid="p%d_%s"%[Time.get_ticks_usec(),str(raw.uid)]
		for container: String in ["rig","pockets","backpack"]:
			var spot: Dictionary = Grid.find_spot(candidate,container,state.inventory_items,state.loadout)
			if spot.is_empty():continue
			raw.qty=int(raw.qty)-amount
			if int(raw.qty)<=0:state.inventory_items.erase(raw)
			Grid.apply_spot(candidate,spot)
			state.inventory_items.append(candidate)
			quantity-=amount
			break
static func transfer(state: Node,uid: String,destination: String,block: String = "",cell: Vector2i = Vector2i(-1,-1)) -> bool:
	if state.raid_active:return state._fail("行动中请先完成撤离")
	var source: Dictionary = Grid.find_record(state.inventory_items,uid)
	var equipped: bool = uid.begins_with("equip/")
	var slot: String = uid.trim_prefix("equip/") if equipped else ""
	var id: String = str(state.loadout.get(slot,"")) if equipped else str(source.get("item",""))
	if id.is_empty():return state._fail("请选择一个物品")
	var snapshot: Dictionary = {}
	for field: String in FIELDS:
		var value: Variant = state.get(field)
		snapshot[field]=value.duplicate(true) if value is Dictionary or value is Array else value
	var before_overflow: int = Grid.overflow_count(state.inventory_items)
	state._grid_defer=true
	state._grid_preferred=uid
	var ok: bool = true
	var message: String = ""
	if destination.begins_with("equip/"):
		var target: String = destination.trim_prefix("equip/")
		var item: Dictionary = Catalog.get_item(id)
		if equipped:
			ok=false
			message="卸下后可更换装备栏"
		elif str(item.get("kind",""))=="ammo" and target in ["primary","secondary","sidearm"]:
			ok=state.select_weapon_ammo(target,id)
			if ok and str(source.container) not in ["rig","pockets","backpack"]:
				var packed: bool=false
				for container: String in ["rig","pockets","backpack"]:
					var spot: Dictionary=Grid.find_spot(source,container,state.inventory_items,state.loadout)
					if not spot.is_empty():
						Grid.apply_spot(source,spot)
						packed=true
						break
				if not packed:
					ok=false
					message="携行容器没有空格放置这叠弹药"
		elif str(item.get("kind",""))=="weapon":ok=state.equip_weapon(id,target)
		elif str(item.get("kind",""))=="armor" and Catalog.equipment_slot(id)==target:ok=state.equip(id)
		else:
			ok=false
			message="物品与装备栏位不匹配"
	else:
		if not equipped and not source.is_empty() and int(source.qty)>Grid.stack_limit(id):
			var part: Dictionary=source.duplicate(true)
			part.uid="recover%d"%Time.get_ticks_usec()
			part.qty=Grid.stack_limit(id)
			source.qty=int(source.qty)-int(part.qty)
			state.inventory_items.append(part)
			source=part
		if equipped:
			ok=state.unequip(slot)
			if ok:
				state.inventory_items=Grid.reconcile(state.inventory_items,state.stash,state.loadout)
				var before_ids: Dictionary = {}
				for r: Dictionary in snapshot.inventory_items:before_ids[r.uid]=true
				for r: Dictionary in state.inventory_items:
					if str(r.item)==id and not before_ids.has(r.uid):
						source=r
						break
		if ok and not source.is_empty():
			var merged: bool = false
			if cell.x>=0 and not block.is_empty():
				for target: Dictionary in state.inventory_items:
					if target.uid==source.uid or str(target.item)!=id or str(target.container)!=destination or str(target.get("block","0"))!=block:continue
					var rectangle:=Rect2i(Vector2i(int(target.x),int(target.y)),Grid.footprint(target,bool(target.rotated)))
					var room: int = Grid.stack_limit(id)-int(target.qty)
					if rectangle.has_point(cell) and room>0:
						var amount: int = mini(room,int(source.qty))
						target.qty=int(target.qty)+amount
						source.qty=int(source.qty)-amount
						if int(source.qty)<=0:state.inventory_items.erase(source)
						merged=true
						break
			if not merged:
				var spot: Dictionary = Grid.find_spot(source,destination,state.inventory_items,state.loadout,block,cell)
				if spot.is_empty():
					ok=false
					message="此区块没有能容纳该物品的空位"
				else:Grid.apply_spot(source,spot)
		elif ok:
			ok=false
			message="物品位置已更新，请重新选择"
	if ok:
		state.inventory_items=Grid.reconcile(state.inventory_items,state.stash,state.loadout)
		if Grid.overflow_count(state.inventory_items)>before_overflow:
			ok=false
			message="仓库已满，无法安置被替换的装备或容器内容物"
	state._grid_defer=false
	state._grid_preferred=""
	if not ok:
		if message.is_empty():message=state.last_error
		for field: String in FIELDS:state.set(field,snapshot[field])
		state._sync_aliases()
		return state._fail(message)
	update_ammo_plan(state)
	state._choose_active()
	state._commit()
	return true
static func quick_transfer(state: Node,uid: String) -> bool:
	if uid.begins_with("equip/"):return transfer(state,uid,"stash")
	var record: Dictionary = Grid.find_record(state.inventory_items,uid)
	if record.is_empty():return state._fail("物品不存在")
	if str(record.container) in ["rig","pockets","backpack"]:return transfer(state,uid,"stash")
	var item: Dictionary = Catalog.get_item(str(record.item))
	if str(item.get("kind",""))=="weapon":
		var slot: String = "sidearm" if str(item.get("category",""))=="pistol" else ("secondary" if not str(state.loadout.get("primary","")).is_empty() and str(state.loadout.get("secondary","")).is_empty() else "primary")
		return transfer(state,uid,"equip/"+slot)
	if str(item.get("kind",""))=="armor":return transfer(state,uid,"equip/"+Catalog.equipment_slot(str(record.item)))
	for container: String in ["rig","pockets","backpack"]:
		if not Grid.find_spot(record,container,state.inventory_items,state.loadout).is_empty():return transfer(state,uid,container)
	return state._fail("携行容器已满，请先腾出位置")
static func update_ammo_plan(state: Node) -> void:
	var plan: Dictionary = {}
	for id: String in state.ammo_carry_plan:plan[id]=0
	for record: Dictionary in state.inventory_items:
		if str(record.container) in ["rig","pockets","backpack"] and str(Catalog.get_item(str(record.item)).get("kind",""))=="ammo":plan[record.item]=int(plan.get(record.item,0))+int(record.qty)
	state.ammo_carry_plan=plan
static func rotate(state: Node,uid: String) -> bool:
	var record: Dictionary = Grid.find_record(state.inventory_items,uid)
	if record.is_empty():return state._fail("请选择仓库或容器中的物品")
	var rotated: bool = not bool(record.get("rotated",false))
	if not Grid.can_place(record,str(record.container),str(record.get("block","0")),Vector2i(int(record.x),int(record.y)),rotated,state.inventory_items,state.loadout):return state._fail("当前位置没有足够空间旋转")
	record.rotated=rotated
	state._commit()
	return true
static func sell_record(state: Node,uid: String) -> bool:
	var record: Dictionary = Grid.find_record(state.inventory_items,uid)
	if record.is_empty():return state._fail("先将装备卸下，再出售")
	state._grid_preferred=uid
	var result: bool = state.sell(str(record.item),int(record.qty))
	state._grid_preferred=""
	return result

static func split(state: Node,uid: String) -> bool:
	var source: Dictionary = Grid.find_record(state.inventory_items,uid)
	if source.is_empty() or int(source.qty)<2:return state._fail("此物品不能拆分")
	var record: Dictionary = source.duplicate(true)
	record.uid="split%d"%Time.get_ticks_usec()
	record.qty=int(source.qty)/2
	var spot: Dictionary = Grid.find_spot(record,str(source.container),state.inventory_items,state.loadout)
	if spot.is_empty():return state._fail("当前容器没有空格用于拆分")
	source.qty=int(source.qty)-int(record.qty)
	Grid.apply_spot(record,spot)
	state.inventory_items.append(record)
	state._commit()
	return true

static func attachment_transaction(state: Node,method: String,value: String) -> bool:
	var snapshot: Dictionary={}
	for field: String in FIELDS:
		var current: Variant=state.get(field)
		snapshot[field]=current.duplicate(true) if current is Dictionary or current is Array else current
	var old_overflow: int=Grid.overflow_count(state.inventory_items)
	state._grid_defer=true
	var ok: bool=bool(state.call(method,value))
	state._grid_defer=false
	if ok:
		state.inventory_items=Grid.reconcile(state.inventory_items,state.stash,state.loadout)
		ok=Grid.overflow_count(state.inventory_items)<=old_overflow
		if not ok:state._fail("仓库没有空间放置替换下来的配件")
	if not ok:
		var message: String=state.last_error
		for field: String in FIELDS:state.set(field,snapshot[field])
		state._sync_aliases()
		return state._fail(message)
	state._commit()
	return true
