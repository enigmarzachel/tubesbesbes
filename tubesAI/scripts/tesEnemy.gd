# tesEnemy.gd
extends CharacterBody2D

@export var tilemap_layer: TileMapLayer
@export var grid_manager: GridManager
@export var player: CharacterBody2D # Diubah ke @export agar bisa ditarik via Inspector
@export var debug_node: Node

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export_group("Patroli (Kanan-Kiri)")
@export var walk_time: float = 1.5 # Waktu (detik) sebelum balik arah saat patroli
@export var patrol_speed: float = 30.0 # Kecepatan jalan patroli
var patrol_timer: float = 0.0
var patrol_direction: float = 1.0

@export_group("Pengejaran & Kecepatan")
@export var step_cooldown: float = 0.36 # Durasi langkah per petak (detik)
@export var stop_distance_tiles: int = 1 # Jarak berhenti dari player
@export var detection_radius_tiles: int = 6 # Radius terdeteksi
@export var out_of_sight_distance_tiles: int = 8 # Jarak out of sight (berhenti mengejar)

enum State { PATROL, CHASE, RETURNING }
var current_state: State = State.PATROL

var move_timer: float = 0.0
var is_moving: bool = false
var home_grid_pos: Vector2i
var active_tween: Tween

func _ready() -> void:
	patrol_timer = walk_time
	
	# Peringatan di Output jika ada slot yang belum diisi
	if not tilemap_layer:
		print_rich("[color=red]ERROR Enemy:[/color] Tilemap Layer belum diisi di Inspector!")
	else:
		# Pastikan posisi spawn disimpan setelah tilemap siap
		home_grid_pos = tilemap_layer.local_to_map(global_position)

	if not grid_manager:
		print_rich("[color=red]ERROR Enemy:[/color] Grid Manager belum diisi di Inspector!")
	if not player:
		print_rich("[color=red]ERROR Enemy:[/color] Player Node belum dimasukkan di Inspector!")

func _physics_process(delta: float) -> void:
	if not player or not tilemap_layer or not grid_manager:
		return

	var my_grid: Vector2i = tilemap_layer.local_to_map(global_position)
	var player_grid: Vector2i = tilemap_layer.local_to_map(player.global_position)
	var distance_to_player: int = abs(my_grid.x - player_grid.x) + abs(my_grid.y - player_grid.y)

	# --- 1. MANAJEMEN STATUS (STATE MACHINE) ---
	match current_state:
		State.PATROL:
			if distance_to_player <= detection_radius_tiles:
				_switch_state(State.CHASE)
				
		State.CHASE:
			if distance_to_player > out_of_sight_distance_tiles:
				_switch_state(State.RETURNING)
				
		State.RETURNING:
			if distance_to_player <= detection_radius_tiles:
				_switch_state(State.CHASE)

	# --- 2. EKSEKUSI PERILAKU ---
	if current_state == State.PATROL:
		_process_patrol_logic(delta)
	else:
		if is_moving:
			return

		move_timer += delta
		if move_timer >= step_cooldown:
			move_timer = 0.0
			
			if current_state == State.CHASE:
				_process_pathfinding_to(my_grid, player_grid, distance_to_player, true)
			elif current_state == State.RETURNING:
				if my_grid == home_grid_pos:
					_switch_state(State.PATROL)
					_set_idle_animation()
					_update_debug_visuals({})
				else:
					_process_pathfinding_to(my_grid, home_grid_pos, 0, false)

func _switch_state(new_state: State) -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()
	is_moving = false
	current_state = new_state

# --- LOGIKA PATROLI KANAN-KIRI ---
func _process_patrol_logic(delta: float) -> void:
	_update_debug_visuals({})

	patrol_timer -= delta
	if patrol_timer <= 0:
		patrol_direction *= -1.0
		patrol_timer = walk_time

	_play_walk_animation(patrol_direction < 0)

	velocity.x = patrol_direction * patrol_speed
	velocity.y = 0
	move_and_slide()

# --- LOGIKA PATHFINDING & INTEGRASI DEBUG ---
func _process_pathfinding_to(my_grid: Vector2i, destination_grid: Vector2i, distance: int, is_chasing_player: bool) -> void:
	if is_chasing_player and distance <= stop_distance_tiles:
		_set_idle_animation()
		_update_debug_visuals({})
		return

	var result: Dictionary = Pathfinding.search_path(
		grid_manager,
		my_grid,
		destination_grid,
		Pathfinding.current_algorithm,
		Pathfinding.current_heuristic
	)

	# Di dalam enemy.gd saat mengirim data debug:
	if debug_node and debug_node.has_method("update_enemy_debug"):
		# Kirim 'self' agar debug manager tahu INI data milik Enemy mana
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
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("idle"):
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
		else:
			animated_sprite.stop()

# --- INTEGRASI KE PATHFINDING DEBUG ---
func _update_debug_visuals(result_data: Dictionary) -> void:
	if debug_node and debug_node.has_method("update_debug_data"):
		debug_node.update_debug_data(result_data)
	else:
		var fallback_debug = get_node_or_null("../../PathfindingDebug")
		if fallback_debug and fallback_debug.has_method("update_debug_data"):
			fallback_debug.update_debug_data(result_data)
			
func _exit_tree() -> void:
	if debug_node and debug_node.has_method("remove_enemy_debug"):
		debug_node.remove_enemy_debug(self)
