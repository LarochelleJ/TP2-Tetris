extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var test = Vector2(10, 20)
	var test2 = [Vector2(10, 20), Vector2(20, 30)]
	var test3 = [2]
	for wtf in test2:
		print(wtf)
		print(wtf.x)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
