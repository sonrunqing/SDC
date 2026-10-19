extends SceneTree
## Raw phone pointers: independent sticks/fire, release-only actions and contextual keys.
var checks: int=0
var failures: int=0
var observed: Dictionary={"move":Vector2.ZERO,"aim":Vector2.ZERO,"fire":false,"heal":0,"weapon":""}

func _initialize() -> void:call_deferred("run")

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)

func touch(control: Control,finger: int,id: String,pressed: bool,offset: Vector2=Vector2.ZERO) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=finger
	event.position=control.get_global_transform_with_canvas()*(control.get_control_rects()[id].get_center()+offset)
	event.pressed=pressed
	control._input(event)

func run() -> void:
	var control: Control=load("res://scripts/virtual_controls.gd").new()
	root.add_child(control)
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size=Vector2(1280,720)
	control.move_changed.connect(func(value: Vector2):observed.move=value)
	control.aim_changed.connect(func(value: Vector2):observed.aim=value)
	control.fire_changed.connect(func(value: bool):observed.fire=value)
	control.medkit_pressed.connect(func():observed.heal+=1)
	control.weapon_pressed.connect(func(slot: String):observed.weapon=slot)
	control.set_weapons([{"slot":"primary","available":true},{"slot":"secondary","available":false}])
	control.enabled=true
	touch(control,0,"move",true,Vector2(30,0))
	touch(control,1,"aim",true,Vector2(0,-30))
	check(observed.move.x>.2 and observed.aim.y<-.2,"both real sticks own independent pointers")
	check(not observed.fire,"movement and aiming never fire")
	touch(control,2,"fire",true)
	check(observed.fire,"third finger alone starts fire")
	touch(control,0,"move",false)
	check(observed.move.is_zero_approx() and observed.fire and not observed.aim.is_zero_approx(),"move release preserves aim and fire")
	touch(control,2,"fire",false)
	check(not observed.fire and not observed.aim.is_zero_approx(),"fire release preserves aim")
	touch(control,1,"aim",false)
	touch(control,3,"heal",true)
	check(observed.heal==0,"action does not trigger before release")
	touch(control,3,"heal",false)
	check(observed.heal==1,"owning release triggers the action once")
	touch(control,4,"weapon_primary",true)
	touch(control,4,"weapon_primary",false)
	check(observed.weapon.is_empty(),"redundant single-weapon key cannot capture an action")
	control.set_weapons([{"slot":"primary","available":true},{"slot":"secondary","available":true},{"slot":"sidearm","available":false}])
	touch(control,4,"weapon_secondary",true)
	touch(control,4,"weapon_secondary",false)
	check(observed.weapon=="secondary","an available second weapon is selectable")
	check(not control._context_visible("weapon_sidearm"),"empty weapon key remains hidden")
	control.preview_mode=true
	check(control._context_visible("weapon_sidearm") and control._context_visible("interact"),"layout editor retains all controls")
	control.preview_mode=false
	touch(control,0,"move",true,Vector2(30,0))
	touch(control,2,"fire",true)
	var modal:=Control.new()
	root.add_child(modal)
	modal.add_to_group("mobile_touch_modal")
	touch(control,1,"aim",true)
	check(observed.move.is_zero_approx() and not observed.fire,"opening a modal releases existing gameplay pointers")
	modal.queue_free()
	control.enabled=false
	control.queue_free()
	await process_frame
	print("TOUCH ","PASS" if failures==0 else "FAIL",": ",checks," checks")
	quit(0 if failures==0 else 1)
