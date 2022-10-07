extends Node

const HOST: String = "127.0.0.1"
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
	send_packet(str("p|", _game_manager.cur_shape.type))

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
		match (args[0]):
			"r":
				_game_manager_opponent.cur_shape.right()
			"l":
				_game_manager_opponent.cur_shape.left()
			"ro":
				_game_manager_opponent.cur_shape.rotate()
			"d":
				_game_manager_opponent.cur_shape.down()
			"sd":
				_game_manager_opponent.cur_shape.slide_down(9999) #Bypass timer
			"sb":
				_game_manager_opponent.cur_shape.space_bar()
			"p":
				_game_manager_opponent.spawn_shape(int(args[1]))
			"sba":
				var temp = args[1].split(",")
				var shape_bag_array = []
				for i in temp:
					shape_bag_array.append(int(i))
				_game_manager_opponent.shape_bag = shape_bag_array
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


