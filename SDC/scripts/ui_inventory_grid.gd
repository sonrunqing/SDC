extends Control
const Grid = preload("res://scripts/inventory_grid.gd")
const Rarity = preload("res://scripts/item_rarity.gd")
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
## Raid search views provide live carried/container records without using stash.
var use_source_records: bool=false
var source_records: Array=[]
var concealed_uids: Dictionary={}
var searching_uid: String="":
	set(next):
		if next!=searching_uid:_display_progress=0
		searching_uid=next
var search_progress: float=0
var animate_search: bool=false
var search_paused: bool=false
var opening_progress: float=1
var reveal_ages: Dictionary={}
var _animation_clock: float=0
var _redraw_clock: float=0
var _display_progress: float=0

func advance_search_animation(delta: float) -> void:
	if not animate_search:return
	if not search_paused:_animation_clock+=delta
	_display_progress=move_toward(_display_progress,clampf(search_progress,0,1),delta*3)
	var fading: bool=not reveal_ages.is_empty()
	for uid: String in reveal_ages.keys():
		reveal_ages[uid]=float(reveal_ages[uid])+delta
		if float(reveal_ages[uid])>=.55:reveal_ages.erase(uid)
	_redraw_clock+=delta
	if _redraw_clock>=1.0/30.0 and (fading or opening_progress<1 or (not searching_uid.is_empty() and not search_paused)):
		_redraw_clock=0
		queue_redraw()

func _ready() -> void:
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	mouse_filter=Control.MOUSE_FILTER_PASS
	if equipment_slot.is_empty():custom_minimum_size=Vector2(columns*cell,rows*cell)

func records() -> Array:
	if use_source_records:
		var matches: Array=[]
		for record: Dictionary in source_records:
			if int(record.get("qty",0))>0 and str(record.get("container",""))==container_id and str(record.get("block","0"))==block_id:matches.append(record)
		return matches
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
		if concealed_uids.has(str(record.uid)):
			_draw_unknown(rectangle,str(record.uid)==searching_uid)
			continue
		var item: Dictionary = Catalog.get_item(str(record.item))
		var valuable: bool=str(item.get("kind",""))=="loot"
		var level: int = int(item.get("level",0))
		var tone: Color = Rarity.tone(item) if valuable else [Color("53645e"),Color("59755b"),Color("496c82"),Color("77658b"),Color("ad8853")][clampi(level,0,4)]
		var reveal: float=1.0-pow(1.0-clampf(float(reveal_ages.get(str(record.uid),.55))/.4,0,1),3)
		var alpha: float=display_alpha*(.12+.88*reveal)
		# Valuable rarity backgrounds: 1.6x, then another 2x, per visual feedback.
		draw_rect(rectangle,Color(tone,(.448 if valuable else .24)*alpha))
		if reveal<1 and not valuable:draw_rect(rectangle,Color(.76,.84,.74,(1-reveal)*.20))
		var border: Color=Color("dfe7e4") if str(record.uid)==selected_uid else tone
		border.a=display_alpha if str(record.uid)==selected_uid or not valuable else display_alpha*.42
		draw_rect(rectangle,border,false,3 if str(record.uid)==selected_uid else 1)
		var icon_box: Rect2=rectangle.grow(-4)
		var scale_reveal: float=.88+.12*reveal
		icon_box=Rect2(icon_box.get_center()-icon_box.size*scale_reveal*.5+Vector2(0,(1-reveal)*5),icon_box.size*scale_reveal)
		_draw_icon(str(record.item),icon_box,bool(record.get("rotated",false)),alpha)
		if int(record.qty)>1:draw_string(_font,rectangle.end-Vector2(28,5),str(record.qty),HORIZONTAL_ALIGNMENT_RIGHT,-1,16,Color(Color("f7ead3"),alpha))
		if rectangle.size.x>110:draw_string(_font,rectangle.position+Vector2(6,rectangle.size.y-7),str(item.get("name","")),HORIZONTAL_ALIGNMENT_LEFT,rectangle.size.x-12,15,Color(Color("f2f0e7"),alpha))
		if not display_note.is_empty():draw_string(_font,rectangle.position+Vector2(4,15),display_note,HORIZONTAL_ALIGNMENT_LEFT,rectangle.size.x-8,12,Color("b0bdbb"))
	if animate_search and opening_progress<1:_draw_opening()
	if not hover_spot.is_empty():
		var rectangle: Rect2 = Rect2(Vector2(int(hover_spot.x),int(hover_spot.y))*cell,Vector2(hover_spot.get("size",Vector2i.ONE))*cell).grow(-1)
		draw_rect(rectangle,Color(.44,.86,.65,.28))
		draw_rect(rectangle,Color("91dab3"),false,3)

