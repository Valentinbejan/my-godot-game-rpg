extends Node3D

const G = preload("res://demo/geometry.gd")
const Player = preload("res://demo/player.gd")
const World = preload("res://demo/world.gd")
const HUD = preload("res://demo/hud.gd")
const Enemy = preload("res://demo/enemy.gd")
const Sound = preload("res://demo/audio.gd")
const Projectile = preload("res://demo/projectile.gd")
const SAVE_PATH := "user://hollow_star_slice_v1.json"
const SETTINGS_PATH := "user://hollow_star_settings_v1.json"
var player: CharacterBody3D
var world: Node3D
var hud: Control
var sound: Node
var playing := false
var overlay := "title"
var flags := {"needle":false,"moth":false,"secret":false,"boss":false,"rung":false,"shortcut":false,"finished":false,"vale":false}
var settings := {"sensitivity":0.0025,"fov":78.0,"volume":0.7,"music":0.7,"shake":0.65,"retro":true,"fullscreen":false}
var enemies: Array = []
var interactions: Array = []
var projectiles: Array = []
var focused: Dictionary = {}
var message := ""
var message_time := 0.0
var damage_flash := 0.0
var hit_flash := 0.0
var elapsed := 0.0
var draughts := 3
var essence := 0
var visited: Array = []
var room_name := "The Quiet Nave"
var room_time := 4.0
var dialogue := ""
var dialogue_title := ""
var boss: CharacterBody3D
var automated := false
var title_camera: Camera3D

func _ready() -> void:
	automated = "--verify" in OS.get_cmdline_user_args() or "--tour" in OS.get_cmdline_user_args()
	configure_input()
	load_settings()
	if not automated:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	world = World.new()
	world.game = self
	add_child(world)
	player = Player.new()
	player.game = self
	add_child(player)
	player.position = Vector3(0,0.1,5.4)
	sound = Sound.new()
	add_child(sound)
	sound.ambient.volume_db = linear_to_db(maxf(settings.music,0.001))-18
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = HUD.new()
	hud.game = self
	canvas.add_child(hud)
	title_camera = Camera3D.new()
	add_child(title_camera)
	title_camera.position = Vector3(6.8,2.8,6.8)
	title_camera.look_at(Vector3(-0.8,2.2,-4.5))
	title_camera.fov = 73
	title_camera.current = true
	spawn_enemies()
	hud.show_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("HOLLOW_STAR_READY rooms=9 controller=ready")
	if "--verify" in OS.get_cmdline_user_args():
		automated = true
		call_deferred("run_verification")
	if "--tour" in OS.get_cmdline_user_args():
		automated = true
		call_deferred("capture_tour")

func configure_input() -> void:
	var keys := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"sprint":KEY_SHIFT,"crouch":KEY_CTRL,"interact":KEY_E,"spell":KEY_Q,"transform":KEY_R,"heal":KEY_F,"inventory":KEY_TAB,"pause":KEY_ESCAPE}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action,event)
	for action in {"attack":MOUSE_BUTTON_LEFT,"block":MOUSE_BUTTON_RIGHT}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
			InputMap.action_add_event(action,event)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if overlay == "settings":
			set_overlay("pause" if playing else "title")
		elif playing and overlay in ["", "pause", "inventory", "dialogue"]:
			set_overlay("pause" if overlay == "" else "")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and playing and overlay in ["","inventory"]:
		set_overlay("inventory" if overlay == "" else "")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and overlay == "dialogue":
		set_overlay("")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		screenshot("user://hollow_star_screenshot.png")

func _process(delta: float) -> void:
	message_time = maxf(0,message_time-delta)
	damage_flash = maxf(0,damage_flash-delta)
	hit_flash = maxf(0,hit_flash-delta)
	room_time = maxf(0,room_time-delta)
	if not playing:
		title_camera.position.y = 2.8+sin(Time.get_ticks_msec()*0.00025)*0.1
		return
	if overlay != "":
		return
	elapsed += delta
	update_focus()
	var room: String = world.room_at(player.global_position)
	if room != room_name:
		room_name = room
		room_time = 4.5
		if not room in visited:
			visited.append(room)
			if room == "Moon Gap":
				notify("The bridge is gone. R to transform • Space to leap • Keep moving to glide.",8)
			elif room == "Flooded Vestibule":
				notify("Read the raised blade. Hold RMB to block; strike during recovery.",7)

