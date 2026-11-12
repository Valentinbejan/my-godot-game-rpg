@tool
extends Node3D
## Makes the local texture palette visible when a reusable kit scene is dragged
## into the editor. Gameplay uses the same material resolver in demo/art.gd.
const ART = preload("res://demo/art.gd")

func _ready() -> void:
	ART.apply_materials(self)
