extends CharacterBody2D

signal trigger_battle_start(enemy_node, player_node)

@export var tilemap_layer: TileMapLayer
@export var grid_manager: GridManager
@export var player: CharacterBody2D
@export var debug_node: Node
@export var battle_manager: Node

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- OPSI PATROLI ---
enum PatrolDirection { LEFT_RIGHT, RIGHT_LEFT, UP_DOWN, DOWN_UP }

@export_group("Patroli")
@export var initial_patrol_direction: PatrolDirection = PatrolDirection.LEFT_RIGHT
@export var walk_time: float = 1.5
@export var patrol_speed: float = 30.0

var patrol_timer: float = 0.0
var patrol_step: float = 1.0

@export_group("Pengejaran & Kecepatan")
@export var step_cooldown: float = 0.36
@export var stop_distance_tiles: int = 1
@export var detection_radius_tiles: int = 6
@export var out_of_sight_distance_tiles: int = 8

@export_group("Posisi Serang")
@export var approach_from_player_facing: bool = false
@export var player_ground_offset: Vector2 = Vector2.ZERO

enum State { PATROL, CHASE, RETURNING }
var current_state: State = State.PATROL

var move_timer: float = 0.0
var is_moving: bool = false
var home_grid_pos: Vector2i
var active_tween: Tween

var is_in_battle: bool = false
var is_dying: bool = false
var front_side: int = -1

func _ready() -> void:
	patrol_timer = walk_time
	
	if not tilemap_layer:
		print_rich("[color=red]ERROR Enemy:[/color] Tilemap Layer belum diisi di Inspector!")
	else:
		home_grid_pos = _to_grid(_get_ground_pos(self))

	if not grid_manager:
		print_rich("[color=red]ERROR Enemy:[/color] Grid Manager belum diisi di Inspector!")
	if not player:
		print_rich("[color=red]ERROR Enemy:[/color] Player Node belum dimasukkan di Inspector!")

# --- VISUALISASI SIGHT PER TILE ---
func _draw() -> void:
	if not tilemap_layer:
		return

	var tile_size: Vector2 = tilemap_layer.tile_set.tile_size
	
	# Warna merah halus transparan (Alpha 12%)
	var fill_color := Color(1.0, 0.1, 0.1, 0.12)
	# Garis tepi dibuat sangat tipis dan lembut (Alpha 25%)
	var border_color := Color(1.0, 0.2, 0.2, 0.25)

	# Loop menggambar 1 kotak di setiap tile dalam jangkauan
	for x in range(-detection_radius_tiles, detection_radius_tiles + 1):
		for y in range(-detection_radius_tiles, detection_radius_tiles + 1):
			if abs(x) + abs(y) <= detection_radius_tiles:
				var tile_local_pos := Vector2(x, y) * tile_size
				# Beri inset kecil (1px) agar antar kotak ada sela tipis dan tidak menumpuk tebal
				var rect := Rect2(tile_local_pos - (tile_size / 2.0) + Vector2(1, 1), tile_size - Vector2(2, 2))
				
				# Gambar isi kotak
				draw_rect(rect, fill_color, true)
				# Garis tepi yang sangat tipis
				draw_rect(rect, border_color, false, 0.5)

func _physics_process(delta: float) -> void:
	if is_in_battle or is_dying:
		return

	if not player or not tilemap_layer or not grid_manager:
		return

	var my_grid: Vector2i = _to_grid(_get_ground_pos(self))
	var player_base_grid: Vector2i = _to_grid(_get_ground_pos(player) + player_ground_offset)

	front_side = _get_front_side(player_base_grid, my_grid)
	
	var distance_to_player_direct: int = abs(my_grid.x - player_base_grid.x) + abs(my_grid.y - player_base_grid.y)

	match current_state:
		State.PATROL:
			if distance_to_player_direct <= detection_radius_tiles:
				_switch_state(State.CHASE)
				
		State.CHASE:
			if distance_to_player_direct > out_of_sight_distance_tiles:
				_switch_state(State.RETURNING)
				
		State.RETURNING:
			if distance_to_player_direct <= detection_radius_tiles:
				_switch_state(State.CHASE)

	if current_state == State.PATROL:
		_process_patrol_logic(delta)
	else:
		if is_moving:
			return

		move_timer += delta
		if move_timer >= step_cooldown:
			move_timer = 0.0
			
			if current_state == State.CHASE:
				_process_pathfinding_to(my_grid, player_base_grid, distance_to_player_direct, true)
			elif current_state == State.RETURNING:
				if my_grid == home_grid_pos:
					_switch_state(State.PATROL)
					_set_idle_animation()
					_update_debug_visuals({})
				else:
					_process_pathfinding_to(my_grid, home_grid_pos, 0, false)

func _get_ground_pos(node: Node2D) -> Vector2:
	for child in node.get_children():
		if child is CollisionShape2D:
			return child.global_position
	return node.global_position

func _to_grid(world_pos: Vector2) -> Vector2i:
	return tilemap_layer.local_to_map(tilemap_layer.to_local(world_pos))

func _get_front_side(player_grid: Vector2i, my_grid: Vector2i) -> int:
	if approach_from_player_facing:
		if "velocity" in player and absf(player.velocity.x) > 0.1:
			return int(signf(player.velocity.x))
		var player_sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if player_sprite:
			return 1 if player_sprite.flip_h else -1
		return front_side

	if my_grid.x < player_grid.x:
		return -1
	elif my_grid.x > player_grid.x:
		return 1
	return front_side

