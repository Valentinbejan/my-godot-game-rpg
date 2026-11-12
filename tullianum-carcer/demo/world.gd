extends Node3D
const G = preload("res://demo/geometry.gd")
const A = preload("res://demo/art.gd")
var game: Node3D
var stone: StandardMaterial3D
var trim: StandardMaterial3D
var dark: StandardMaterial3D
var floor_mat: StandardMaterial3D
var gold: StandardMaterial3D
var silver: StandardMaterial3D
var flame: StandardMaterial3D
var water_mat: ShaderMaterial
var rings: Array = []
var candles: Array = []
var motes: MultiMeshInstance3D
var pickups: Dictionary = {}
var gates: Array = []
var secret_runes: Node3D
var time := 0.0
var rng := RandomNumberGenerator.new()
var room_bounds: Array = []

func _ready() -> void:
	rng.seed = 190719
	stone = G.textured("res://assets/textures/pack2/256x256/Brick/Brick_10-256x256.png",Color("bcc7cb"))
	stone.uv1_scale = Vector3.ONE*0.7
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	trim = G.textured("res://assets/textures/pack2/256x256/Stone/Stone_03-256x256.png",Color("879e9e"))
	trim.uv1_scale = Vector3.ONE*0.65
	dark = G.material(Color("1d2930"))
	floor_mat = G.textured("res://assets/textures/pack2/256x256/Stone/Stone_06-256x256.png",Color("88969b"))
	gold = G.material(Color("a48a59"))
	gold.metallic = 0.65
	gold.roughness = 0.4
	silver = G.material(Color("b8e0d4"),2.3)
	flame = G.material(Color("ffcf8a"),5)
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://demo/water.gdshader")
	build_environment()
	build_layout()
	build_landmarks()
	build_details()
	build_carved_architecture()
	build_motes()

func build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07131e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8ba4b8")
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.38
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color("18343c")
	env.fog_density = 0.006
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color("90aab4")
	env.volumetric_fog_length = 48.0
	env.fog_sky_affect = 0.1
	env.ssao_enabled = true
	env.ssao_intensity = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("839db8")
	moon.light_energy = 0.10
	moon.rotation_degrees = Vector3(-62,-30,0)
	add_child(moon)

func build_layout() -> void:
	room("The Quiet Nave",Vector2(0,0),Vector2(18,16),["N","E"],8.5)
	room("Bell Stair",Vector2(0,-12),Vector2(6,8),["N","S"],6)
	room("Flooded Vestibule",Vector2(0,-24),Vector2(18,16),["N","S"],6.5)
	room("The Listening Passage",Vector2(0,-35),Vector2(6,6),["N","S"],5)
	room("Broken Gallery",Vector2(0,-45),Vector2(20,14),["S","E"],7)
	room("The Pilgrims' Way",Vector2(13,-46),Vector2(6,5),["E","W"],5)
	room("Pilgrim Crypt",Vector2(24,-46),Vector2(16,16),["E","W"],6)
	room("The Silver Threshold",Vector2(34.5,-46),Vector2(5,5),["E","W"],5)
	room("Moth Chapel",Vector2(46,-46),Vector2(18,18),["W","S"],8)
	room("Drowned Bell Chamber",Vector2(46,0),Vector2(24,24),["N","W"],11)
	room("Return Passage",Vector2(21.5,0),Vector2(25,6),["E","W"],5.5)
	# The only missing floor on the critical route: an eight-meter Moth crossing.
	for z in [-33.0,-16.5]:
		G.box(self,Vector3(46,-0.22,z),Vector3(6,0.44,8 if z == -33 else 9),floor_mat,true)
		for side in [-1,1]:
			G.box(self,Vector3(46+side*3.2,0.55,z),Vector3(0.5,1.1,8 if z == -33 else 9),stone,true)
			for dz in [-3,0,3]:
				G.pillar(self,Vector3(46+side*3.2,0,z+dz),3.2,stone,trim)
	for x in [40.0,52.0]:
		G.box(self,Vector3(x,3,-25),Vector3(1,18,24),stone,true)
	for z in [-29.3,-20.7]:
		G.arch(self,Vector3(46,0,z),5.6,2.8,trim)
		for side in [-1,1]:
			candle(Vector3(46+side*2.2,0.1,z),3)
	water(Vector3(46,-4,-25),Vector2(12,28))
	G.light(self,Vector3(46,4,-25),Color("749dce"),3.8,18)
	room_bounds.append({"name":"Moon Gap","rect":Rect2(39,-37,14,25)})
	# Closed shortcut visible from the sanctuary; opens after the bell is rung.
	gate(Vector3(11.7,0,0),true)
	gate(Vector3(33.3,0,0),true)
	game.add_interaction("shortcut","Unseal the return gate",Vector3(11.6,1.4,0))
	game.add_interaction("shortcut","Unseal the return gate",Vector3(33.2,1.4,0))

