# enemy.gd
extends CharacterBody2D


@export var tilemap_layer: TileMapLayer
@export var grid_manager: GridManager
@export var player_node: Node2D

@export_group("Pengejaran & Kecepatan")
@export var step_cooldown: float = 0.36 # Durasi langkah (detik)
@export var stop_distance_tiles: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var debug_node: Node2D = $"../../PathfindingDebug"

var move_timer: float = 0.0
var is_moving: bool = false # Menandai apakah musuh sedang dalam proses meluncur

func _physics_process(delta: float) -> void:
	if not player_node or not tilemap_layer or not grid_manager:
		return

	# Jika musuh sedang meluncur antar-petak, jangan hitung cooldown baru
	if is_moving:
		return

	move_timer += delta

	if move_timer >= step_cooldown:
		move_timer = 0.0
		_process_chase_logic()

func _process_chase_logic() -> void:
	
	var my_grid: Vector2i = tilemap_layer.local_to_map(global_position)
	var player_grid: Vector2i = tilemap_layer.local_to_map(player_node.global_position)

	var grid_distance: int = abs(my_grid.x - player_grid.x) + abs(my_grid.y - player_grid.y)

	# Jika sudah dekat, matikan animasi jalan (diam/idle)
	if grid_distance <= stop_distance_tiles:
		if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		return

	# Hitung rute pathfinding
	# Di dalam enemy.gd saat memanggil search_path:
	var result: Dictionary = Pathfinding.search_path(
		grid_manager,
		my_grid,
		player_grid,
		Pathfinding.current_algorithm,
		Pathfinding.current_heuristic
	)
	
	if debug_node and debug_node.has_method("update_debug_data"):
		debug_node.update_debug_data(result)

	if result["found"] and result["path"].size() > 1:
		var next_grid_pos: Vector2i = result["path"][1]
		var target_pixel_pos: Vector2 = tilemap_layer.map_to_local(next_grid_pos)
		
		# Jalankan fungsi meluncur secara halus
		_move_smoothly_to(target_pixel_pos)

func _move_smoothly_to(target_pos: Vector2) -> void:
	is_moving = true
	
	# 1. Mainkan animasi jalan & balikkan gambar (flip) sesuai arah
	if animated_sprite:
		animated_sprite.play("jalan") # Sesuaikan dengan nama animasi kamu
		if target_pos.x != global_position.x:
			animated_sprite.flip_h = (target_pos.x < global_position.x)

	# 2. Buat Tween untuk pergerakan slide
	var tween = create_tween()
	
	# Geser properti "global_position" menuju target_pos selama step_cooldown detik
	tween.tween_property(self, "global_position", target_pos, step_cooldown)
	
	# 3. Callback saat slide selesai
	tween.finished.connect(func():
		is_moving = false
	)
