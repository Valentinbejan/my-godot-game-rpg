extends RefCounted
const A = preload("res://demo/art.gd")
## Small shared mesh library; all geometry is authored in meters.

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func textured(path: String, color: Color) -> StandardMaterial3D:
	var m := material(color)
	m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.4
	return m

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat
	parent.add_child(n)
	n.position = pos
	return n

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid: bool = false) -> Node3D:
	var shape := BoxMesh.new()
	shape.size = size
	if not solid:
		return mesh(parent, shape, pos, mat)
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	mesh(body, shape, Vector3.ZERO, mat)
	var col := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	col.shape = b
	body.add_child(col)
	return body

static func cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, mat: Material, sides: int = 12) -> MeshInstance3D:
	var s := CylinderMesh.new()
	s.bottom_radius = bottom
	s.top_radius = top
	s.height = height
	s.radial_segments = sides
	return mesh(parent, s, pos, mat)

static func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	return mesh(parent, s, pos, mat)

static func ring(parent: Node3D, pos: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius - thickness
	t.outer_radius = radius + thickness
	t.rings = 48
	t.ring_segments = 6
	return mesh(parent, t, pos, mat)

static func light(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float, shadow: bool = false) -> OmniLight3D:
	var n := OmniLight3D.new()
	n.light_color = color
	n.light_energy = energy
	n.omni_range = radius
	n.omni_attenuation = 1.3
	n.shadow_enabled = shadow
	parent.add_child(n)
	n.position = pos
	return n

static func line(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var n := cylinder(parent, (a+b)*0.5, radius, radius, a.distance_to(b), mat, 6)
	var direction := (b-a).normalized()
	n.quaternion = Quaternion(Vector3.UP, direction)
	return n

static func pillar(parent: Node3D, pos: Vector3, height: float, _mat: Material, _trim: Material) -> void:
	A.place("fluted_column",parent,pos,Vector3(1,height/6.0,1))
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	var shaft := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.height = height
	shape.radius = 0.42
	shaft.shape = shape
	shaft.position.y = height*0.5
	body.add_child(shaft)
	var foot := CollisionShape3D.new()
	var base := BoxShape3D.new()
	base.size = Vector3(1.15,0.36,1.15)
	foot.shape = base
	foot.position.y = 0.18
	body.add_child(foot)

static func arch(parent: Node3D, pos: Vector3, width: float, spring: float, _mat: Material, rotated: bool = false) -> Node3D:
	return A.place("pointed_arch",parent,pos,Vector3(width/4.6,(spring+width*0.5)/5.05,1),PI/2.0 if rotated else 0.0)

static func robe(parent: Node3D, mat: Material, height: float = 1.45) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels := [Vector2(0.04,0.48),Vector2(0.62,0.34),Vector2(1.12,0.26),Vector2(1.42,0.4)]
	for row in range(3):
		for i in range(16):
			var verts: Array[Vector3] = []
			for pair in [[row,i],[row,(i+1)%16],[row+1,(i+1)%16],[row+1,i]]:
				var level: Vector2 = levels[pair[0]]
				var angle: float = TAU*pair[1]/16.0
				var fold: float = 1.0 if pair[1]%2==0 else 0.83
				var yy: float = level.x*height/1.45
				if pair[0]==0: yy += 0.06*sin(pair[1]*3.2)
				verts.append(Vector3(cos(angle)*level.y*fold,yy,sin(angle)*level.y*fold))
			for idx in [0,2,1,0,3,2]:
				tool.set_uv(Vector2(verts[idx].x*2,verts[idx].y))
				tool.add_vertex(verts[idx])
	tool.generate_normals()
	return mesh(parent,tool.commit(),Vector3.ZERO,mat)

static func hood(parent: Node3D, mat: Material, face: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-0.34,1.39,0.04),Vector3(-0.32,1.77,-0.1),Vector3(0,2.01,0.02),Vector3(0.32,1.77,-0.1),Vector3(0.34,1.39,0.04),Vector3(0,1.69,0.3)]
	for tri in [[0,1,5],[1,2,5],[2,3,5],[3,4,5],[0,5,4],[0,2,1],[2,4,3]]:
		for index in tri: tool.add_vertex(points[index])
	tool.generate_normals()
	mesh(parent,tool.commit(),Vector3.ZERO,mat)
	var mask := box(parent,Vector3(0,1.63,-0.09),Vector3(0.35,0.42,0.1),face)
	mask.rotation.z = 0
	line(parent,Vector3(-0.23,1.42,-0.14),Vector3(-0.24,1.75,-0.15),0.026,mat)
	line(parent,Vector3(-0.24,1.75,-0.15),Vector3(0,1.92,-0.12),0.026,mat)
	line(parent,Vector3(0,1.92,-0.12),Vector3(0.24,1.75,-0.15),0.026,mat)
	line(parent,Vector3(0.24,1.75,-0.15),Vector3(0.23,1.42,-0.14),0.026,mat)
