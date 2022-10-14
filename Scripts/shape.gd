extends Node

class_name ShapeX

var type
var rotation_matrix = []
var prev_rotation
var rotation_index = 0
var start_pos

var _game_manager

const cellsize = 40
const _max_lock_delay_increase = 2
var lock_delay_counter = 0
var lock_delay_active = false

var timer:float = 0
var hold_delay:float = 0.6
var hold_timer:float = 0
var slide_delay:float = 0.08
var downtimer:float = 0
enum direction {None, Right, Left}
var cur_direction
var last_direction
var grid_limits:Vector2
var down_timer_paused
var ghost_blocks = []
var ghost_path = "res://Shapes/Ghost.tscn"

# Functions that need delayed executions
var delayed_functions = {} # function_name : TimeLeft. GDscript

# Multiplayer variables
var player_type;
enum player_types {OneP, TwoP, Lan}
var isOnline = false;

signal shape_stopped
signal hold_shape

func _ready():
	_game_manager = get_parent()
	pass

func game_loaded():
	pass

func _physics_process(delta):
	for function_name in delayed_functions:
		var time_left = delayed_functions[function_name] - delta * 1000 # Ms
		if (time_left <= 0):
			call(function_name)
			delayed_functions.erase(function_name)
		else:
			delayed_functions[function_name] = time_left

func _process(delta):
	if (player_type == player_types.OneP):
		if Input.is_action_just_pressed("multiplayer"):
			get_tree().change_scene("res://Scenes/TetrisGameOnline.tscn")

		if (!isOnline || isOnline && !_game_manager.isPaused):
			if Input.is_action_just_pressed("ui_up"):
				rotate()
			
			if Input.is_action_just_pressed("ui_right"):
				right()
				cur_direction = direction.Right
			
			if Input.is_action_just_pressed("ui_left"):
				left()
				cur_direction = direction.Left

			if Input.is_action_just_released("ui_right"):
				if (Input.is_action_pressed("ui_left")):
					cur_direction = direction.Left
				else:
					hold_timer = 0
					timer = 0
					last_direction = cur_direction
					cur_direction = direction.None

			if Input.is_action_just_released("ui_left"):
				if (Input.is_action_pressed("ui_right")):
					cur_direction = direction.Right
				else:
					hold_timer = 0
					timer = 0
					last_direction = cur_direction
					cur_direction = direction.None
			
			if Input.is_action_pressed("ui_down"):
				down_timer_paused = true
				slide_down(delta)
			
			if Input.is_action_just_released("ui_down"):
				down_timer_paused = false
				hold_timer = 0
				timer = 0
				cur_direction = direction.None
			
			if Input.is_action_just_pressed("ui_accept"):
				space_bar()
			
			if Input.is_action_just_pressed("hold_key"):
				emit_signal("hold_shape")

			if hold_delay < hold_timer:
				slide(delta)
			hold_timer += delta

func tick_down():
	if !down_timer_paused && player_type != player_types.Lan:
		down()

func rotate():
	if (isOnline):
		_game_manager.client_handler.send_packet("ro|")

	if rotation_index == rotation_matrix.size():
		rotation_index = 0
	if rotation_index == 0:
		prev_rotation = rotation_matrix.size() - 1
	var rotation_vectors = rotation_matrix[rotation_index]
	
	var next_positions = []
	
	var _i = 0
	for block in self.get_children():
		var delta_vector =  block.transform.origin - rotation_matrix[prev_rotation][_i]
		next_positions.append(Vector2(rotation_vectors[_i] + delta_vector))
		_i += 1
	
	if !is_out_of_grid(get_shape_boundairies(next_positions)) && !is_colliding(next_positions):
		_i = 0
		for block in self.get_children():
			var delta_vector =  block.transform.origin - rotation_matrix[prev_rotation][_i]
			block.transform.origin = rotation_vectors[_i] + delta_vector
			_i += 1
		prev_rotation = rotation_index
		rotation_index += 1
		move_ghost()

		if (lock_delay_active):
			if (lock_delay_counter <= _max_lock_delay_increase):
				edit_delayed_function("stop_shape", 1000) # 1s
				lock_delay_counter += 1

	elif !wall_rotation(next_positions):
		ground_rotation(next_positions)

