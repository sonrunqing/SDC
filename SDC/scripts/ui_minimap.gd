extends Control

var info: Dictionary = {}
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/NotoSansSC.ttf") as Font

func update_info(value: Dictionary) -> void:
	info = value
	queue_redraw()

func _point(value: Vector2) -> Vector2:
	var bounds: Vector2 = info.get("map_bounds", Vector2(48,52))
	return Vector2(12 + (value.x / bounds.x + 0.5) * (size.x - 24), 28 + (value.y / bounds.y + 0.5) * (size.y - 40))

func _draw() -> void:
	draw_style_box(_box(), Rect2(Vector2.ZERO,size))
	for index in range(1,4):
		var x: float = 12 + (size.x - 24) * float(index) / 4.0
		var y: float = 28 + (size.y - 40) * float(index) / 4.0
		draw_line(Vector2(x,28),Vector2(x,size.y-12),Color(0.3,0.55,0.55,0.18),1)
		draw_line(Vector2(12,y),Vector2(size.x-12,y),Color(0.3,0.55,0.55,0.18),1)
	if _font: draw_string(_font,Vector2(12,21),"战术地图",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("b6c5ba"))
	for road:Dictionary in info.get("map_roads",[]):
		var start:Vector2=_point(road.position-road.size*.5)
		var end:Vector2=_point(road.position+road.size*.5)
		draw_rect(Rect2(start,end-start),Color("213d44"))
	var exit_pos: Vector2 = _point(info.get("extraction_position",Vector2.ZERO))
	draw_rect(Rect2(exit_pos-Vector2(5,5),Vector2(10,10)),Color("65d9b2"),false,1.5)
	for marker: Dictionary in info.get("minimap",[]):
		var pos: Vector2 = _point(marker.get("position",Vector2.ZERO))
		draw_circle(pos,2.0,Color("d77868") if marker.get("kind") == "enemy" else Color("d3ac65"))
	var player: Vector2 = _point(info.get("player_position",Vector2.ZERO))
	draw_circle(player,4.2,Color("79f0dc"))
	var heading: float = deg_to_rad(float(info.get("heading",0)))
	var direction := Vector2(sin(heading),-cos(heading))
	draw_line(player,player+direction*11,Color("cbf5ec"),1.8,true)

func _box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.07,0.09,0.88)
	style.border_color = Color(0.23,0.4,0.43,0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
