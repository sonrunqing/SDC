extends Node
## Player-facing automation: real phone events and actual rendered frames.
var _peer:=StreamPeerTCP.new()
var _buffer: String=""
var _busy: bool=false
var _game: Control
var _touches: Dictionary={}
var _frame: int=0
var _next_shot: int=0
var _frozen_world: Node
var _directory: String
var _connected: bool=false

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--sdc-ai") or DisplayServer.get_name()=="headless":
		push_error("Visual AI player needs --sdc-ai and a rendering display (Xvfb works).")
		get_tree().quit(78)
		return
	_directory=OS.get_environment("SDC_AI_FRAMES")
	if not _directory.is_absolute_path():get_tree().quit(78);return
	var port: int=int(OS.get_environment("SDC_AI_PORT"))
	if _peer.connect_to_host("127.0.0.1",port)!=OK:get_tree().quit(78);return
	_game=load("res://scenes/main.tscn").instantiate()
	add_child(_game)
	for index: int in range(3):await get_tree().process_frame
	_peer.poll()
	if _peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:get_tree().quit(78);return
	_connected=true
	_send({"type":"ready","nonce":OS.get_environment("SDC_AI_NONCE"),"protocol":1,"mode":"real-touch-and-render"})

func _process(_delta: float) -> void:
	_peer.poll()
	if _peer.get_status()==StreamPeerTCP.STATUS_NONE:
		if _connected:get_tree().quit()
		return
	if _peer.get_status()==StreamPeerTCP.STATUS_ERROR:get_tree().quit();return
	var available: int=_peer.get_available_bytes()
	if available>0:
		_buffer+=_peer.get_utf8_string(available)
		if _buffer.length()>65536:get_tree().quit(78);return
	while _buffer.contains("\n"):
		var end: int=_buffer.find("\n")
		var request: Variant=JSON.parse_string(_buffer.substr(0,end))
		_buffer=_buffer.substr(end+1)
		if not request is Dictionary:_send({"error":"Expected JSON object"});continue
		if _busy:_send({"id":request.get("id"),"error":"busy"});continue
		_busy=true
		_execute.call_deferred(request)

func _send(value: Dictionary) -> void:
	_peer.put_data((JSON.stringify(value)+"\n").to_utf8_buffer())

func _execute(request: Dictionary) -> void:
	var operation: String=str(request.get("op","snapshot"))
	var error: String=""
	var film: Array=[]
	_next_shot=Time.get_ticks_msec()+100
	if operation!="snapshot":_thaw()
	match operation:
		"snapshot":pass
		"tap","double_tap":
			var point: Vector2=_point(request.get("at",[]))
			if point.x<0:error="at must be normalized [x,y] within the image"
			else:
				for index: int in range(2 if operation=="double_tap" else 1):
					_touch("down",0,point)
					await _wait(.07,film)
					_touch("up",0,point)
					if operation=="double_tap":await _wait(.08,film)
		"swipe":
			var start: Vector2=_point(request.get("from",[]))
			var end: Vector2=_point(request.get("to",[]))
			var duration: float=clampf(float(request.get("duration_ms",450)),100,2000)/1000.0
			if start.x<0 or end.x<0:error="from/to must be normalized [x,y]"
			else:
				_touch("down",0,start)
				await _wait(clampf(float(request.get("hold_ms",0)),0,1000)/1000.0,film)
				for index: int in range(1,17):
					_touch("move",0,start.lerp(end,float(index)/16))
					await _wait(duration/16,film)
				_touch("up",0,end)
		"touch_sequence":
			var events: Variant=request.get("events",[])
			var previous: float=0
			if not events is Array or events.size()>160:error="events must be an array of at most160 events"
			else:
				for event: Variant in events:
					if not event is Dictionary:error="Invalid touch event";break
					var at: float=float(event.get("ms",-1))
					var position_value: Vector2=_point(event.get("at",[]))
					var pointer: int=int(event.get("finger",0))
					var kind: String=str(event.get("type",""))
					if at<previous or at>10000 or position_value.x<0 or pointer<0 or pointer>9 or kind not in ["down","move","up"]:
						error="Invalid touch timing, coordinate, finger or type";break
					await _wait((at-previous)/1000.0,film)
					_touch(kind,pointer,position_value)
					previous=at
		"wait":await _wait(clampf(float(request.get("ms",250)),0,5000)/1000.0,film)
		"back":get_tree().root.go_back_requested.emit()
		"close":
			_send({"id":request.get("id"),"closed":true})
			get_tree().quit()
			return
		_:error="Unknown operation"
	# Every gesture is bounded. No held fire or movement survives agent thinking.
	for pointer: Variant in _touches.keys():_touch("up",int(pointer),_touches[pointer],true)
	await _wait(0 if operation=="snapshot" else clampf(float(request.get("settle_ms",160)),0,1500)/1000.0,film)
	_freeze()
	await RenderingServer.frame_post_draw
	var snapshot: Dictionary=_capture()
	snapshot["id"]=request.get("id")
	snapshot["film"]=film
	if not error.is_empty():snapshot["error"]=error
	_send(snapshot)
	_busy=false

