extends Control
## Ashfront's four-arm crosshair, driven by the phone's world aim state.
## This CanvasItem is visual only and never captures or emits input.
var _point:=Vector2.ZERO
var _muzzle:=Vector2.ZERO
var _spread: float=0

func _ready() -> void:
	name="TouchAimReticle"
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func present(camera: Camera3D,state: Dictionary) -> void:
	visible=bool(state.get("visible",false)) and is_instance_valid(camera)
	if not visible:return
	var at: Vector3=state.point
	if camera.is_position_behind(at):hide();return
	_point=camera.unproject_position(at)
	_muzzle=camera.unproject_position(state.muzzle)
	_spread=clampf(rad_to_deg(float(state.spread)) * 4.0,0,18)
	queue_redraw()

func _draw() -> void:
	var scale: float=clampf(get_viewport_rect().size.y/720.0,.9,1.6)
	var gap: float=(6.0+_spread)*scale
	var length: float=11.0*scale
	var ink:=Color(.025,.035,.045,.9)
	var light:=Color(.98,.97,.91,.98)
	# A short muzzle-side tick makes the weapon-to-reticle direction readable.
	var toward: Vector2=_point-_muzzle
	if toward.length()>gap+length+26*scale:
		var direction: Vector2=toward.normalized()
		draw_line(_muzzle+direction*5*scale,_muzzle+direction*19*scale,ink,3.5*scale,true)
		draw_line(_muzzle+direction*5*scale,_muzzle+direction*19*scale,Color(light,.55),1.25*scale,true)
	for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var from: Vector2=_point+direction*gap
		var to: Vector2=_point+direction*(gap+length)
		draw_line(from,to,ink,4.5*scale,true)
		draw_line(from,to,light,2.2*scale,true)
	draw_circle(_point,3.0*scale,ink)
	draw_circle(_point,1.5*scale,light)
