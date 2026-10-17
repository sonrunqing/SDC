extends SceneTree
## Actual screen: readonly draft, immediate model, displayed price, one-button purchase.
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	var state: Node = root.get_node("GameState")
	var catalog: Node = root.get_node("Catalog")
	state.reset_progress()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call("_select_tab","workbench")
	await process_frame
	var preview: Control = main.get("_wb_preview")
	var node_id: int = preview.get_instance_id()
	var before: String = JSON.stringify([state.credits,state.stash,state.weapon_builds,state.loadout])
	var gun: String = str(main.get("_draft_weapon"))
	var part: String = str(catalog.compatible_attachments(gun,"muzzle")[0].id)
	check(main.call("_draft_choose_part",part),"Compatible accessory can be selected on assembly screen")
	check(main.get("_wb_preview").get_instance_id() == node_id,"Changing parts preserves the interactive viewport")
	var summary: Dictionary = preview.call("get_build_summary")
	check(summary.parts.get("muzzle","") == part and bool(summary.valid),"Selection immediately replaces the physical model on screen")
	check(JSON.stringify([state.credits,state.stash,state.weapon_builds,state.loadout]) == before,"Screen selection has not purchased anything")
	var quote: Dictionary = state.quote_build(gun,main.get("_draft_parts"),"primary")
	var button: Button = main.get("_wb_commit")
	var quote_label: Label = main.get("_wb_quote")
	check(not button.disabled and quote_label.text.contains(str(main.call("_number",int(quote.cost)))),"Actual whole-build price is shown before the enabled purchase button")
	var cash_before: int = state.credits
	button.pressed.emit()
	await process_frame
	check(state.credits == cash_before-int(quote.cost),"One screen button debits the displayed total once")
	check(state.weapon_builds.primary.get("muzzle","") == part,"One screen button automatically equips the combined gun into primary")
	var replacement: String = str(catalog.compatible_attachments(gun,"muzzle")[1].id)
	check(main.call("_draft_choose_part",replacement),"Draft can be changed after purchasing")
	var draft_before: Dictionary = main.get("_draft_parts").duplicate(true)
	var installed_before: Dictionary = state.weapon_builds.duplicate(true)
	state.credits = 0
	check(not bool(main.call("_commit_draft")),"Unfunded screen commit is rejected")
	check(state.weapon_builds == installed_before and main.get("_draft_parts") == draft_before,"Purchase failure preserves equipped kit and proposed visible assembly")
	main.queue_free()
	await process_frame
	await process_frame
	print("WORKBENCH TESTS ","PASS" if failures == 0 else "FAIL",": ",checks," checks; visible draft, quote, one-button procurement")
	quit(0 if failures == 0 else 1)