func _point(value: Variant) -> Vector2:
	if not value is Array or value.size()!=2:return Vector2(-1,-1)
	if not (value[0] is float or value[0] is int) or not (value[1] is float or value[1] is int):return Vector2(-1,-1)
	var point:=Vector2(float(value[0]),float(value[1]))
	if not point.is_finite() or point.x<0 or point.x>1 or point.y<0 or point.y>1:return Vector2(-1,-1)
	# parse_input_event applies the window-to-canvas stretch itself.
	return point*Vector2(get_window().size)

func _touch(kind: String,pointer: int,at: Vector2,cancelled: bool = false) -> void:
	if kind=="move":
		if not _touches.has(pointer):return
		var drag:=InputEventScreenDrag.new()
		drag.index=pointer
		drag.position=at
		drag.relative=at-Vector2(_touches[pointer])
		Input.parse_input_event(drag)
		_touches[pointer]=at
	else:
		if kind=="down" and _touches.has(pointer):return
		if kind=="up" and not _touches.has(pointer):return
		var touch:=InputEventScreenTouch.new()
		touch.index=pointer
		touch.position=at
		touch.pressed=kind=="down"
		touch.canceled=cancelled
		Input.parse_input_event(touch)
		if touch.pressed:_touches[pointer]=at
		else:_touches.erase(pointer)

func _wait(seconds: float,film: Array) -> void:
	var until: int=Time.get_ticks_msec()+roundi(seconds*1000)
	while Time.get_ticks_msec()<until:
		await get_tree().process_frame
		if Time.get_ticks_msec()>=_next_shot and film.size()<40:
			await RenderingServer.frame_post_draw
			film.append(_capture(false).image)
			_next_shot=Time.get_ticks_msec()+120

func _freeze() -> void:
	var world: Node=_game._world
	if is_instance_valid(world) and world.is_physics_processing():
		_frozen_world=world
		world.set_physics_process(false)

func _thaw() -> void:
	if is_instance_valid(_frozen_world) and not get_tree().paused:
		_frozen_world.set_physics_process(true)
	_frozen_world=null

func _capture(include_ui: bool = true) -> Dictionary:
	_frame+=1
	var image: Image=get_viewport().get_texture().get_image()
	var path: String=_directory.path_join("frame-%06d.png"%_frame)
	var saved: Error=image.save_png(path)
	var result: Dictionary={"image":path,"width":image.get_width(),"height":image.get_height(),"frame":_frame,"saved":saved==OK}
	if include_ui:
		var elements: Array=[]
		_collect_ui(get_tree().root,elements)
		result["ui"]=elements
		result["screen"]=str(_game._tab)
	return result

func _collect_ui(node: Node,items: Array) -> void:
	if items.size()>=180:return
	if node is Control:
		var control: Control=node
		if not control.is_visible_in_tree():return
		var rect: Rect2=control.get_global_rect()
		var clip: Rect2=Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
		var ancestor: Node=control.get_parent()
		while ancestor!=null:
			if ancestor is Control and ancestor.clip_contents:clip=clip.intersection(ancestor.get_global_rect())
			ancestor=ancestor.get_parent()
		if not rect.intersects(clip):return
		var text: String=""
		if control is Label or control is BaseButton:text=str(control.text)
		if not text.is_empty():
			var bounds: Rect2=rect.intersection(clip)
			var size: Vector2=get_viewport().get_visible_rect().size
			items.append({"text":text.left(160),"type":control.get_class(),"rect":[bounds.position.x/size.x,bounds.position.y/size.y,bounds.size.x/size.x,bounds.size.y/size.y],"disabled":control is BaseButton and control.disabled})
	for child: Node in node.get_children():_collect_ui(child,items)
