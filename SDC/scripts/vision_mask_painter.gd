extends Control
## Opaque union mask, following Ashfront VisionMaskPainter's triangle fan.
var polygons: Array[PackedVector2Array]=[]
func _draw() -> void:
	for polygon: PackedVector2Array in polygons:
		for index: int in range(1,polygon.size()-1):
			var a: Vector2=polygon[0]
			var b: Vector2=polygon[index]
			var c: Vector2=polygon[index+1]
			if absf((b-a).cross(c-a))<.1:continue
			draw_colored_polygon(PackedVector2Array([a,b,c]),Color.WHITE)