func room(label: String, center: Vector2, dimensions: Vector2, doors: Array, height: float) -> void:
	var c := Vector3(center.x,0,center.y)
	room_bounds.append({"name":label,"rect":Rect2(center-dimensions*0.5,dimensions)})
	G.box(self,c+Vector3(0,-0.25,0),Vector3(dimensions.x,0.5,dimensions.y),floor_mat,true)
	var half := dimensions*0.5
	for dir in ["N","S","E","W"]:
		var ns: bool = dir in ["N","S"]
		var length: float = dimensions.x if ns else dimensions.y
		var sign_value: float = -1 if dir in ["N","W"] else 1
		var origin := c+Vector3(0,0,sign_value*half.y) if ns else c+Vector3(sign_value*half.x,0,0)
		if dir in doors:
			var segment := (length-4.6)*0.5
			for side in [-1,1]:
				var shift: float = side*(2.3+segment*0.5)
				G.box(self,origin+Vector3(shift,height*0.5,0) if ns else origin+Vector3(0,height*0.5,shift),Vector3(segment,height,0.7) if ns else Vector3(0.7,height,segment),stone,true)
			G.box(self,origin+Vector3(0,(height+4.7)*0.5,0),Vector3(4.6,height-4.7,0.7) if ns else Vector3(0.7,height-4.7,4.6),stone,true)
			G.arch(self,origin,4.5,2.6,trim,not ns)
		else:
			G.box(self,origin+Vector3.UP*height*0.5,Vector3(length,height,0.7) if ns else Vector3(0.7,height,length),stone,true)
		# Continuous cornice and high stonework break up flat walls.
		G.box(self,origin+Vector3.UP*(height-0.3),Vector3(length,0.32,1.0) if ns else Vector3(1.0,0.32,length),trim)
	if dimensions.x < 8 or dimensions.y < 8:
		G.box(self,c+Vector3.UP*(height+0.12),Vector3(dimensions.x,0.25,dimensions.y),dark)
	else:
		for x in [-half.x+1.4,half.x-1.4]:
			for z in [-half.y+2.1,0,half.y-2.1]:
				if absf(z)<0.1 and ((x>0 and "E" in doors) or (x<0 and "W" in doors)):
					continue
				G.pillar(self,c+Vector3(x,0,z),height-2.0,stone,trim)
		var bay_count := int(ceil(dimensions.y/4.0))
		for bay in range(bay_count):
			var depth := dimensions.y/float(bay_count)
			var z := -half.y+depth*(bay+0.5)
			A.place("ribbed_vault",self,c+Vector3(0,height-2.0,z),Vector3((dimensions.x-2.8)/8.0,1,depth/4.0))
		for side in [-1,1]:
			G.box(self,c+Vector3(side*(half.x-0.7),height-1.9,0),Vector3(1.5,0.22,dimensions.y),dark)
		var nx := int(dimensions.x/4.0)
		var nz := int(dimensions.y/4.0)
		for ix in range(nx):
			for iz in range(nz):
				A.place("flagstone_floor",self,c+Vector3((ix-(nx-1)*0.5)*4,0.023,(iz-(nz-1)*0.5)*4))
		var shaft := SpotLight3D.new()
		add_child(shaft)
		shaft.position = c+Vector3(half.x*0.55,height-0.2,-half.y*0.55)
		shaft.light_color = Color("9bc4d1")
		shaft.light_energy = 6.0
		shaft.light_volumetric_fog_energy = 2.0
		shaft.spot_range = height*2.0
		shaft.spot_angle = 32.0
		shaft.shadow_enabled = true
		shaft.look_at(c+Vector3(-2,0,1))
		# Narrow polished inlay leads through otherwise dark, worn paving.
		for x in [-1.2,1.2]:
			G.box(self,c+Vector3(x,0.012,0),Vector3(0.035,0.018,dimensions.y-0.5),gold)
		for i in range(int(dimensions.y/2)):
			G.box(self,c+Vector3(0,0.005,-half.y+i*2),Vector3(dimensions.x-0.4,0.014,0.025),dark)
		for side in [-1,1]:
			var pos := c+Vector3(side*(half.x-2.0),0.5,half.y-3)
			candle(pos,5)
		G.light(self,c+Vector3(0,height-1,0),Color("6e9db2"),1.7,maxf(dimensions.x,dimensions.y))

