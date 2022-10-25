extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	load_animation()
	get_username()
	play_animation()
	$HTTPRequest.connect("request_completed", self, "_on_request_completed")
	$HTTPRequest.request("https://larochellej.com/ip_tetris.json")

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

func play_animation():
	get_node("SelectionMenu/MenuLoad").play("MenuLoad")

func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse(body.get_string_from_utf8())
	if typeof(json.result) == TYPE_ARRAY:
		GlobalVariables.server_ip = json.result[0]
	print("Server ip: ", GlobalVariables.server_ip)