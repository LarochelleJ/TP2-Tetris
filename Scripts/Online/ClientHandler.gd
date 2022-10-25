extends Node

const HOST: String = "192.168.0.1"
const PORT: int = 2121
const RECONNECT_TIMEOUT: float = 3.0

const Client = preload("res://Scripts/Online/client.gd")
var _client: Client = Client.new()
var _game_manager
var _game_manager_opponent


func _ready() -> void:
	_client.connect("connected", self, "_handle_client_connected")
	_client.connect("disconnected", self, "_handle_client_disconnected")
	_client.connect("error", self, "_handle_client_error")
	_client.connect("data", self, "_handle_client_data")
	add_child(_client)
	_game_manager = get_parent()
	_game_manager.client_handler = self;
	_game_manager_opponent = get_parent().get_node("Opponent")
	_client.connect_to_host(HOST, PORT)

func _connect_after_timeout(timeout: float) -> void:
	yield(get_tree().create_timer(timeout), "timeout") # Delay for timeout
	_client.connect_to_host(HOST, PORT)

func _handle_client_connected() -> void:
	print("Client connected to server.")

func _handle_client_data(data: PoolByteArray) -> void:
	for packet in filter_with_custom_codec(data):
		var formated_packet = packet.get_string_from_utf8().strip_edges()
		print("Packet received: ", formated_packet)
		parse_packet(formated_packet)

func _handle_client_disconnected() -> void:
	print("Client disconnected from server.")
	_connect_after_timeout(RECONNECT_TIMEOUT) # Try to reconnect after 3 seconds

func _handle_client_error() -> void:
	print("Client error.")
	_connect_after_timeout(RECONNECT_TIMEOUT) # Try to reconnect after 3 seconds

func parse_packet(packet):
	var args = packet.split("|")
	if (len(args) > 0):
		if (_game_manager_opponent.cur_shape != null):
		# Packet that require an active ShapeX to work
			match (args[0]):
				"r":
					_game_manager_opponent.cur_shape.right()
					_game_manager_opponent.cur_shape.cur_direction = _game_manager_opponent.cur_shape.direction.Right
				"l":
					_game_manager_opponent.cur_shape.left()
					_game_manager_opponent.cur_shape.cur_direction = _game_manager_opponent.cur_shape.direction.Left
				"ro":
					_game_manager_opponent.cur_shape.rotate()
				"d":
					var timer_time = float(args[1])
					_game_manager_opponent.cur_shape.down(timer_time)
				"sd":
					_game_manager_opponent.cur_shape.slide_down(9999) #Bypass timer
				"sb":
					_game_manager_opponent.cur_shape.space_bar()
				_:
					pass
		
		# Packets that doesnt work with ShapeX
		match (args[0]):
			"p":
				_game_manager_opponent.spawn_shape(int(args[1]))
			"po":
				_game_manager_opponent.refresh_points(args[1])
			"start":
				_game_manager.isPaused = false
				_game_manager.timer.start()
			"ready":
				send_packet(str("ready|", _game_manager.cur_shape.type, "|", GlobalVariables.local_username))
			"ts":
				_game_manager.set_status_message(args[1])
			"username":
				_game_manager_opponent.set_name(args[1])
			"best":
				_game_manager.set_best(args[1], args[2])
			"win":
				_game_manager.set_endgame(args[1])
			_:
				pass

func send_packet(packet):
	var formated_packet = packet.to_utf8() + PoolByteArray([10]) # We terminate the message with 0x0A
	if(_client.send(formated_packet)):
		print("Sent packet: ", packet)

# Use the terimation 0x0A to seperate the packets in the TCP stream
func filter_with_custom_codec(data):
	var cursor = 0
	var terminations_indexes = []
	var packets = []

	for index in range(len(data)):
		if (data[index] == 10): #0x0A
			terminations_indexes.append(index)
	
	if (len(terminations_indexes) > 0):
		for index in terminations_indexes:
			packets.append(data.subarray(cursor, index-1))
			cursor = index+1
	else:
		packets.append(data) 
	
	return packets


