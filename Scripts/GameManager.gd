extends Node2D

var blocksPath = [
	"res://Shapes/IShape.tscn",
	"res://Shapes/JShape.tscn",
	"res://Shapes/LShape.tscn",
	"res://Shapes/OShape.tscn",
	"res://Shapes/SShape.tscn",
	"res://Shapes/TShape.tscn",
	"res://Shapes/ZShape.tscn"
]

var points

var grid_offset:Vector2 = Vector2(19,4)
var rng = RandomNumberGenerator.new()
var shape_bag = []
var shape_bag_index = 0
var hold_shape = -1
var can_hold_shape = true
var cur_shape
var grid_blocks
var grid_x = 10
var grid_y = 20
var level = 0
var lines_cleared = 0
var gameover = false

# Called when the node enters the scene tree for the first time.
func _ready():
	points = 0
	level = 1
	refresh_level_label()
	print("speed ", set_new_gravity())
	gen_grid_array()
	rng.randomize()
	gen_shape_bag()
	spawn_shape(false)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene("res://Scenes/Menu.tscn")
	pass

func gen_grid_array():
	var matrix = []
	for _x in range(grid_x):
		matrix.append([])
		for _y in range(grid_y):
			matrix[_x].append(null)
	grid_blocks = matrix

func tick():
	pass

func gen_shape_bag():
	shape_bag = []
	while shape_bag.size() != blocksPath.size():
		var random = rng.randi_range(0,blocksPath.size()-1)
		if !shape_bag.has(random): 
			shape_bag.append(random)

func spawn_shape(shape_type):
	can_hold_shape = true;
	var blockpath
	if !shape_type && typeof(shape_type) == TYPE_BOOL: # If no shape_type is specified, we use one from our generated bag
		blockpath = blocksPath[shape_bag[shape_bag_index]]
		shape_bag_index += 1
		if shape_bag_index == shape_bag.size():
			shape_bag_index = 0
			gen_shape_bag()
	else:
		blockpath = blocksPath[shape_type]

	var shape = load(blockpath).instance()
	cur_shape = shape
	var starting_pos
	if shape.name == "OShape":
		starting_pos = Vector2(4,0)
	else:
		starting_pos = Vector2(3,0)
	shape.connect("shape_stopped", self, "_on_shape_stopped")
	shape.connect("hold_shape", self, "_on_hold_shape")
	shape.set_pos(starting_pos + grid_offset)
	shape.set_grid_limits(grid_offset)
	shape.set_player_type(shape.player_types.OneP)
	self.add_child(shape)
	shape.gen_ghost()
	refresh_next_shape()
	if cur_shape.current_pos_is_colliding():
		game_over()

func _on_shape_stopped():
	for block in cur_shape.get_children():
		grid_blocks[block.position.x / cur_shape.cellsize - grid_offset.x][block.position.y / cur_shape.cellsize - grid_offset.y] = block
		cur_shape.remove_child(block)
		self.get_node("Blocks").add_child(block)
		block.get_node("ParticlesPlaced").emitting = true
	remove_shape()
	if !gameover:
		spawn_shape(false)
	
func remove_shape():
	self.remove_child(cur_shape)
	remove_ghosts()
	verify_full_rows()
	verify_level_up()
	
func grid_cell_is_taken(x, y):
	x = x / cur_shape.cellsize - grid_offset.x
	y = y / cur_shape.cellsize - grid_offset.y
	if x < grid_x && y < grid_y:
		return grid_blocks[x][y] != null
	else: return false

func verify_full_rows():
	var rows_to_remove = []
	for y in range(grid_y-1,0,-1):
		if verify_full_row(y):
			lines_cleared += 1
			print("Lines cleared ", lines_cleared)
			rows_to_remove.append(y)
	remove_rows(rows_to_remove)
	
	if rows_to_remove.size() != 0:
		get_points_lines(get_consecutive_lines(rows_to_remove))

func get_consecutive_lines(rows):
	var ref = rows[0]
	var consecutive = -1
	for row in rows:
		if row == ref-1:
			consecutive += 1
		ref = row
	return consecutive + 2

func get_points_lines(lines):
	var new_points = 0
	if lines == 1: new_points = 40
	elif lines == 2: new_points = 100
	elif lines == 3: new_points = 300
	elif lines == 4: new_points = 1200
	add_points(new_points*(level + 1))

func remove_rows(rows_to_remove):
	var coeff = 0
	for row_to_remove in rows_to_remove:
		for x in range(grid_x):
			var temp = grid_blocks[x][row_to_remove+coeff]
			grid_blocks[x][row_to_remove+coeff] = null
			get_node("Blocks").remove_child(temp)
		drop_rows(row_to_remove+coeff)
		coeff += 1

func drop_rows(removed_row):
	var new_grid = grid_blocks.duplicate(true)
	for row_y in range(removed_row-1,0,-1):
		for x in range(grid_x):
			var temp = grid_blocks[x][row_y]
			if temp != null:
				new_grid[x][row_y] = null 
				new_grid[x][row_y+1] = temp
				temp.transform.origin += Vector2(0, cur_shape.cellsize)
	grid_blocks = new_grid

func verify_full_row(y):
	for x in range(grid_x):
		if grid_blocks[x][y] == null:
			return false
	return true

func remove_ghosts():
	for ghost in get_node("Ghosts").get_children():
		ghost.get_parent().remove_child(ghost)

func game_over():
	gameover = true
	self.get_node("Points").text = "YOU LOST"

func refresh_next_shape():
	self.get_node("NextShape").remove_child(self.get_node("NextShape").get_child(0))
	var next_shape = load(blocksPath[shape_bag[shape_bag_index]]).instance()
	next_shape.set_script(null)
	set_display_offset(next_shape, shape_bag[shape_bag_index])
	self.get_node("NextShape").add_child(next_shape)

func set_display_offset(shape, shape_index):
	var offset_vector
	match shape_index:
		0: offset_vector = Vector2(-20, 0) #IShape
		1 , 2, 6: offset_vector = Vector2(0, 25) #JShape, LShape, ZShape
		3: offset_vector = Vector2(15, 25) #OShape
		5: offset_vector = Vector2(-5, 25) #TShape
		_: offset_vector = null
	
	if (offset_vector != null):
		shape.transform.origin += offset_vector

func add_points(points_to_add):
	points += points_to_add
	self.get_node("Points").text = str(points)

func refresh_hold_shape():
	self.get_node("Hold").remove_child(self.get_node("Hold").get_child(0))
	var shape = load(blocksPath[hold_shape]).instance()
	shape.set_script(null)
	set_display_offset(shape, hold_shape)
	self.get_node("Hold").add_child(shape)

func _on_hold_shape():
	if can_hold_shape:
		if hold_shape != -1:
			var cur_shape_type_id = cur_shape.type
			remove_shape()
			spawn_shape(hold_shape)
			hold_shape = cur_shape_type_id
		else:
			hold_shape = cur_shape.type
			remove_shape()
			spawn_shape(false)
		
		can_hold_shape = false
		refresh_hold_shape()

func verify_level_up():
	if lines_cleared >= 10:
		level += 1
		lines_cleared = lines_cleared - 10
		refresh_level_label()
		set_new_gravity()

func refresh_level_label():
	self.get_node("Level").text = str(level)

func set_new_gravity():
	var speed = pow(0.8 - ((level -1) * 0.007), level-1)
	self.get_node("TickSpeed").wait_time = speed

func get_timer_time():
	return self.get_node("TickSpeed").wait_time;

func _on_TickSpeed_timeout():
	cur_shape.tick_down()
