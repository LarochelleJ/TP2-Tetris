extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	load_animation()
	get_username()

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func load_animation():
	pass

func _on_LAN_pressed():
	get_tree().change_scene("res://Scenes/TetrisGameOnline.tscn")


func _on_1P_pressed():
	get_tree().change_scene("res://Scenes/TetrisGame.tscn")

func get_username():
	var username
	if OS.has_environment("USERNAME"):
		username = OS.get_environment("USERNAME")
	else:
		username = "Guest"
	get_node("SelectionMenu/Username").text = username
	GlobalVariables.local_username = username