func _draw_unknown(rectangle: Rect2,active: bool) -> void:
	var center: Vector2=rectangle.get_center()
	draw_rect(rectangle,Color("2c3036") if active else Color("24282d"))
	draw_rect(rectangle,Color("92979c") if active else Color("4c5157"),false,1)
	if not active:
		draw_string(_font,center+Vector2(-6,7),"?",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("858a90"))
		return
	var progress: float=_display_progress if animate_search else search_progress
	if not search_paused:
		var scan: float=rectangle.position.y+fmod(_animation_clock*.8,1.0)*rectangle.size.y
		for step: int in range(7):
			var top: float=maxf(rectangle.position.y,scan-float(step)*2)
			var bottom: float=minf(rectangle.end.y,scan-float(step)*2+2)
			if bottom>top:draw_rect(Rect2(rectangle.position.x,top,rectangle.size.x,bottom-top),Color(.74,.74,.74,.16*(1-float(step)/7)))
		var line_y: float=clampf(scan,rectangle.position.y,rectangle.end.y-1)
		draw_line(Vector2(rectangle.position.x,line_y),Vector2(rectangle.end.x,line_y),Color("b5b9bf"),1)
	var icon_center: Vector2=center-Vector2(0,5)
	draw_arc(icon_center,15,0,TAU,36,Color("4b5056"),2,true)
	var phase: float=_animation_clock*3
	draw_arc(icon_center,15,phase,phase+TAU*.72,28,Color("c6c9cf"),2,true)
	if search_paused:
		for x: float in [-3,3]:draw_line(icon_center+Vector2(x,-5),icon_center+Vector2(x,5),Color("c6c9cf"),2,true)
	else:
		draw_arc(icon_center-Vector2(2,2),5.5,0,TAU,20,Color("d5d8dd"),1.5,true)
		draw_line(icon_center+Vector2(2,2),icon_center+Vector2(7,7),Color("d5d8dd"),2,true)
	var percent: String="%d%%"%roundi(progress*100)
	var width: float=_font.get_string_size(percent,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
	draw_string(_font,Vector2(center.x-width*.5,rectangle.end.y-7),percent,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ccd0d5"))
	draw_rect(Rect2(rectangle.position.x,rectangle.end.y-3,rectangle.size.x*progress,3),Color("b8bec4"))
	for corner: Vector2 in [rectangle.position,Vector2(rectangle.end.x,rectangle.position.y),rectangle.end,Vector2(rectangle.position.x,rectangle.end.y)]:
		var horizontal: float=7 if corner.x==rectangle.position.x else -7
		var vertical: float=7 if corner.y==rectangle.position.y else -7
		draw_line(corner,corner+Vector2(horizontal,0),Color("b8bec4"),2)
		draw_line(corner,corner+Vector2(0,vertical),Color("b8bec4"),2)

func _draw_opening() -> void:
	var extent:=Vector2(columns,rows)*cell
	var eased: float=1.0-pow(1.0-opening_progress,3)
	var width: float=extent.x*.5*(1.0-eased)
	for x: float in [0.0,extent.x-width]:
		draw_rect(Rect2(x,0,width,extent.y),Color("28333a"))
	var text: String="打开容器"
	var text_width: float=_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
	draw_string(_font,extent*.5+Vector2(-text_width*.5,8),text,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color(.8,.84,.79,1.0-opening_progress))

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
