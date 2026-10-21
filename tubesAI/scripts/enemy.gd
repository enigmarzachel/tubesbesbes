extends CharacterBody2D

signal trigger_battle_start(enemy_node, player_node)

@export var tilemap_layer: TileMapLayer
@export var grid_manager: GridManager
@export var player: CharacterBody2D
@export var debug_node: Node
@export var battle_manager: Node

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

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
var has_home_pos: bool = false
var active_tween: Tween
var is_in_battle: bool = false
var is_dying: bool = false
var front_side: int = -1

func _ready() -> void:
	add_to_group("enemies")
	patrol_timer = walk_time
	if not tilemap_layer:
		print_rich("[color=red]ERROR Enemy:[/color] Tilemap Layer belum diisi!")
	else:
		home_grid_pos = _to_grid(_get_ground_pos(self))
		has_home_pos = true
	if not grid_manager:
		print_rich("[color=red]ERROR Enemy:[/color] Grid Manager belum diisi!")
	if not player:
		print_rich("[color=red]ERROR Enemy:[/color] Player Node belum diisi!")

func _draw() -> void:
	if not tilemap_layer: return

	var tile_size: Vector2 = tilemap_layer.tile_set.tile_size
	var fill_color := Color(1.0, 0.1, 0.1, 0.12)
	var border_color := Color(1.0, 0.2, 0.2, 0.25)

	for x in range(-detection_radius_tiles, detection_radius_tiles + 1):
		for y in range(-detection_radius_tiles, detection_radius_tiles + 1):
			if abs(x) + abs(y) <= detection_radius_tiles:
				var rect := Rect2(Vector2(x, y) * tile_size - (tile_size / 2.0) + Vector2(1, 1), tile_size - Vector2(2, 2))
				draw_rect(rect, fill_color, true)
				draw_rect(rect, border_color, false, 0.5)

func _physics_process(delta: float) -> void:
	if is_in_battle or is_dying or not player or not tilemap_layer or not grid_manager:
		return

	var my_grid: Vector2i = _to_grid(_get_ground_pos(self))
	var player_grid: Vector2i = _to_grid(_get_ground_pos(player) + player_ground_offset)
	front_side = _get_front_side(player_grid, my_grid)
	var dist: int = abs(my_grid.x - player_grid.x) + abs(my_grid.y - player_grid.y)

	match current_state:
		State.PATROL:
			if dist <= detection_radius_tiles:
				_switch_state(State.CHASE)
		State.CHASE:
			if dist > out_of_sight_distance_tiles:
				_switch_state(State.RETURNING)
		State.RETURNING:
			if dist <= detection_radius_tiles:
				_switch_state(State.CHASE)

	if current_state == State.PATROL:
		_process_patrol(delta)
	else:
		if is_moving: return
		move_timer += delta
		if move_timer >= step_cooldown:
			move_timer = 0.0
			if current_state == State.CHASE:
				_process_pathfinding_to(my_grid, player_grid, dist, true)
			elif current_state == State.RETURNING:
				if my_grid == home_grid_pos:
					_switch_state(State.PATROL)
					_set_idle_animation()
					_update_debug_visuals({})
				else:
					_process_pathfinding_to(my_grid, home_grid_pos, 0, false)

# --- Utilitas ---

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
		var sprite := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			return 1 if sprite.flip_h else -1
		return front_side
	if my_grid.x < player_grid.x: return -1
	elif my_grid.x > player_grid.x: return 1
	return front_side

func _switch_state(new_state: State) -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()
	is_moving = false
	move_timer = 0.0
	current_state = new_state
	queue_redraw()

# --- Patroli ---

func _process_patrol(delta: float) -> void:
	_update_debug_visuals({})
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		patrol_step *= -1.0
		patrol_timer = walk_time

	var move_vec := Vector2.ZERO
	match initial_patrol_direction:
		PatrolDirection.LEFT_RIGHT:  move_vec.x = -1.0 if patrol_step > 0 else 1.0
		PatrolDirection.RIGHT_LEFT:  move_vec.x = 1.0 if patrol_step > 0 else -1.0
		PatrolDirection.UP_DOWN:     move_vec.y = -1.0 if patrol_step > 0 else 1.0
		PatrolDirection.DOWN_UP:     move_vec.y = 1.0 if patrol_step > 0 else -1.0

	_play_walk_animation(move_vec.x < 0 if move_vec.x != 0 else false)
	velocity = move_vec * patrol_speed
	move_and_slide()

# --- Pathfinding & Movement ---

func _process_pathfinding_to(my_grid: Vector2i, dest: Vector2i, distance: int, is_chasing: bool) -> void:
	if is_chasing and distance <= stop_distance_tiles:
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
		grid_manager, my_grid, dest,
		Pathfinding.current_algorithm, Pathfinding.current_heuristic
	)

	if debug_node and debug_node.has_method("update_enemy_debug"):
		debug_node.update_enemy_debug(self, result)

	if result.get("found", false) and result["path"].size() > 1:
		_move_smoothly_to(tilemap_layer.map_to_local(result["path"][1]))
	else:
		_set_idle_animation()

func _move_smoothly_to(target_pos: Vector2) -> void:
	is_moving = true
	_play_walk_animation(target_pos.x < global_position.x)

	if active_tween and active_tween.is_running():
		active_tween.kill()

	active_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(self, "global_position", target_pos, step_cooldown)
	active_tween.finished.connect(func(): is_moving = false)

# --- Animasi ---

func _play_walk_animation(should_flip: bool) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames: return
	var anim = "jalan" if animated_sprite.sprite_frames.has_animation("jalan") else "walk"
	if animated_sprite.sprite_frames.has_animation(anim):
		if animated_sprite.animation != anim or not animated_sprite.is_playing():
			animated_sprite.play(anim)
	animated_sprite.flip_h = should_flip

func _set_idle_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle" or not animated_sprite.is_playing():
				animated_sprite.play("idle")
		else:
			animated_sprite.stop()

func _update_debug_visuals(result_data: Dictionary) -> void:
	if debug_node and debug_node.has_method("update_debug_data"):
		debug_node.update_debug_data(result_data)
	else:
		var fallback = get_node_or_null("../../PathfindingDebug")
		if fallback and fallback.has_method("update_debug_data"):
			fallback.update_debug_data(result_data)

# --- Battle Events ---

func die() -> void:
	is_dying = true
	is_in_battle = false
	remove_from_group("enemies")
	set_physics_process(false)
	if active_tween and active_tween.is_running():
		active_tween.kill()
	_update_debug_visuals({})
	visible = true

	if animated_sprite and animated_sprite.sprite_frames:
		var anim := ""
		if animated_sprite.sprite_frames.has_animation("mati"): anim = "mati"
		elif animated_sprite.sprite_frames.has_animation("death"): anim = "death"

		if anim != "":
			animated_sprite.play(anim)
			await animated_sprite.animation_finished
		else:
			var fade = create_tween()
			fade.tween_property(self, "modulate:a", 0.0, 0.6)
			await fade.finished
	queue_free()

func reset_after_battle() -> void:
	is_in_battle = false
	is_moving = false
	patrol_timer = walk_time
	patrol_step = 1.0
	if active_tween and active_tween.is_running():
		active_tween.kill()
	if tilemap_layer and has_home_pos:
		global_position = tilemap_layer.map_to_local(home_grid_pos)
	set_physics_process(true)
	_switch_state(State.PATROL)
	_set_idle_animation()

func _exit_tree() -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()
	if debug_node and debug_node.has_method("remove_enemy_debug"):
		debug_node.remove_enemy_debug(self)