func start_game(continue_save: bool = false) -> void:
	flags = {"needle":false,"moth":false,"secret":false,"boss":false,"rung":false,"shortcut":false,"finished":false,"vale":false}
	visited = ["The Quiet Nave"]
	draughts = 3
	essence = 0
	elapsed = 0
	if continue_save:
		load_game()
	playing = true
	set_overlay("")
	player.camera.current = true
	player.global_position = Vector3(0,0.1,5.4)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.health = 100
	player.stamina = 100
	player.charge = 100
	player.moth = false
	player.last_safe = player.position
	spawn_enemies()
	world.apply_progress()
	notify("Speak with Sister Vale beside the candles. E to interact.",7)

func set_overlay(value: String) -> void:
	overlay = value
	player.attacking = false
	player.blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value == "" and playing and not automated else Input.MOUSE_MODE_VISIBLE
	hud.show_menu()

func spawn_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()
	var placements := [[Vector3(-2,0,-25),"pilgrim"],[Vector3(3,0,-29),"pilgrim"],[Vector3(-3,0,-46),"pilgrim"],[Vector3(3,0,-49),"pilgrim"],[Vector3(26,0,-49),"pilgrim"],[Vector3(29,0,-43),"moth"],[Vector3(46,0,-46),"moth"],[Vector3(49,0,2),"boss"]]
	for entry in placements:
		var enemy = Enemy.new()
		enemy.game = self
		enemy.kind = entry[1]
		add_child(enemy)
		enemy.position = entry[0]
		enemy.home = entry[0]
		enemies.append(enemy)
		if enemy.kind == "boss":
			boss = enemy
			if flags.boss:
				boss.dead = true
				boss.hide()
				boss.collision_layer = 0

func add_interaction(id: String, label: String, point: Vector3, visual: Node3D = null) -> void:
	interactions.append({"id":id,"label":label,"position":point,"visual":visual})

func update_focus() -> void:
	focused = {}
	var nearest := 3.3
	for item in interactions:
		var id: String = item.id
		if id in ["needle","moth","secret"] and flags[id]:
			continue
		if id == "secret" and not player.moth:
			continue
		var offset: Vector3 = item.position-player.camera.global_position
		var distance := offset.length()
		if distance < nearest and (-player.camera.global_basis.z).dot(offset.normalized())>0.78 and clear_line(player.camera.global_position,item.position):
			focused = item
			nearest = distance

func interact() -> void:
	if not focused.is_empty():
		activate(focused.id)

