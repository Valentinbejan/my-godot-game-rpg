extends RefCounted
## Reusable Blender meshes and shared materials sourced from the local library.
const MODEL_ROOT := "res://assets/models/cloister_kit/"
const TEXTURE_ROOT := "res://assets/textures/pack2/256x256/"
const PALETTE := {
	"ashlar": ["Brick/Brick_10-256x256.png", Color("bbc8cd"), 0.0, 0.9],
	"stone": ["Stone/Stone_12-256x256.png", Color("b3bdc0"), 0.0, 0.86],
	"carving": ["Stone/Stone_03-256x256.png", Color("879e9e"), 0.0, 0.80],
	"paving": ["Stone/Stone_06-256x256.png", Color("a5b2b1"), 0.0, 0.86],
	"mosaic": ["Tile/Tile_04-256x256.png", Color("8da5a4"), 0.0, 0.70],
	"bronze": ["Metal/Metal_11-256x256.png", Color("bf9559"), 0.68, 0.43],
	"patina": ["Metal/Metal_03-256x256.png", Color("719e89"), 0.48, 0.65],
	"steel": ["Metal/Metal_09-256x256.png", Color("c2d1d7"), 0.58, 0.38],
	"wood": ["Wood/Wood_11-256x256.png", Color("72513a"), 0.0, 0.9],
	"cloth": ["Plaster/Plaster_02-256x256.png", Color("28464d"), 0.0, 0.96],
	"ivory": ["Plaster/Plaster_09-256x256.png", Color("bfb79b"), 0.0, 0.84],
	"shadow": ["", Color("070e12"), 0.0, 1.0],
	"glass": ["", Color("376771"), 0.35, 0.25],
	"lumen": ["", Color("8de0cc"), 0.0, 0.4],
	"ember": ["", Color("ffbf72"), 0.0, 0.6]
}
static var materials: Dictionary = {}
static var scenes: Dictionary = {}

static func material(key: String) -> StandardMaterial3D:
	if materials.has(key): return materials[key]
	var spec: Array = PALETTE[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "cloister_"+key
	mat.albedo_color = spec[1]
	mat.metallic = spec[2]
	mat.roughness = spec[3]
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if spec[0] != "":
		mat.albedo_texture = load(TEXTURE_ROOT+spec[0])
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if key in ["lumen", "ember", "glass"]:
		mat.emission_enabled = true
		mat.emission = spec[1]
		mat.emission_energy_multiplier = 1.8 if key == "lumen" else (3.0 if key == "ember" else 0.14)
	materials[key] = mat
	return mat

static func apply_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var source: Material = node.mesh.surface_get_material(surface)
			if source != null:
				var key := source.resource_name.trim_prefix("cloister_")
				if PALETTE.has(key): node.set_surface_override_material(surface,material(key))
	for child in node.get_children(): apply_materials(child)

static func place(asset: String, parent: Node3D, pos: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ONE, yaw: float = 0.0) -> Node3D:
	if not scenes.has(asset): scenes[asset] = load(MODEL_ROOT+asset+".glb")
	var model: Node3D = scenes[asset].instantiate()
	model.name = asset
	model.set_meta("art_asset",asset)
	apply_materials(model)
	parent.add_child(model)
	model.position = pos
	model.scale = size
	model.rotation.y = yaw
	return model

static func part(root: Node, prefix: String) -> Node3D:
	for child in root.get_children():
		if child is Node3D and String(child.name).begins_with(prefix): return child
		var found := part(child,prefix)
		if found != null: return found
	return null