func build_landmarks() -> void:
	# Quiet Nave: raised octagonal shrine under a suspended, broken astrolabe.
	var altar := Vector3(0,0,-4)
	A.place("celestial_shrine",self,altar)
	for i in range(3):
		var halo := G.ring(self,altar+Vector3(0,3.6,0),1.6+i*0.36,0.025,gold if i != 1 else silver)
		halo.rotation = Vector3(PI/2.0,0.35*i,0.4*i)
		rings.append(halo)
	for x in [-1,1]:
		G.line(self,Vector3(x*1.5,7,-4),Vector3(x*1.5,4,-4),0.016,gold)
	G.light(self,altar+Vector3.UP*2.5,Color("9ffff0"),3.1,9,true)
	for x in [-5.5,5.5]:
		water(Vector3(x,0.03,-0.5),Vector2(3.5,11))
		for z in [-5,-2,1,4]:
			G.box(self,Vector3(x,0.15,z),Vector3(2.4,0.3,0.5),trim)
	game.add_interaction("shrine","Rest at the quiet flame",altar+Vector3.UP*1.6)
	inscription(Vector3(0,5.5,-7.55),"THE DEAD DO NOT DREAM",0.008,Color("9db8b8"))
	# The guide shares the kit's sculpted cowl, layered robes, and candle staff.
	A.place("sister_vale",self,Vector3(-4.3,0,-3),Vector3.ONE,-0.5)
	game.add_interaction("vale","Speak with Sister Vale",Vector3(-4.3,1.4,-3))
	candle(Vector3(-3.5,0,-3.2),5)
	# The flooded hall contains islands, submerged graves, and a broken bell.
	water(Vector3(0,0.028,-24),Vector2(16,14))
	for x in [-3,0,3]:
		for z in [-29,-25,-21]:
			G.box(self,Vector3(x,0.035,z),Vector3(2.5,0.07,3.1),floor_mat)
	var broken_bell := A.place("votive_brazier",self,Vector3(5,0.40,-29))
	broken_bell.rotation.z = 1.05
	# A gallery of empty apertures and one toppled column.
	for x in [-7.5,-3.8,0,3.8,7.5]:
		G.arch(self,Vector3(x,0,-51.4),2.4,2.5,trim)
		G.box(self,Vector3(x,2,-51.5),Vector3(1.8,3.8,0.05),dark)
	var fallen := A.place("fluted_column",self,Vector3(-6.4,0.46,-44),Vector3(0.7,0.7,0.7))
	fallen.rotation.z = PI/2
	fallen.rotation.y = 0.35
	# The spell has its own light source and a clear silhouette above a tomb.
	for x in [19,29]:
		for z in [-50,-42]:
			A.place("pilgrim_sarcophagus",self,Vector3(x,0,z))
			var collision := G.box(self,Vector3(x,0.43,z),Vector3(1.3,0.85,2.3),stone,true)
			collision.get_child(0).hide()
	pickup("needle",Vector3(21,1.25,-49),"Take Star Needle",false)
	inscription(Vector3(24,4,-53.5),"WE CARRIED THE LIGHT BELOW",0.011,Color("a2b2b0"))
	# Moth Chapel: winged reliquary, a luminous rose window, and hidden script.
	G.cylinder(self,Vector3(49,0.62,-50),0.95,0.72,1.24,stone,8)
	pickup("moth",Vector3(49,1.65,-50),"Receive Moth Form",true)
	var rose_center := Vector3(46,4.8,-54.3)
	for i in range(3):
		var rose := G.ring(self,rose_center,1.25+i*0.4,0.035,silver if i==0 else gold)
		rose.rotation.x = PI/2
	for i in range(12):
		var a := TAU*i/12.0
		G.line(self,rose_center+Vector3(cos(a)*0.5,sin(a)*0.5,0),rose_center+Vector3(cos(a)*1.95,sin(a)*1.95,0),0.022,silver)
	G.light(self,rose_center+Vector3(0,0,1),Color("b1a3f3"),4,13)
	secret_runes = Node3D.new()
	add_child(secret_runes)
	for i in range(5):
		var a := TAU*i/5
		G.line(secret_runes,Vector3(54.54,1.8+sin(a),-44+cos(a)),Vector3(54.54,1.8+sin(a+TAU*2/5),-44+cos(a+TAU*2/5)),0.018,silver)
	inscription(Vector3(54.5,3.4,-44),"A NAME THE STONE FORGOT",0.012,Color("bef7e6"),-PI/2,secret_runes)
	game.add_interaction("secret","Read the unwritten name",Vector3(54.2,1.8,-44))
	for z in [-36.6,-32.5,-28.9,-20.8,-17,-12.5]:
		var rune := G.ring(secret_runes,Vector3(46,0.08,z),0.38,0.023,silver)
		rune.rotation.z = 0.1
	# The Bell Chamber's impossible halo is visible from across the chasm.
	var bell_center := Vector3(46,0,8)
	G.cylinder(self,bell_center+Vector3.UP*0.15,2.4,2.4,0.3,trim,12)
	var bell_asset: PackedScene = load("res://assets/models/demo/drowned_bell.glb")
	var bell_model := bell_asset.instantiate() as Node3D
	add_child(bell_model)
	bell_model.position = bell_center+Vector3.UP*1.05
	G.line(self,bell_center+Vector3.UP*3.2,bell_center+Vector3.UP*9,0.045,gold)
	game.add_interaction("bell","Ring the drowned bell",bell_center+Vector3(0,1.7,-1.2))
	for i in range(3):
		var halo := G.ring(self,Vector3(46,7,8),2.8+i*0.5,0.045,gold if i<2 else silver)
		halo.rotation = Vector3(PI/2+0.2*i,0.3*i,0.5*i)
		rings.append(halo)
	G.light(self,Vector3(46,6,5),Color("cfb992"),5.5,19,true)
	for x in [38,54]:
		water(Vector3(x,0.024,0),Vector2(3.5,19))
		for z in [-6,6]:
			G.pillar(self,Vector3(x,0,z),8,stone,trim)
	inscription(Vector3(46,5.2,11.5),"LET NO DREAM PASS",0.016,Color("ccb989"),PI)