func activate(id: String) -> void:
	match id:
		"vale":
			flags.vale = true
			dialogue_title = "SISTER VALE"
			if flags.boss:
				dialogue = "You heard it, too. A voice inside the bell.\n\nI came here for my brother. Now it dreams in his voice.\n\nRest, pilgrim. Something below has learned your name."
			elif flags.moth:
				dialogue = "Silver dust on your shoulders. So it chose you.\n\nThe wings will bear you over the missing bridge.\nBeyond it, the Keeper guards a bell that should never ring."
			else:
				dialogue = "You came for someone. We all do.\n\nFollow the drowned halls. Take the star from the pilgrims' crypt, and the wings from the chapel beyond.\n\nCross the broken bridge. Silence its Keeper. Ring the bell."
			set_overlay("dialogue")
		"shrine":
			player.health = 100
			player.stamina = 100
			player.charge = 100
			draughts = 3
			if flags.boss and flags.shortcut:
				flags.finished = true
				save_game()
				set_overlay("ending")
			else:
				save_game()
				notify("RESTORED  •  Progress saved at the Quiet Nave.")
			sound.play_tone("bell",-4)
		"needle":
			if flags.needle: return
			flags.needle = true
			player.charge = 100
			notify("STAR NEEDLE ACQUIRED  •  Q to cast. Moths are vulnerable to starlight.",8)
			sound.play_tone("pickup")
			save_game()
		"moth":
			if flags.moth: return
			flags.moth = true
			player.charge = 100
			notify("MOTH FORM ACQUIRED  •  R to transform. The silver eye reveals what stone conceals.",8)
			sound.play_tone("pickup")
			save_game()
		"secret":
			if not player.moth or flags.secret: return
			flags.secret = true
			essence += 50
			player.charge = 100
			draughts = mini(5,draughts+2)
			notify("SECRET FOUND  •  The Unwritten Name. +50 essence, +2 moon draughts.",7)
			sound.play_tone("pickup")
			save_game()
		"shortcut":
			if not flags.rung:
				notify("The Keeper's vow binds this gate. Ring the drowned bell.")
			else:
				flags.shortcut = true
				world.apply_progress()
				notify("SHORTCUT OPENED  •  The Quiet Nave waits beyond. Rest at its shrine.",7)
				sound.play_tone("bell")
				save_game()
		"bell":
			if not flags.boss:
				notify("The Bell Keeper still holds its voice.")
			else:
				flags.rung = true
				flags.shortcut = true
				world.apply_progress()
				dialogue_title = "THE DROWNED BELL"
				dialogue = "The sound does not travel through the air.\nIt travels through you.\n\nFar beneath the water, a star opens its eye.\nAnd in the echo, you hear the person you came to find.\n\nThe western gate opens. Return to the Quiet Nave."
				set_overlay("dialogue")
				sound.play_tone("bell")
				save_game()
	world.apply_progress()

func objective() -> String:
	if flags.finished: return "The star has learned your name."
	if flags.shortcut: return "Return to the Quiet Nave • Rest at the shrine"
	if flags.boss: return "Ring the drowned bell"
	if flags.moth: return "Cross Moon Gap • Silence the Bell Keeper"
	if flags.needle: return "Find the winged reliquary in the Moth Chapel"
	if flags.vale: return "Follow the drowned halls • Find the Pilgrim Crypt"
	return "Speak with Sister Vale in the Quiet Nave"

func objective_position() -> Vector3:
	if flags.shortcut: return Vector3(0,1,-4)
	if flags.boss: return Vector3(46,2,8)
	if flags.moth: return Vector3(46,1,0)
	if flags.needle: return Vector3(49,1.4,-50)
	if flags.vale: return Vector3(21,1,-49)
	return Vector3(-5,1,-3)

func heal() -> void:
	if draughts <= 0:
		notify("No moon draughts remain. Rest at the sanctuary.")
		return
	if player.health >= 100 and player.charge >= 100: return
	draughts -= 1
	player.health = minf(100,player.health+45)
	player.charge = minf(100,player.charge+35)
	sound.play_tone("pickup",-5)
	notify("Moon draught • Health and starlight restored.")

func die() -> void:
	set_overlay("death")

func respawn() -> void:
	player.position = Vector3(0,0.15,5.4)
	player.velocity = Vector3.ZERO
	player.health = 100
	player.stamina = 100
	player.charge = 100
	player.moth = false
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.last_safe = player.position
	draughts = 3
	spawn_enemies()
	set_overlay("")
	notify("The shrine remembers. Your discoveries remain.")

func enemy_defeated(enemy: Node3D) -> void:
	essence += 12 if enemy.kind != "boss" else 120
	player.charge = minf(100,player.charge+14)
	if enemy.kind == "boss":
		flags.boss = true
		notify("THE BELL KEEPER FALLS  •  Ring the bell beneath the broken halo.",9)
		sound.play_tone("bell")
		save_game()

func spawn_projectile(pos: Vector3, direction: Vector3, hostile: bool, damage: float) -> Node3D:
	var p = Projectile.new()
	p.game = self
	p.direction = direction.normalized()
	p.hostile = hostile
	p.damage = damage
	add_child(p)
	p.global_position = pos
	projectiles.append(p)
	return p

