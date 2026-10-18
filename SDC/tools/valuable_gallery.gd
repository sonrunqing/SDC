extends Control
## Production-grid art capture; never changes inventory or simulates user input.
const Rarity=preload("res://scripts/item_rarity.gd")
const GridView=preload("res://scripts/ui_inventory_grid.gd")
const Grid=preload("res://scripts/inventory_grid.gd")
var _destination: String="D:/aa/SDC-tools/previews/SDC-v0.4.11-valuables.png"
func _ready() -> void:call_deferred("capture")
func label(text: String,font_size: int=18) -> Label:
	var node:=Label.new();node.text=text;node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("e5e8e5"));return node
func capture() -> void:
	var mode: String="gallery"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):_destination=arg.trim_prefix("--out=")
		if arg.begins_with("--mode="):mode=arg.trim_prefix("--mode=")
	var window: Window=get_tree().root
	window.size=Vector2i(1520,1360) if mode=="gallery" else Vector2i(1100,500)
	window.content_scale_size=window.size
	DisplayServer.window_set_size(window.size)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background:=ColorRect.new();background.color=Color("14191f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var font: Font=load("res://assets/fonts/NotoSansSC.ttf")
	theme=Theme.new();theme.default_font=font
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,24)
	add_child(margin)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",10);margin.add_child(body)
	body.add_child(label("SDC  /  48 种变卖物 · 8 类",30) if mode=="gallery" else label("稀有度颜色：发现后显示，搜索前完全隐藏",28))
	if mode=="gallery":
		body.add_child(label("工业品 7  ·  收藏品 7  ·  生活物品 14  ·  高精度仪器 4  ·  金属 5  ·  电子元件 5  ·  医疗物资 3  ·  机修工具 3",17))
		var cards:=GridContainer.new();cards.columns=8
		cards.add_theme_constant_override("h_separation",12);cards.add_theme_constant_override("v_separation",12);body.add_child(cards)
		for item: Dictionary in Catalog.items.values():
			if str(item.kind)!="loot":continue
			var card:=VBoxContainer.new();card.custom_minimum_size=Vector2(173,198)
			card.add_theme_constant_override("separation",3);cards.add_child(card)
			var title:=label(str(item.name),17);title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;card.add_child(title)
			var center:=CenterContainer.new();center.custom_minimum_size=Vector2(173,145);card.add_child(center)
			var view:=GridView.new();view.use_source_records=true;view.container_id="gallery"
			var cells: Vector2i=Grid.item_size(str(item.id));view.columns=cells.x;view.rows=cells.y;view.cell=140.0/maxi(cells.x,cells.y)
			view.source_records=[{"uid":str(item.id),"item":str(item.id),"qty":1,"container":"gallery","block":"0","x":0,"y":0,"rotated":false}]
			center.add_child(view)
			var caption:=label(Rarity.group_label(item)+" · "+Rarity.label(item),13);caption.modulate=Color("a9b2b6");card.add_child(caption)
	else:
		for hidden: bool in [true,false]:
			body.add_child(label("未搜索：同一中性背景，不展示品质" if hidden else "已发现：灰 / 绿 / 蓝 / 黄 / 红（淡色）",20))
			var view:=GridView.new();view.use_source_records=true;view.container_id="gallery";view.columns=5;view.rows=1;view.cell=150
			var index: int=0
			for id: String in ["loot_wire","loot_tools","loot_radio","loot_watch","loot_statue"]:
				view.source_records.append({"uid":id,"item":id,"qty":1,"container":"gallery","block":"0","x":index,"y":0,"rotated":false})
				if hidden:view.concealed_uids[id]=true
				index+=1
			body.add_child(view)
	for frame: int in range(8):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_destination.get_base_dir())
	var result: Error=window.get_texture().get_image().save_png(_destination)
	print("VALUABLE_GALLERY ",mode," ",_destination," result=",result)
	get_tree().quit(result)
