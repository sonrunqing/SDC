extends Control
const Grid = preload("res://scripts/inventory_grid.gd")
var container_id: String = "stash"
var block_id: String = "0"
var columns: int = 10
var rows: int = 50
var cell: float = 50
var equipment_slot: String = ""
var caption: String = ""
## Presentation-only alias of an existing equipment record, never saved or counted.
var display_override: Dictionary = {}
var display_alpha: float = 1.0
var display_note: String = ""
var selected_uid: String = ""
var hover_spot: Dictionary = {}
var _font: Font
var _textures: Dictionary = {}

func _ready() -> void:
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	mouse_filter=Control.MOUSE_FILTER_PASS
	if equipment_slot.is_empty():custom_minimum_size=Vector2(columns*cell,rows*cell)

func records() -> Array:
	if not display_override.is_empty():return [display_override]
	if not equipment_slot.is_empty():
		var id: String = str(GameState.loadout.get(equipment_slot,""))
		return [] if id.is_empty() else [{"uid":"equip/"+equipment_slot,"item":id,"qty":1,"x":0,"y":0,"rotated":false}]
	var output: Array = []
	for record: Dictionary in GameState.inventory_items:
		if str(record.container)==container_id and str(record.get("block","0"))==block_id:output.append(record)
	return output

func record_rect(record: Dictionary) -> Rect2:
	if not equipment_slot.is_empty():return Rect2(Vector2(2,23),size-Vector2(4,25))
	var footprint: Vector2i = Grid.footprint(record,bool(record.get("rotated",false)))
	return Rect2(Vector2(float(record.get("x",0)),float(record.get("y",0)))*cell,Vector2(footprint)*cell).grow(-2)

func hit(global: Vector2) -> Dictionary:
	if not is_visible_in_tree():return {}
	var local: Vector2 = get_global_transform_with_canvas().affine_inverse()*global
	if not Rect2(Vector2.ZERO,size).has_point(local):return {}
	var ancestor: Node = get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer and not ancestor.get_global_rect().has_point(global):return {}
		ancestor=ancestor.get_parent()
	var uid: String = ""
	for record: Dictionary in records():
		if record_rect(record).has_point(local):uid=str(record.uid)
	# The alias identifies the real drag/selection source. Its destination stays
	# this displayed slot, so a new armor item can replace a combined rig here.
	return {"view":self,"uid":uid,"container":"equip/"+equipment_slot if not equipment_slot.is_empty() else container_id,"block":block_id,"cell":Vector2i(floori(local.x/cell),floori(local.y/cell))}

func _draw() -> void:
	if _font==null:return
	draw_rect(Rect2(Vector2.ZERO,size),Color("111b20"))
	if equipment_slot.is_empty():
		for y: int in range(rows):
			for x: int in range(columns):
				var rectangle:=Rect2(Vector2(x,y)*cell+Vector2.ONE,Vector2.ONE*(cell-2))
				draw_rect(rectangle,Color("202b31"))
				draw_rect(rectangle,Color("3a484e"),false,1)
	else:
		draw_rect(Rect2(Vector2.ZERO,size),Color("4c5d62"),false,1)
		draw_string(_font,Vector2(10,20),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-16,16,Color("b0bdbb"))
	for record: Dictionary in records():
		var rectangle: Rect2 = record_rect(record)
		var item: Dictionary = Catalog.get_item(str(record.item))
		var level: int = int(item.get("level",0))
		var tone: Color = [Color("53645e"),Color("59755b"),Color("496c82"),Color("77658b"),Color("ad8853")][clampi(level,0,4)]
		draw_rect(rectangle,Color(tone,.24*display_alpha))
		var border: Color=Color("dfe7e4") if str(record.uid)==selected_uid else tone
		border.a=display_alpha
		draw_rect(rectangle,border,false,3 if str(record.uid)==selected_uid else 1)
		_draw_icon(str(record.item),rectangle.grow(-4),bool(record.get("rotated",false)),display_alpha)
		if int(record.qty)>1:draw_string(_font,rectangle.end-Vector2(28,5),str(record.qty),HORIZONTAL_ALIGNMENT_RIGHT,-1,16,Color(Color("f7ead3"),display_alpha))
		if rectangle.size.x>110:draw_string(_font,rectangle.position+Vector2(6,rectangle.size.y-7),str(item.get("name","")),HORIZONTAL_ALIGNMENT_LEFT,rectangle.size.x-12,15,Color(Color("f2f0e7"),display_alpha))
		if not display_note.is_empty():draw_string(_font,rectangle.position+Vector2(4,15),display_note,HORIZONTAL_ALIGNMENT_LEFT,rectangle.size.x-8,12,Color("b0bdbb"))
	if not hover_spot.is_empty():
		var rectangle: Rect2 = Rect2(Vector2(int(hover_spot.x),int(hover_spot.y))*cell,Vector2(hover_spot.get("size",Vector2i.ONE))*cell).grow(-1)
		draw_rect(rectangle,Color(.44,.86,.65,.28))
		draw_rect(rectangle,Color("91dab3"),false,3)

func _draw_icon(id: String, rectangle: Rect2, rotated: bool,alpha: float = 1.0) -> void:
	if not _textures.has(id):
		_textures[id]=preload("res://scripts/item_textures.gd").icon(id)
	var texture: Texture2D = _textures[id]
	if texture==null:
		draw_string(_font,rectangle.position+Vector2(3,24),str(Catalog.get_item(id).get("name","")).left(3),HORIZONTAL_ALIGNMENT_LEFT,rectangle.size.x,15,Color(Color("cbd4cc"),alpha))
		return
	var natural: Vector2 = texture.get_size()
	if rotated:natural=Vector2(natural.y,natural.x)
	var scale_factor: float = minf(rectangle.size.x/natural.x,rectangle.size.y/natural.y)
	var dimensions: Vector2 = texture.get_size()*scale_factor
	draw_set_transform(rectangle.get_center(),PI*.5 if rotated else 0)
	draw_texture_rect(texture,Rect2(-dimensions*.5,dimensions),false,Color(1,1,1,alpha))
	draw_set_transform(Vector2.ZERO)