func build_details() -> void:
	for center in [Vector3(0,0,0),Vector3(0,0,-24),Vector3(0,0,-45),Vector3(24,0,-46),Vector3(46,0,-46),Vector3(46,0,0)]:
		for side in [-1,1]:
			for z in [-4,4]:
				candle(center+Vector3(side*6.5,0.1,z),rng.randi_range(3,6))
		for i in range(16):
			var pos: Vector3 = center+Vector3(rng.randf_range(-7,7),0.07,rng.randf_range(-5.5,5.5))
			if absf(pos.x-center.x)<2: continue
			var shard := G.box(self,pos,Vector3(rng.randf_range(0.12,0.48),rng.randf_range(0.08,0.2),rng.randf_range(0.1,0.5)),stone)
			shard.rotation.y = rng.randf_range(0,TAU)
	# Small wayfinding plaques sit beside important thresholds.
	inscription(Vector3(0,4.55,-15.4),"S U N K E N   C L O I S T E R",0.004,Color("b2b6ad"))
	inscription(Vector3(36.5,3.7,-46),"WINGS REMEMBER",0.009,Color("bfbcab"),PI/2)
	for z in [-10,-12,-14]:
		G.box(self,Vector3(0,0.012,z),Vector3(4.5,0.022,0.55),trim)
		candle(Vector3(2.1,0.06,z),2)
	# Chain silhouettes and a constellation high above the open roofs.
	for i in range(150):
		var pos := Vector3(rng.randf_range(-35,85),rng.randf_range(24,45),rng.randf_range(-80,40))
		G.sphere(self,pos,rng.randf_range(0.025,0.065),silver)

func candle(pos: Vector3, count: int) -> void:
	A.place("votive_candles",self,pos,Vector3.ONE*(0.8+count*0.045),rng.randf_range(0,TAU))
	var light := G.light(self,pos+Vector3.UP*0.65,Color("ffc17a"),1.3,5.3)
	candles.append([light,rng.randf_range(0,TAU),1.3])

func brazier(pos: Vector3) -> void:
	A.place("votive_brazier",self,pos)
	var light := G.light(self,pos+Vector3.UP*1.8,Color("ffc17a"),2.0,7.0)
	candles.append([light,rng.randf_range(0,TAU),2.0])