func clear_line(a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a,b,1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func notify(text: String, duration: float = 5.0) -> void:
	message = text
	message_time = duration

func save_game(path: String = SAVE_PATH) -> bool:
	if automated and path == SAVE_PATH: return true
	var data := {"version":1,"flags":flags,"essence":essence,"elapsed":elapsed,"visited":visited}
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		notify("Could not save progress. Check write access to the save folder.")
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var result := DirAccess.rename_absolute(path+".tmp",path)
	if result != OK:
		notify("Save could not be finalized.")
		return false
	return true

func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version",0) != 1 or not data.get("flags") is Dictionary:
		notify("The save could not be read. A fresh pilgrimage begins.")
		return false
	for key in flags:
		flags[key] = data.flags.get(key,false) == true
	essence = maxi(0,int(data.get("essence",0)))
	elapsed = maxf(0,float(data.get("elapsed",0)))
	if data.get("visited") is Array: visited = data.visited
	return true

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if data is Dictionary:
			for key in settings:
				if data.has(key) and (data[key] is float or data[key] is int or data[key] is bool):
					settings[key] = data[key]
	settings.sensitivity = clampf(settings.sensitivity,0.0006,0.007)
	settings.fov = clampf(settings.fov,65,100)
	settings.volume = clampf(settings.volume,0,1)
	settings.music = clampf(settings.music,0,1)
	settings.shake = clampf(settings.shake,0,1)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(settings.volume,0.001)))

func save_settings() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(settings.volume,0.001)))
	sound.ambient.volume_db = linear_to_db(maxf(settings.music,0.001))-18
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if automated: return
	var file := FileAccess.open(SETTINGS_PATH,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(settings))

func screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SCREENSHOT ",path)

func run_verification() -> void:
	var suite = load("res://demo/verify.gd").new()
	add_child(suite)
	await suite.run(self)

func capture_tour() -> void:
	var capture_root := "res://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_root = arg.trim_prefix("--capture-dir=").trim_suffix("/")+"/"
	await get_tree().create_timer(3).timeout
	await screenshot(capture_root+"demo_title.png")
	start_game(false)
	player.automation = true
	flags.vale = true
	for enemy in enemies: enemy.set_physics_process(false)
	message_time = 0
	var shots := [
		[Vector3(0,0.1,5.4),Vector3(0,2,-4),"demo_nave"],
		[Vector3(-5,0.1,-20),Vector3(2,2,-28),"demo_vestibule"],
		[Vector3(-5,0.1,-40),Vector3(3,2,-49),"demo_gallery"],
		[Vector3(19,0.1,-42),Vector3(27,1.7,-49),"demo_crypt"],
		[Vector3(42,0.1,-41),Vector3(49,2,-50),"demo_chapel"],
		[Vector3(45,0.1,-34),Vector3(46,1,-16),"demo_gap"],
		[Vector3(42,0.1,-8),Vector3(48,2,7),"demo_keeper"]
	]
	for shot in shots:
		player.position = shot[0]
		player.camera.look_at(shot[1])
		for enemy in enemies:
			var offset: Vector3 = player.position-enemy.position
			if offset.length() < 15: enemy.rotation.y = atan2(-offset.x,-offset.z)
		room_name = world.room_at(player.position)
		room_time = 4
		if shot[2] == "demo_chapel": flags.needle = true
		if shot[2] == "demo_gap": flags.moth = true
		await get_tree().create_timer(1).timeout
		await screenshot(capture_root+shot[2]+".png")
		print("PERFORMANCE ",shot[2]," fps=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	set_overlay("inventory")
	await get_tree().create_timer(0.2).timeout
	await screenshot(capture_root+"demo_inventory.png")
	set_overlay("settings")
	await get_tree().create_timer(0.2).timeout
	await screenshot(capture_root+"demo_settings.png")
	set_overlay("")
	activate("vale")
	await get_tree().create_timer(0.2).timeout
	await screenshot(capture_root+"demo_dialogue.png")
	get_tree().quit()
