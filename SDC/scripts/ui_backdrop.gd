extends Control
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0d151b"))
	draw_colored_polygon(PackedVector2Array([Vector2(size.x*.36,0),Vector2(size.x*.72,0),Vector2(size.x*.34,size.y),Vector2(0,size.y)]),Color("16242b"))
	for x: int in range(0,int(size.x),52):draw_line(Vector2(x,0),Vector2(x,size.y),Color(.42,.54,.53,.055))
	for y: int in range(0,int(size.y),52):draw_line(Vector2(0,y),Vector2(size.x,y),Color(.42,.54,.53,.055))
	draw_line(Vector2(24,9),Vector2(size.x-24,9),Color("b08f58"),2)