func water(pos: Vector3, dimensions: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = dimensions
	plane.subdivide_depth = 16
	plane.subdivide_width = 12
	G.mesh(self,plane,pos,water_mat)

func gate(pos: Vector3, turned: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	if turned: root.rotation.y = PI/2
	A.place("vow_gate",root)
	var body := StaticBody3D.new()
	root.add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.6,4.6,0.3)
	col.shape = shape
	col.position.y = 2.3
	body.add_child(col)
	gates.append([root,col])

func pickup(id: String, pos: Vector3, label: String, winged: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	G.sphere(root,Vector3.ZERO,0.14,silver)
	if winged:
		A.place("glass_moth",root,Vector3(0,-0.74,0),Vector3.ONE*0.45)
	else:
		G.cylinder(root,Vector3.ZERO,0.055,0,0.7,silver,5)
	var ring := G.ring(root,Vector3.ZERO,0.65,0.015,gold)
	ring.rotation.x = PI/2
	rings.append(ring)
	G.light(root,Vector3.UP,Color("a7e6dd"),2.5,6)
	pickups[id] = root
	game.add_interaction(id,label,pos,root)

func inscription(pos: Vector3, text: String, size: float, color: Color, yaw: float = 0, parent: Node3D = self) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = size
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.double_sided = false
	parent.add_child(label)
	label.position = pos
	label.rotation.y = yaw

func build_motes() -> void:
	motes = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 0.018
	sphere.height = 0.036
	sphere.radial_segments = 4
	sphere.rings = 2
	mm.mesh = sphere
	mm.instance_count = 180
	motes.multimesh = mm
	motes.material_override = G.material(Color("9bbcba"),1.3)
	add_child(motes)
	for i in range(180):
		var room_index := i%6
		var centers := [Vector3(0,0,0),Vector3(0,0,-24),Vector3(0,0,-45),Vector3(24,0,-46),Vector3(46,0,-46),Vector3(46,0,0)]
		var origin: Vector3 = centers[room_index]+Vector3(rng.randf_range(-7,7),rng.randf_range(0.3,7),rng.randf_range(-6,6))
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,origin))

func apply_progress() -> void:
	for id in pickups:
		pickups[id].visible = not game.flags[id]
	for entry in gates:
		entry[0].visible = not game.flags.shortcut
		entry[1].set_deferred("disabled",game.flags.shortcut)

func _process(delta: float) -> void:
	if game.playing and game.overlay != "": return
	time += delta
	for i in range(rings.size()):
		rings[i].rotate_y(delta*0.12*(1 if i%2==0 else -1))
	for c in candles:
		c[0].light_energy = c[2]+sin(time*6+c[1])*0.10+sin(time*11+c[1])*0.04
	if is_instance_valid(game.player):
		secret_runes.visible = game.player.moth and not game.flags.secret
	for id in pickups:
		pickups[id].rotation.y = sin(time*0.7)*0.25
	if motes: motes.position.y = sin(time*0.3)*0.16

func room_at(pos: Vector3) -> String:
	for room_data in room_bounds:
		if room_data.rect.has_point(Vector2(pos.x,pos.z)): return room_data.name
	return "Beneath the Hollow Star"

func burst(pos: Vector3, color: Color) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	for i in range(7):
		var mote := G.sphere(root,Vector3.ZERO,0.035,G.material(color,2))
		var tween := mote.create_tween().set_parallel()
		tween.tween_property(mote,"position",Vector3(rng.randf_range(-0.7,0.7),rng.randf_range(-0.2,0.8),rng.randf_range(-0.7,0.7)),0.35)
		tween.tween_property(mote,"scale",Vector3.ZERO,0.35)
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(root.queue_free)

func build_carved_architecture() -> void:
	for center in [Vector3(0,0,0),Vector3(0,0,-24),Vector3(0,0,-45),Vector3(24,0,-46),Vector3(46,0,-46),Vector3(46,0,0)]:
		var half_width: float = 12 if center == Vector3(46,0,0) else (8 if center.x == 24 else (10 if center.z == -45 else 9))
		for side in [-1,1]:
			for dz in [-4.3,4.3]:
				A.place("tracery_bay",self,center+Vector3(side*(half_width-0.38),0.35,dz),Vector3.ONE,PI/2 if side < 0 else -PI/2)
			brazier(center+Vector3(side*(half_width-2.2),0,-5.2))
			for dz in [-5.8,5.8]:
				A.place("masonry_rubble",self,center+Vector3(side*(half_width-2.0),0,dz),Vector3.ONE,rng.randf_range(0,TAU))
		# Octagonal floor inlay marks the center without competing with the relic.
		for radius in [2.2,2.4]:
			G.ring(self,center+Vector3(0,0.025,0),radius,0.018,gold)
	for center in [Vector3(0,0,0),Vector3(46,0,0),Vector3(46,0,-46)]:
		var north_z: float = -11.5 if center == Vector3(46,0,0) else (-8.45 if center.x == 46 else -7.5)
		for side in [-1,1]:
			A.place("ritual_banner",self,center+Vector3(side*5.3,3.6,north_z),Vector3.ONE)
	# A chapel altar and votive graves use the same kit on a smaller scale.
	for x in [-7.0,7.0]:
		A.place("pilgrim_sarcophagus",self,Vector3(x,0,-48),Vector3.ONE*0.85)
