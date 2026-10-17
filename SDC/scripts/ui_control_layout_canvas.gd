extends Control
signal selection_changed(id: String)
signal layout_changed
const Layout = preload("res://scripts/control_layout.gd")
var draft: Dictionary={}
var source_size := Vector2(1280,720)
var source_safe := Vector4(24,24,24,24)
var selected_id: String="fire"
var _preview: Control
var _font: Font
var _pointer: int=-99
var _grab_offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	_font=load("res://assets/fonts/NotoSansSC.ttf")
	_preview=preload("res://scripts/virtual_controls.gd").new()
	_preview.preview_mode=true
	_preview.enabled=true
	_preview.size=source_size
	add_child(_preview)
	refresh_preview()

func configure(layout: Dictionary,dimensions: Vector2,safe: Vector4,selection: String) -> void:
	draft=layout
	source_size=dimensions
	source_safe=safe
	selected_id=selection
	size=dimensions
	if is_instance_valid(_preview):
		_preview.size=dimensions
		refresh_preview()
	queue_redraw()

func refresh_preview() -> void:
	if not is_instance_valid(_preview):return
	var rectangles: Dictionary=Layout.rectangles(draft,source_size,source_safe)
	var conflicts: Array[String]=Layout.collisions(draft,rectangles)
	_preview.set_preview_layout(draft,source_safe,selected_id,conflicts)
	queue_redraw()

func select_control(id: String) -> void:
	selected_id=id
	refresh_preview()

func move_selected(offset: Vector2) -> void:
	var rect: Rect2=Layout.rectangles(draft,source_size,source_safe)[selected_id]
	Layout.set_center(draft,selected_id,rect.get_center()+offset,source_size,source_safe)
	refresh_preview()
	layout_changed.emit()

func _gui_input(event: InputEvent) -> void:
	# The emulated mouse press precedes the touch and must not claim its drag.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1:return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:_press(event.index,event.position)
		elif _pointer==event.index:_pointer=-99
		accept_event()
	elif event is InputEventScreenDrag and event.index==_pointer:
		_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:_press(-2,event.position)
		elif _pointer==-2:_pointer=-99
		accept_event()
	elif event is InputEventMouseMotion and _pointer==-2:
		_drag(event.position)
		accept_event()

func _press(pointer: int,point: Vector2) -> void:
	if _pointer!=-99:return
	var rects: Dictionary=Layout.rectangles(draft,source_size,source_safe)
	var id: String=Layout.pick(draft,rects,point,selected_id)
	if id.is_empty():return
	_pointer=pointer
	selected_id=id
	_grab_offset=point-(rects[id] as Rect2).get_center()
	selection_changed.emit(id)
	refresh_preview()

func _drag(point: Vector2) -> void:
	Layout.set_center(draft,selected_id,point-_grab_offset,source_size,source_safe)
	refresh_preview()
	layout_changed.emit()

func cancel_drag() -> void:
	_pointer=-99

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:cancel_drag()

func _draw() -> void:
	if _font==null:return
	draw_rect(Rect2(Vector2.ZERO,size),Color("0e1a20"))
	for x: int in range(0,int(size.x),64):draw_line(Vector2(x,0),Vector2(x,size.y),Color(.5,.65,.6,.08))
	for y: int in range(0,int(size.y),64):draw_line(Vector2(0,y),Vector2(size.x,y),Color(.5,.65,.6,.08))
	var area: Rect2=Layout.usable_rect(size,source_safe)
	draw_rect(area,Color("4d665f"),false,1)
	var hud:=Rect2(area.position,Vector2(300,94))
	draw_rect(hud,Color(.15,.23,.25,.6))
	draw_string(_font,hud.position+Vector2(14,34),"生命 100 / 100",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("879b93"))
	draw_string(_font,hud.position+Vector2(14,66),"弹药 30 / 90",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("879b93"))
	var map_rect:=Rect2(Vector2(area.end.x-186,area.position.y+184),Vector2(186,150))
	draw_rect(map_rect,Color(.15,.23,.25,.45))
	draw_string(_font,map_rect.position+Vector2(55,82),"地图",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("879b93"))
	draw_string(_font,Vector2(area.get_center().x-120,area.get_center().y),"拖动按键调整位置",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("6f8880"))
