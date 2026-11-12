extends CharacterBody3D

const G = preload("res://demo/geometry.gd")
const A = preload("res://demo/art.gd")
var game: Node3D
var camera: Camera3D
var hand: Node3D
var blade: Node3D
var health := 100.0
var stamina := 100.0
var charge := 100.0
var moth := false
var blocking := false
var invulnerable := 0.0
var attack_cooldown := 0.0
var attack_hold := 0.0
var attacking := false
var swing := 0.0
var spell_cooldown := 0.0
var bob := 0.0
var flutter_cooldown := 0.0
var last_safe := Vector3(46,0.1,-33)
var safe_clock := 0.0
var automation := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.84
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.near = 0.04
	camera.far = 160
	camera.fov = 78
	add_child(camera)
	hand = Node3D.new()
	camera.add_child(hand)
	blade = A.place("pilgrim_longsword",hand,Vector3(0.36,-0.30,-0.76),Vector3.ONE*0.64)
	blade.rotation_degrees = Vector3(-15,0,-12)
	A.place("pilgrim_gauntlet",blade)
	G.light(camera,Vector3(0,0,-0.8),Color("a7bfbc"),0.5,4)

func _unhandled_input(event: InputEvent) -> void:
	if not game.playing or game.overlay != "" or automation:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * game.settings.sensitivity)
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*game.settings.sensitivity,-1.35,1.35)
	if event.is_action_pressed("attack") and not moth and attack_cooldown <= 0:
		attacking = true
		attack_hold = 0
	if event.is_action_released("attack") and attacking:
		melee(attack_hold >= 0.48)
		attacking = false
	if event.is_action_pressed("spell"):
		cast_spell()
	if event.is_action_pressed("transform"):
		transform()
	if event.is_action_pressed("interact"):
		game.interact()
	if event.is_action_pressed("heal"):
		game.heal()

func _physics_process(delta: float) -> void:
	if not game.playing or game.overlay != "" or automation:
		return
	invulnerable = maxf(0,invulnerable-delta)
	attack_cooldown = maxf(0,attack_cooldown-delta)
	spell_cooldown = maxf(0,spell_cooldown-delta)
	flutter_cooldown = maxf(0,flutter_cooldown-delta)
	if attacking:
		attack_hold += delta
	blocking = Input.is_action_pressed("block") and not moth and not attacking and stamina > 2
	var input := Input.get_vector("left","right","forward","back")
	var direction := (basis * Vector3(input.x,0,input.y)).normalized()
	var sprint := Input.is_action_pressed("sprint") and stamina > 1 and input.length() > 0 and not moth and not blocking
	var crouch := Input.is_action_pressed("crouch") and not moth
	var speed := 4.2
	if sprint:
		speed = 6.4
		stamina -= delta*14
	elif crouch:
		speed = 2.2
	elif blocking:
		speed = 2.4
	elif moth:
		speed = 7.4
	if not sprint and not blocking and attack_cooldown < 0.12:
		stamina = minf(100,stamina+delta*24)
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*24)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*24)
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = 5.6 if not moth else 5.2
		else:
			velocity.y = -0.4
	else:
		velocity.y -= delta * (5.0 if moth else 18.0)
		if moth:
			velocity.y = maxf(velocity.y,-0.75)
	if moth and Input.is_action_just_pressed("block") and flutter_cooldown <= 0 and stamina >= 16:
		velocity += (direction if direction.length()>0 else basis.x)*7
		invulnerable = 0.22
		flutter_cooldown = 1.0
		stamina -= 16
		game.sound.play_tone("flutter")
	if moth:
		charge = maxf(0,charge-delta*2.8)
		if charge <= 0:
			moth = false
			game.notify("The wings fade. Rest at a shrine to recover starlight.")
	move_and_slide()
	safe_clock += delta
	if is_on_floor() and safe_clock > 0.4:
		last_safe = global_position
		safe_clock = 0
	if global_position.y < -5:
		global_position = last_safe + Vector3.UP*0.4
		velocity = Vector3.ZERO
		take_damage(18,Vector3.ZERO,true)
		game.notify("The deep returns you. R: Moth Form, then jump and glide.")
	bob += delta * (10 if sprint else 7) * minf(input.length(),1)
	camera.position.y = lerpf(camera.position.y,(1.05 if crouch else 1.6)+sin(bob)*0.024*game.settings.shake,delta*12)
	camera.fov = lerpf(camera.fov,game.settings.fov+(5 if moth else 0),delta*4)
	var swing_strength := sin(swing*PI)
	swing = maxf(0,swing-delta*3.4)
	hand.position = Vector3(-swing_strength*0.28,sin(bob)*0.008+swing_strength*0.1,-swing_strength*0.2)
	hand.rotation.z = -swing_strength*1.1
	blade.rotation.x = lerpf(blade.rotation.x,(-0.7 if attacking else -0.26),delta*9)
	blade.rotation.z = lerpf(blade.rotation.z,(-1.1 if blocking else -0.2),delta*12)
	blade.visible = not moth

func melee(charged: bool = false) -> bool:
	var cost := 28.0 if charged else 15.0
	if moth or attack_cooldown > 0 or stamina < cost:
		return false
	stamina -= cost
	attack_cooldown = 0.72 if charged else 0.4
	swing = 1.0
	game.sound.play_tone("swing")
	var best: Node3D = null
	var best_distance := 3.2 if charged else 2.8
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var target: Vector3 = enemy.global_position + Vector3.UP*1.1
		var offset := target-camera.global_position
		var distance := offset.length()
		if distance < best_distance and (-camera.global_basis.z).dot(offset.normalized()) > 0.62 and game.clear_line(camera.global_position,target):
			best = enemy
			best_distance = distance
	if best != null:
		best.take_damage(38 if charged else 21,charged)
		game.hit_flash = 0.15
		game.sound.play_tone("hit")
	return true

func cast_spell() -> bool:
	if not game.flags.needle:
		game.notify("A spell waits among the pilgrims' tombs.")
		return false
	if spell_cooldown > 0 or charge < 9:
		return false
	charge -= 9
	spell_cooldown = 0.48
	game.spawn_projectile(camera.global_position-camera.global_basis.z*0.55,-camera.global_basis.z,false,24)
	game.sound.play_tone("spell")
	return true

func transform() -> bool:
	if not game.flags.moth:
		game.notify("Seek the winged reliquary in the Moth Chapel.")
		return false
	if not moth and charge < 6:
		game.notify("Not enough starlight. Rest, or drink a moon draught [F].")
		return false
	moth = not moth
	attacking = false
	game.notify("MOTH FORM  •  Jump to glide. RMB to flutter. Follow the hidden silver marks." if moth else "Your human shape returns.")
	game.sound.play_tone("flutter")
	return true

func take_damage(amount: float, source: Vector3 = Vector3.ZERO, unavoidable: bool = false) -> void:
	if health <= 0 or invulnerable > 0:
		return
	if blocking and not unavoidable and source != Vector3.ZERO:
		var offset := (source-global_position).normalized()
		if (-global_basis.z).dot(offset)>0.1 and stamina >= amount*0.65:
			stamina -= amount*0.65
			amount *= 0.12
			game.sound.play_tone("block")
	health = maxf(0,health-amount)
	invulnerable = 0.45
	game.damage_flash = 0.6
	game.sound.play_tone("hurt")
	if health <= 0:
		game.die()
