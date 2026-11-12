extends CharacterBody3D
const G = preload("res://demo/geometry.gd")
const A = preload("res://demo/art.gd")
var wings: Array[Node3D] = []
var legs: Array[Node3D] = []
var off_arm: Node3D
var game: Node3D
var kind := "pilgrim"
var health := 64.0
var max_health := 64.0
var dead := false
var state := "idle"
var timer := 0.0
var home := Vector3.ZERO
var body: Node3D
var arm: Node3D
var aura: MeshInstance3D
var health_bar: Sprite3D
var attack_number := 0
var phase_two := false
var bob := 0.0
var stagger := 0.0
var flash := 0.0
var tell: OmniLight3D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	max_health = 330 if kind == "boss" else (38 if kind == "moth" else 64)
	health = max_health
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.65 if kind == "boss" else 0.36
	shape.height = 3.5 if kind == "boss" else 1.7
	cs.shape = shape
	cs.position.y = shape.height*0.5
	add_child(cs)
	body = Node3D.new()
	add_child(body)
	var asset := "bell_keeper" if kind == "boss" else ("glass_moth" if kind == "moth" else "drowned_pilgrim")
	var model := A.place(asset,body,Vector3.ZERO,Vector3.ONE,PI)
	arm = A.part(model,"WeaponArm")
	off_arm = A.part(model,"OffArm")
	for label in ["WingLeft","WingRight"]:
		var wing := A.part(model,label)
		if wing != null: wings.append(wing)
	for label in ["LegLeft","LegRight"]:
		var leg := A.part(model,label)
		if leg != null: legs.append(leg)
	if kind == "moth":
		cs.position.y = 1.65
		shape.height = 0.75
		G.light(body,Vector3(0,1.7,0),Color("8ce8da"),0.45,3)
	tell = G.light(self,Vector3(0,2,0),Color("ff694b"),0,4)
	aura = G.ring(self,Vector3(0,0.04,0),1.2,0.022,G.material(Color("e69364"),2))
	aura.visible = false

func _physics_process(delta: float) -> void:
	if dead or not game.playing or game.overlay != "": return
	bob += delta
	stagger = maxf(0,stagger-delta)
	flash = maxf(0,flash-delta)
	var p: Vector3 = game.player.global_position
	var offset := p-global_position
	var distance := Vector2(offset.x,offset.z).length()
	var line_of_sight: bool = game.clear_line(global_position+Vector3.UP*1.35,p+Vector3.UP)
	if kind == "boss" and (p.x < 33 or p.z < -14):
		state = "idle"
		velocity = Vector3.ZERO
		aura.visible = false
		tell.light_energy = 0
		return
	if distance > 15 or global_position.distance_to(home)>12:
		state = "idle"
		velocity = Vector3.ZERO
	if offset.length() > 0.01:
		var target_angle := atan2(-offset.x,-offset.z)
		rotation.y = lerp_angle(rotation.y,target_angle,delta*4)
	if stagger > 0:
		velocity.x = 0
		velocity.z = 0
		return
	if kind == "moth":
		body.position.y = sin(bob*2.5)*0.17
		body.rotation.z = sin(bob*4)*0.08
		for i in range(wings.size()): wings[i].rotation.y = sin(bob*12.0)*0.55*(1 if i == 0 else -1)
	else:
		body.rotation.z = sin(bob*3)*0.025 if state == "pursue" else 0.0
		for i in range(legs.size()): legs[i].rotation.x = sin(bob*4.5+i*PI)*0.20 if state == "pursue" else 0.0
		if off_arm: off_arm.rotation.x = sin(bob*4.5)*0.12 if state == "pursue" else 0.0
	if kind != "moth": velocity.y -= delta*18
	else: velocity.y = (home.y-global_position.y)*3
	var reach := 3.3 if kind == "boss" else (9.0 if kind == "moth" else 2.15)
	match state:
		"idle":
			velocity.x = 0
			velocity.z = 0
			if distance < 12 and line_of_sight: state = "pursue"
		"pursue":
			if distance < reach and line_of_sight:
				state = "windup"
				timer = 1.15 if kind == "boss" else (1.0 if kind == "moth" else 0.82)
				if phase_two: timer *= 0.78
				aura.visible = true
				tell.light_energy = 1.5
				game.sound.play_tone("warn",-13 if kind != "boss" else -5)
			else:
				var direction := Vector3(offset.x,0,offset.z).normalized()
				var test := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,global_position+Vector3.UP+direction*1.3,1)
				if not get_world_3d().direct_space_state.intersect_ray(test).is_empty():
					direction = direction.rotated(Vector3.UP,PI*0.4)
				var speed := 1.5 if kind != "boss" else 1.9
				velocity.x = direction.x*speed
				velocity.z = direction.z*speed
		"windup":
			velocity.x = 0
			velocity.z = 0
			timer -= delta
			aura.scale = Vector3.ONE*(1+sin(bob*15)*0.04)
			if arm: arm.rotation.x = lerpf(arm.rotation.x,-2.0,delta*8)
			if timer <= 0:
				attack_number += 1
				if kind == "moth":
					game.spawn_projectile(global_position+Vector3.UP*1.7,(p+Vector3.UP*1.2-global_position-Vector3.UP*1.7).normalized(),true,15)
				elif kind == "boss" and attack_number%3 == 0:
					for i in [-1,0,1]:
						var dir := (p+Vector3.UP-global_position-Vector3.UP*1.8).normalized().rotated(Vector3.UP,i*0.18)
						game.spawn_projectile(global_position+Vector3.UP*1.8+dir*1.2,dir,true,23)
				elif distance < reach+0.25 and line_of_sight:
					game.player.take_damage(28 if kind == "boss" else 17,global_position)
				state = "recover"
				timer = 1.3 if kind == "boss" else 1.05
				aura.visible = false
				tell.light_energy = 0
		"recover":
			timer -= delta
			if arm: arm.rotation.x = lerpf(arm.rotation.x,0.5,delta*14)
			if timer <= 0: state = "pursue"
	move_and_slide()
	if global_position.y < -4: global_position = home

func take_damage(amount: float, heavy: bool = false) -> void:
	if dead: return
	health = maxf(0,health-amount)
	game.world.burst(global_position+Vector3.UP*(2.0 if kind == "boss" else 1.1),Color("c9f1d1"))
	if heavy and kind != "boss":
		stagger = 0.45
		state = "recover"
		timer = 0.7
		aura.visible = false
		tell.light_energy = 0
	if kind == "boss" and health <= max_health*0.5 and not phase_two:
		phase_two = true
		game.notify("The Keeper's bell quickens. Watch the shorter windup.")
	if health <= 0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		aura.visible = false
		tell.light_energy = 0
		game.enemy_defeated(self)
		var tween := create_tween()
		tween.tween_property(body,"scale",Vector3.ONE*0.02,0.65)
		tween.tween_callback(hide)