func _switch_state(new_state: State) -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()
	is_moving = false
	current_state = new_state
	queue_redraw()

func _process_patrol_logic(delta: float) -> void:
	_update_debug_visuals({})

	patrol_timer -= delta
	if patrol_timer <= 0.0:
		patrol_step *= -1.0
		patrol_timer = walk_time

	var move_vec: Vector2 = Vector2.ZERO

	match initial_patrol_direction:
		PatrolDirection.LEFT_RIGHT:
			move_vec.x = -1.0 if patrol_step > 0 else 1.0
		PatrolDirection.RIGHT_LEFT:
			move_vec.x = 1.0 if patrol_step > 0 else -1.0
		PatrolDirection.UP_DOWN:
			move_vec.y = -1.0 if patrol_step > 0 else 1.0
		PatrolDirection.DOWN_UP:
			move_vec.y = 1.0 if patrol_step > 0 else -1.0

	if move_vec.x != 0:
		_play_walk_animation(move_vec.x < 0)
	else:
		_play_walk_animation(false)

	velocity = move_vec * patrol_speed
	move_and_slide()

func _process_pathfinding_to(my_grid: Vector2i, destination_grid: Vector2i, distance: int, is_chasing_player: bool) -> void:
	if is_chasing_player and distance <= stop_distance_tiles:
		if active_tween and active_tween.is_running():
			active_tween.kill()
		is_moving = false

		if animated_sprite and player:
			animated_sprite.flip_h = _get_ground_pos(player).x < _get_ground_pos(self).x
		_set_idle_animation()
		
		_update_debug_visuals({})
		
		if not is_in_battle:
			is_in_battle = true
			
			if battle_manager and battle_manager.has_method("start_battle"):
				battle_manager.start_battle(self, player)
			else:
				emit_signal("trigger_battle_start", self, player)
		return

	var result: Dictionary = Pathfinding.search_path(
		grid_manager,
		my_grid,
		destination_grid,
		Pathfinding.current_algorithm,
		Pathfinding.current_heuristic
	)

	if debug_node and debug_node.has_method("update_enemy_debug"):
		debug_node.update_enemy_debug(self, result)

	if result.get("found", false) and result["path"].size() > 1:
		var next_grid_pos: Vector2i = result["path"][1]
		var target_pixel_pos: Vector2 = tilemap_layer.map_to_local(next_grid_pos)
		_move_smoothly_to(target_pixel_pos)
	else:
		_set_idle_animation()

func _move_smoothly_to(target_pos: Vector2) -> void:
	is_moving = true
	
	var is_flipping = target_pos.x < global_position.x
	_play_walk_animation(is_flipping)

	if active_tween and active_tween.is_running():
		active_tween.kill()

	active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(self, "global_position", target_pos, step_cooldown)
	
	active_tween.finished.connect(func():
		is_moving = false
	)

func _play_walk_animation(should_flip: bool) -> void:
	if animated_sprite:
		var target_anim = "jalan"
		if not animated_sprite.sprite_frames.has_animation("jalan") and animated_sprite.sprite_frames.has_animation("walk"):
			target_anim = "walk"

		if animated_sprite.animation != target_anim or not animated_sprite.is_playing():
			animated_sprite.play(target_anim)

		animated_sprite.flip_h = should_flip

func _set_idle_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.animation != "idle" or not animated_sprite.is_playing():
			animated_sprite.play("idle")
		else:
			animated_sprite.stop()

func _update_debug_visuals(result_data: Dictionary) -> void:
	if debug_node and debug_node.has_method("update_debug_data"):
		debug_node.update_debug_data(result_data)
	else:
		var fallback_debug = get_node_or_null("../../PathfindingDebug")
		if fallback_debug and fallback_debug.has_method("update_debug_data"):
			fallback_debug.update_debug_data(result_data)

func die() -> void:
	is_dying = true
	is_in_battle = false
	set_physics_process(false)
	
	if active_tween and active_tween.is_running():
		active_tween.kill()
		
	_update_debug_visuals({})
	visible = true
	
	if animated_sprite and animated_sprite.sprite_frames:
		var anim_name: String = ""
		
		if animated_sprite.sprite_frames.has_animation("mati"):
			anim_name = "mati"
		elif animated_sprite.sprite_frames.has_animation("death"):
			anim_name = "death"
			
		if anim_name != "":
			animated_sprite.play(anim_name)
			await animated_sprite.animation_finished
		else:
			var fade_tween: Tween = create_tween()
			fade_tween.tween_property(self, "modulate:a", 0.0, 0.6)
			await fade_tween.finished

	queue_free()

func reset_after_battle() -> void:
	is_in_battle = false
	is_moving = false
	patrol_timer = walk_time
	patrol_step = 1.0
	
	if active_tween and active_tween.is_running():
		active_tween.kill()
		
	if tilemap_layer and home_grid_pos != Vector2i.ZERO:
		global_position = tilemap_layer.map_to_local(home_grid_pos)
		
	set_physics_process(true)
	_switch_state(State.PATROL)
	_set_idle_animation()

func _exit_tree() -> void:
	if debug_node and debug_node.has_method("remove_enemy_debug"):
		debug_node.remove_enemy_debug(self)
