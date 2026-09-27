extends CharacterBody2D

const SPEED = 30.0
# Waktu (dalam detik) sebelum balik badan. 
# Sesuaikan nilai ini agar pas dengan "3 langkah" animasi/jaraknya.
const WALK_TIME = 1.5 

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: float = 1.0
var walk_timer: float = 0.0

func _ready() -> void:
	walk_timer = WALK_TIME
	if animated_sprite:
		animated_sprite.play("jalan")

func _physics_process(delta: float) -> void:
	# Hitung mundur timer jalan
	walk_timer -= delta
	
	# Saat timer habis, balik arah dan reset timer
	if walk_timer <= 0:
		direction *= -1.0 # Balik arah (1 jadi -1, atau -1 jadi 1)
		walk_timer = WALK_TIME
		
		# Balik arah gambar/sprite
		if animated_sprite:
			animated_sprite.flip_h = (direction < 0)

	# Gerakkan musuh secara horizontal
	velocity.x = direction * SPEED
	velocity.y = 0

	move_and_slide()
