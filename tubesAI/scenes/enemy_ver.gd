extends CharacterBody2D

const SPEED = 30.0
const WALK_TIME = 1.5 

# Boleh dipilih langsung dari Inspector:
# true  = Mula jalan dari Bawah ke Atas (Arah -1)
# false = Mula jalan dari Atas ke Bawah (Arah 1)
@export var start_move_up: bool = false 

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: float = 1.0
var walk_timer: float = 0.0

func _ready() -> void:
	walk_timer = WALK_TIME
	
	# Tetapkan arah awal berdasarkan pilihan dari Inspector
	if start_move_up:
		direction = -1.0 # Ke Atas
	else:
		direction = 1.0  # Ke Bawah

	if animated_sprite:
		animated_sprite.play("jalan")

func _physics_process(delta: float) -> void:
	walk_timer -= delta
	
	if walk_timer <= 0:
		direction *= -1.0 # Tukar arah apabila pemasa tamat
		walk_timer = WALK_TIME

	velocity.x = 0
	velocity.y = direction * SPEED

	move_and_slide()
