extends Node
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ")+label)
	if not condition: failures.append(label)

func run(game: Node3D) -> void:
	game.start_game(false)
	game.player.automation = true
	for enemy in game.enemies: enemy.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(game.world.room_bounds.size() >= 9,"Connected dungeon layout exists")
	check(InputMap.has_action("forward") and InputMap.has_action("transform"),"Input map has movement and transformation")
	check(game.player.health == 100,"Player starts healthy")
	verify_art(game)
	# A real physics ray verifies solid flooring at each required stop.
	for point in [Vector3(0,0,5),Vector3(0,0,-12),Vector3(0,0,-24),Vector3(0,0,-44),Vector3(24,0,-46),Vector3(46,0,-46),Vector3(46,0,-33),Vector3(46,0,-16),Vector3(46,0,0),Vector3(22,0,0)]:
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP,1)
		check(not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Floor at "+str(point))
	var gap_query := PhysicsRayQueryParameters3D.create(Vector3(46,2,-25),Vector3(46,-3,-25),1)
	check(game.get_world_3d().direct_space_state.intersect_ray(gap_query).is_empty(),"Moon Gap has no human walkable bridge")
	check(not game.player.transform(),"Moth form locked before discovery")
	game.activate("needle")
	check(game.flags.needle,"Spell pickup unlocks Star Needle")
	var before: float = game.player.charge
	check(game.player.cast_spell(),"Spell fires")
	check(game.player.charge == before-9,"Spell consumes starlight")
	game.activate("moth")
	check(game.player.transform(),"Moth form unlocks")
	check(not game.player.melee(),"Moth cannot use the sword")
	game.activate("secret")
	check(game.flags.secret and game.essence == 50,"Moth perception reveals a meaningful secret")
	game.player.transform()
	var pilgrim = game.enemies[0]
	game.player.global_position = pilgrim.global_position+Vector3(0,0,2)
	game.player.rotation.y = 0
	game.player.camera.rotation = Vector3.ZERO
	game.player.attack_cooldown = 0
	game.player.stamina = 100
	check(game.player.melee(),"Light melee attack executes")
	check(pilgrim.health < pilgrim.max_health,"Melee damages a visible enemy in reach")
	game.player.blocking = true
	game.player.invulnerable = 0
	game.player.take_damage(20,pilgrim.global_position)
	check(game.player.health > 95,"Forward block mitigates damage")
	game.player.blocking = false
	game.player.invulnerable = 0
	game.player.take_damage(1000)
	check(game.overlay == "death","Death opens recovery screen")
	var escape := InputEventAction.new()
	escape.action = "pause"
	escape.pressed = true
	game._unhandled_input(escape)
	check(game.overlay == "death" and game.player.health == 0,"Escape cannot resume a dead player")
	game.respawn()
	game.player.automation = true
	for enemy in game.enemies: enemy.set_physics_process(false)
	check(game.flags.moth and game.flags.needle and game.flags.secret,"Death preserves discoveries")
	check(game.player.health == 100 and game.player.position.z>0,"Respawn restores the shrine checkpoint")
	game.set_overlay("settings")
	game._unhandled_input(escape)
	check(game.overlay == "pause","Escape from settings returns to pause")
	game.set_overlay("")
	game.boss.take_damage(1000)
	check(game.flags.boss,"Boss death records progression")
	game.activate("bell")
	check(game.flags.shortcut,"Ringing the bell opens the return loop")
	game.set_overlay("")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(game.world.gates[0][1].disabled,"Shortcut collision is disabled")
	check(game.save_game("user://hollow_star_verification.json"),"Versioned save writes successfully")
	game.flags.moth = false
	check(game.load_game("user://hollow_star_verification.json") and game.flags.moth and game.flags.boss,"Save round trip restores progression")
	game.activate("shrine")
	check(game.flags.finished and game.overlay == "ending","Return to shrine completes the demo")
	game.set_overlay("")
	game.player.automation = false
	game.player.moth = false
	game.player.position = Vector3(3,0.1,5)
	game.player.velocity = Vector3.ZERO
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
		enemy.collision_mask = 0
	var route := [Vector3(3,0,-6),Vector3(0,0,-6),Vector3(0,0,-23),Vector3(0,0,-35),Vector3(0,0,-45),Vector3(13,0,-45),Vector3(24,0,-46),Vector3(35,0,-46),Vector3(46,0,-46),Vector3(46,0,-32)]
	for target in route:
		var arrived := false
		for frame in range(650):
			var offset: Vector3 = target-game.player.position
			if Vector2(offset.x,offset.z).length()<0.38:
				arrived = true
				break
			game.player.rotation.y = atan2(-offset.x,-offset.z)
			Input.action_press("forward")
			await get_tree().physics_frame
		Input.action_release("forward")
		check(arrived,"Physical walking route reaches "+str(target)+" actual="+str(game.player.position))
		if not arrived: break
	game.player.position = Vector3(46,0.1,-31)
	game.player.velocity = Vector3.ZERO
	game.player.rotation.y = PI
	game.player.camera.rotation = Vector3.ZERO
	for frame in range(20): await get_tree().physics_frame
	Input.action_press("forward")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	for frame in range(170): await get_tree().physics_frame
	Input.action_release("forward")
	check(game.player.position.z < -21,"Human jump cannot cross Moon Gap")
	game.player.position = Vector3(46,0.1,-31)
	game.player.velocity = Vector3.ZERO
	game.player.charge = 100
	game.player.health = 100
	for frame in range(20): await get_tree().physics_frame
	game.player.transform()
	Input.action_press("forward")
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	for frame in range(155): await get_tree().physics_frame
	Input.action_release("forward")
	check(game.player.position.z > -21,"Moth jump physically crosses Moon Gap: "+str(game.player.position))
	check(game.player.charge < 100,"Gliding continuously consumes starlight")
	game.player.moth = false
	game.player.position = Vector3(46,0.1,0)
	game.player.velocity = Vector3.ZERO
	for target in [Vector3(32,0,0),Vector3(22,0,0),Vector3(6,0,0)]:
		var arrived := false
		for frame in range(650):
			var offset: Vector3 = target-game.player.position
			if Vector2(offset.x,offset.z).length()<0.4:
				arrived = true
				break
			game.player.rotation.y = atan2(-offset.x,-offset.z)
			Input.action_press("forward")
			await get_tree().physics_frame
		Input.action_release("forward")
		check(arrived,"Opened return passage is physically traversable to "+str(target))
	print("HOLLOW_STAR_VERIFICATION "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

func verify_art(game: Node3D) -> void:
	# Inspect instantiated meshes, not just source paths: this also catches missing
	# runtime-loaded resources in the standalone Windows export.
	var art = preload("res://demo/art.gd")
	var assets := {}
	var textures := {}
	var issues: Array[String] = []
	var pending: Array[Node] = [game]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.has_meta("art_asset"): assets[node.get_meta("art_asset")] = true
		if node is MeshInstance3D and node.mesh != null:
			for surface in range(node.mesh.get_surface_count()):
				var source: Material = node.mesh.surface_get_material(surface)
				if source == null or not source.resource_name.begins_with("cloister_"): continue
				var key := source.resource_name.trim_prefix("cloister_")
				var active: Material = node.get_active_material(surface)
				if not art.PALETTE.has(key) or active != art.material(key):
					issues.append(str(node.get_path())+" has an unresolved material: "+key)
					continue
				var expected: String = art.PALETTE[key][0]
				if expected != "":
					if active.albedo_texture == null or active.albedo_texture.resource_path != art.TEXTURE_ROOT+expected:
						issues.append("Missing library texture: "+expected)
					else: textures[expected] = true
					var arrays: Array = node.mesh.surface_get_arrays(surface)
					if arrays[Mesh.ARRAY_TEX_UV] == null or arrays[Mesh.ARRAY_TEX_UV].is_empty(): issues.append("Missing UVs: "+key)
		for child in node.get_children(): pending.append(child)
	check(assets.size() == 18,"All 18 Blender kit assets are instantiated in the playable game")
	check(issues.is_empty(),"Blender surfaces resolve shared materials, textures and UVs: "+str(issues))
	check(textures.size() == 11,"All 11 original library textures are applied to game meshes")
	var articulated := true
	for enemy in game.enemies:
		if enemy.kind == "moth": articulated = articulated and enemy.wings.size() == 2
		else: articulated = articulated and enemy.arm != null and enemy.off_arm != null and enemy.legs.size() == 2
	check(articulated,"Every enemy exposes its weapon, limb or wing animation pivots")
