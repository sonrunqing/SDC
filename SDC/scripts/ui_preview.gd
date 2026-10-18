extends Control

var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(500, 260)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/NotoSansSC.ttf") as Font

func _draw() -> void:
	var sx: float = size.x / 700.0
	var sy: float = size.y / 300.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(sx, sy))
	draw_rect(Rect2(0, 0, 700, 300), Color("111e25"))
	for n in range(-4, 15):
		draw_line(Vector2(n * 70, 0), Vector2(n * 70 + 200, 300), Color(0.34, 0.48, 0.5, 0.08), 1)
	for n in range(8):
		draw_line(Vector2(0, n * 45), Vector2(700, n * 45 - 70), Color(0.34, 0.48, 0.5, 0.08), 1)
	draw_colored_polygon(PackedVector2Array([Vector2(0,210), Vector2(700,145),Vector2(700,185),Vector2(0,250)]),Color("1f3036"))
	draw_line(Vector2(0,232),Vector2(700,166), Color("a28f52"),1.0)
	_container(Vector2(90,72),Vector2(130,42),Color("3e6266"))
	_container(Vector2(235,56),Vector2(130,42),Color("3e6266"))
	_container(Vector2(106,124),Vector2(130,42),Color("455b5d"))
	_container(Vector2(460,94),Vector2(150,48),Color("815442"))
	_container(Vector2(440,200),Vector2(150,48),Color("4d6470"))
	_container(Vector2(245,240),Vector2(100,35),Color("3d555a"))
	for pos: Vector2 in [Vector2(360,124),Vector2(392,122),Vector2(380,152),Vector2(161,256)]:
		_container(pos,Vector2(19,15),Color("898364"))
	draw_arc(Vector2(342,188),17,0,TAU,40,Color("66d8c3"),2,true)
	draw_circle(Vector2(342,188),4,Color("e2f5ea"))
	draw_line(Vector2(342,188),Vector2(384,176),Color(0.5,0.9,0.84,0.5),1.5,true)
	draw_rect(Rect2(616,35,45,60),Color(0.2,0.7,0.56,0.12))
	draw_rect(Rect2(616,35,45,60),Color("62c9af"),false,1)
	if _font:
		draw_string(_font,Vector2(20,30),"ZONE 07  /  灰港货运站",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("829d9f"))
		draw_string(_font,Vector2(612,25),"撤离点",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("74d5bd"))

func _container(pos: Vector2, dimensions: Vector2, color: Color) -> void:
	var v: Vector2 = Vector2(16,-10)
	var a: Vector2 = pos
	var b: Vector2 = pos + Vector2(dimensions.x, -dimensions.x * 0.1)
	var c: Vector2 = b + Vector2(dimensions.y * 0.4, dimensions.y)
	var d: Vector2 = a + Vector2(dimensions.y * 0.4, dimensions.y)
	draw_colored_polygon(PackedVector2Array([a,b,c,d]),color.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([a+v,b+v,c+v,d+v]),color)
	draw_colored_polygon(PackedVector2Array([d+v,c+v,c,d]),color.darkened(0.4))
	for x in range(7):
		var start: Vector2 = a.lerp(b,float(x)/7.0)+v
		draw_line(start,start + Vector2(dimensions.y*0.4,dimensions.y),color.lightened(0.14),1)
