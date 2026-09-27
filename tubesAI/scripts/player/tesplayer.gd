extends CharacterBody2D

const SPEED = 70.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	# Ambil input 4 arah (kiri, kanan, atas, bawah)
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