func slide(delta):
	timer += delta
	if timer > slide_delay:
		if cur_direction == direction.Right : right()
		elif cur_direction == direction.Left : left()
		timer = 0

func right():
	var _i = 0
	var next_positions = []
	for block in self.get_children():
		var newPos = block.transform.origin + Vector2.RIGHT*cellsize
		next_positions.append(newPos)
		_i += 1

	if !is_out_of_grid(get_shape_boundairies(next_positions)) && !is_colliding(next_positions):
		_i = 0
		for block in self.get_children():
			var newPos = block.transform.origin + Vector2.RIGHT*cellsize
			block.transform.origin = newPos
			_i += 1
		move_ghost()
		if (isOnline):
			_game_manager.client_handler.send_packet("r|")

func left():
	var _i = 0
	var next_positions = []
	for block in self.get_children():
		var newPos = block.transform.origin + Vector2.LEFT*cellsize
		next_positions.append(newPos)
		_i += 1

	if !is_out_of_grid(get_shape_boundairies(next_positions)) && !is_colliding(next_positions):
		_i = 0
		for block in self.get_children():
			var newPos = block.transform.origin + Vector2.LEFT*cellsize
			block.transform.origin = newPos
			_i += 1
		move_ghost()
		if (isOnline):
			_game_manager.client_handler.send_packet("l|")

func down(timer_time = -1):
	if (isOnline):
		_game_manager.client_handler.send_packet(str("d|", _game_manager.get_timer_time()))
	var _i = 0
	var next_positions = []
	for block in self.get_children():
		var newPos = block.transform.origin + Vector2.DOWN*cellsize
		next_positions.append(newPos)
		_i += 1

	if !is_out_of_grid(get_shape_boundairies(next_positions)):
		if !is_colliding(next_positions):
			_i = 0
			for block in self.get_children():
				var newPos = block.transform.origin + Vector2.DOWN*cellsize
				block.transform.origin = newPos
				_i += 1
			move_ghost()
			if (lock_delay_active):
				lock_delay_active = false
				stop_delayed_function("stop_shape")
		else:
			lock_delay_active = true
			if timer_time == -1:
				delay_function("stop_shape", 800 - _game_manager.get_timer_time() * 1000) # 800 ms
			else: # LAN player
				delay_function("stop_shape", 800 - timer_time * 1000)
	else:
		emit_signal("shape_stopped")


func stop_shape():
	lock_delay_active = false
	lock_delay_counter = 0
	emit_signal("shape_stopped")

func delay_function(function_name, delayMs):
	if !delayed_functions.has(function_name):
		delayed_functions[function_name] = delayMs

func stop_delayed_function(function_name):
	delayed_functions.erase(function_name)

func edit_delayed_function(function_name, delay_to_add):
	if delayed_functions.has(function_name):
		delayed_functions[function_name] += delay_to_add


func slide_down(delta):
	downtimer += delta
	if downtimer > slide_delay:
		var _i = 0
		var next_positions = []
		for block in self.get_children():
			var newPos = block.transform.origin + Vector2.DOWN*cellsize
			next_positions.append(newPos)
			_i += 1

		if !is_out_of_grid(get_shape_boundairies(next_positions)) && !is_colliding(next_positions):
			_i = 0
			_game_manager.add_points(1)
			for block in self.get_children():
				var newPos = block.transform.origin + Vector2.DOWN*cellsize
				block.transform.origin = newPos
				_i += 1
			downtimer = 0
		if (isOnline):
			_game_manager.client_handler.send_packet("sd|")
		move_ghost()

func set_pos(offset):
	var _i = 0
	for block in self.get_children():
		block.transform.origin += offset * cellsize
		_i += 1

func set_online(status):
	isOnline = status

func set_player_type(type):
	player_type = type

