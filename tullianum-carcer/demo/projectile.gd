extends Node3D
const G = preload("res://demo/geometry.gd")
var game: Node3D
var direction := Vector3.FORWARD
var hostile := false
var damage := 24.0
var life := 0.0
var speed := 14.0

func _ready() -> void:
	var color := Color("ffae78") if hostile else Color("acfff0")
	G.sphere(self,Vector3.ZERO,0.13 if hostile else 0.065,G.material(color,5))
	G.light(self,Vector3.ZERO,color,1.8,3.0)
	speed = 7 if hostile else 18

func _physics_process(delta: float) -> void:
	if not game.playing or game.overlay != "": return
	life += delta
	if life > 6:
		queue_free()
		return
	var next := global_position+direction*speed*delta
	var mask := 1 | (2 if hostile else 4)
	var query := PhysicsRayQueryParameters3D.create(global_position,next,mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("take_damage"):
			if hostile:
				hit.collider.take_damage(damage,global_position)
			else:
				hit.collider.take_damage(damage,false)
				game.hit_flash = 0.15
				game.sound.play_tone("hit",-4)
		game.world.burst(hit.position,Color("99e2d7"))
		queue_free()
		return
	global_position = next

func _exit_tree() -> void:
	if is_instance_valid(game): game.projectiles.erase(self)
