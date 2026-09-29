extends CharacterBody2D

const SPEED = 70.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@onready var initial_spawn_position: Vector2 = global_position
var is_in_battle: bool = false

# --- HP PLAYER ---
signal hp_changed(current_hp: int, max_hp: int)
const MAX_HP: int = 100
var hp: int = MAX_HP

func _physics_process(_delta: float) -> void:
	if is_in_battle:
		return

	var direction := Input.get_vector("moveLeft", "moveRight", "moveUp", "moveDown")
	
	if direction:
		velocity = direction * SPEED
		animated_sprite_2d.play("walk")
		if direction.x < 0:
			animated_sprite_2d.flip_h = true
		elif direction.x > 0:
			animated_sprite_2d.flip_h = false
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)
		animated_sprite_2d.play("idle")

	move_and_slide()

func set_hp(value: int) -> void:
	hp = clampi(value, 0, MAX_HP)
	hp_changed.emit(hp, MAX_HP)

# Dipanggil oleh duri (atau sumber damage lain di luar battle)
func take_damage(amount: int) -> void:
	if is_in_battle:
		return

	set_hp(hp - amount)

	# Kedip merah singkat sebagai tanda kena damage
	if animated_sprite_2d:
		animated_sprite_2d.modulate = Color(1.0, 0.3, 0.3)
		create_tween().tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.3)

	if hp <= 0:
		respawn()

func set_battle_mode(in_battle: bool) -> void:
	is_in_battle = in_battle
	velocity = Vector2.ZERO
	if animated_sprite_2d:
		animated_sprite_2d.play("idle")
	set_physics_process(not in_battle)
	set_process_unhandled_input(not in_battle)

func face_enemy(enemy_node: Node2D) -> void:
	if enemy_node and animated_sprite_2d:
		animated_sprite_2d.flip_h = enemy_node.global_position.x < global_position.x

# Fungsi khusus memainkan animasi saat battle
func play_action_animation(action_name: String) -> void:
	if not animated_sprite_2d or not animated_sprite_2d.sprite_frames:
		return
		
	var anim_name: String = ""
	match action_name:
		"ATTACK":
			anim_name = "attack"
		"HEAVY_ATTACK":
			anim_name = "heavy"
		"HIT":
			anim_name = "hit"
		"DIE":
			anim_name = "mati"
			
	if anim_name != "" and animated_sprite_2d.sprite_frames.has_animation(anim_name):
		# Pastikan tidak looping, kalau tidak sinyal animation_finished tidak akan pernah keluar
		animated_sprite_2d.sprite_frames.set_animation_loop(anim_name, false)
		animated_sprite_2d.play(anim_name)
		await animated_sprite_2d.animation_finished
		if action_name != "DIE" and is_in_battle:
			animated_sprite_2d.play("idle")

func respawn() -> void:
	set_hp(MAX_HP)
	global_position = initial_spawn_position
	velocity = Vector2.ZERO
	if animated_sprite_2d:
		animated_sprite_2d.play("idle")
	set_battle_mode(false)
