extends ShapeX

func _ready():
	rotation_matrix = [
		[Vector2(40,0), Vector2(40,40), Vector2(80,40), Vector2(80,80)],
		[Vector2(80,0), Vector2(40,0), Vector2(40,40), Vector2(0,40)],
		[Vector2(40,80), Vector2(40,40), Vector2(0,40), Vector2(0,0)],
		[Vector2(0,80), Vector2(40,80), Vector2(40,40), Vector2(80,40)]
	]
