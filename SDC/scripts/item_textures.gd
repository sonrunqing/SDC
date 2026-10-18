extends RefCounted
## Trim transparent render padding, then preserve the model's proportions in UI.
static var cache: Dictionary = {}
static func icon(id: String) -> Texture2D:
	if cache.has(id):return cache[id]
	var path: String="res://assets/icons/items/"+id+".png"
	if not ResourceLoader.exists(path):
		var item: Dictionary=Catalog.get_item(id)
		var visual_alias: String=str(item.get("visual_alias",""))
		if not visual_alias.is_empty():path="res://assets/icons/items/"+visual_alias+".png"
	if not ResourceLoader.exists(path):
		cache[id]=null
		return null
	var texture: Texture2D=load(path)
	var bitmap: Image=texture.get_image()
	if bitmap!=null:
		if bitmap.is_compressed():bitmap.decompress()
		var used: Rect2i=bitmap.get_used_rect()
		if used.has_area():
			var atlas:=AtlasTexture.new()
			atlas.atlas=texture
			atlas.region=Rect2(used.grow(2).intersection(Rect2i(Vector2i.ZERO,bitmap.get_size())))
			cache[id]=atlas
			return atlas
	cache[id]=texture
	return texture