func get_shape_boundairies(vectors_list):
	var maxX = 0
	var minX = 2000
	var maxY = 0
	var minY = 2000
	for vector in vectors_list:
		if vector.x > maxX:
			maxX = vector.x
		if vector.x < minX:
			minX = vector.x
		if vector.y > maxY:
			maxY = vector.y
		if vector.y < minY:
			minY = vector.y
	return [minX, maxX, minY, maxY]

func is_out_of_grid(boundaries):
	if boundaries[0] >= grid_limits.x && boundaries[1] < grid_limits.x + 10 * cellsize && boundaries[2] >= grid_limits.y && boundaries[3] < grid_limits.y + 20 * cellsize:
		return false
	return true

func is_colliding(vectors_list):
	for vector in vectors_list:
		if _game_manager.grid_cell_is_taken(vector.x, vector.y):
			return true
	return false

func current_pos_is_colliding():
	var vectors = []
	for block in get_children():
		vectors.append(block.transform.origin)
	return is_colliding(vectors)

func ground_rotation(next_positions):
	var decalage = -cellsize
	for _e in range(2):	
		var next_possible_positions = []
		for block in next_positions:
			var temp = block + Vector2(0,decalage)
			next_possible_positions.append(temp)
		if !is_out_of_grid(get_shape_boundairies(next_possible_positions)) && !is_colliding(next_positions):
			var _i = 0
			for block in self.get_children():
				block.transform.origin = next_possible_positions[_i]
				_i += 1
			prev_rotation = rotation_index
			rotation_index += 1
			move_ghost()
			return true
		else:
			decalage *= 2
	return false

func wall_rotation(next_positions):
	var decalage
	if last_direction == direction.Left || cur_direction == direction.Left:
		decalage = cellsize
	if last_direction == direction.Right || cur_direction == direction.Right:
		decalage = -cellsize
	if last_direction == direction.Right || cur_direction == direction.Right:
		decalage = -cellsize
	if decalage != null:
		for _e in range(2):	
			var next_possible_positions = []
			for block in next_positions:
				var temp = block + Vector2(decalage,0)
				next_possible_positions.append(temp)
			if !is_out_of_grid(get_shape_boundairies(next_possible_positions)) && !is_colliding(next_positions):
				var _i = 0
				for block in self.get_children():
					block.transform.origin = next_possible_positions[_i]
					_i += 1
				prev_rotation = rotation_index
				rotation_index += 1
				move_ghost()
				return true
			else:
				decalage *= 2
	return false

func gen_ghost():
	for block in get_children():
		var ghost = load(ghost_path).instance()
		_game_manager.get_node("Ghosts").add_child(ghost)
		ghost.transform.origin = block.transform.origin
		ghost_blocks.append(ghost)
	move_ghost()

func move_ghost():
	if get_parent() != null:
		var ghost_blocks_pos = []
		for y in range(20):
			var next_positions = []
			for block in get_children():
				next_positions.append(block.transform.origin + Vector2(0,y*cellsize))
			if is_colliding(next_positions) || is_out_of_grid(get_shape_boundairies(next_positions)):
				next_positions = []
				for block in get_children():
					next_positions.append(block.transform.origin + Vector2(0,(y-1)*cellsize))
				ghost_blocks_pos = next_positions
				break
		var _i = 0
		for ghost in ghost_blocks:
			ghost.transform.origin = ghost_blocks_pos[_i]
			_i += 1

func space_bar():
	var _i = 0
	var lowest_distance_travelled = 20 # 20 is max height of game space
	for block in get_children():
		var distance_travelled = ghost_blocks[_i].transform.origin.y - block.transform.origin.y
		block.transform.origin = ghost_blocks[_i].transform.origin
		var normalized_distance = distance_travelled / cellsize
		if normalized_distance < lowest_distance_travelled: lowest_distance_travelled = normalized_distance
		_i += 1
	_game_manager.add_points(lowest_distance_travelled * 2)
	if (isOnline):
		_game_manager.client_handler.send_packet("sb|")
	emit_signal("shape_stopped")

func set_grid_limits(offset):
	grid_limits = offset * cellsize
