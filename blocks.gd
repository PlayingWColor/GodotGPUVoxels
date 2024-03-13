extends Node3D

@export var voxelGenPath : String
@export var genOffset : Vector3
@export var continuousGeneration : bool = false
@export var animationAction : String

# Called when the node enters the scene tree for the first time.
func _ready():
	
	var blockgen = get_child(0)
	
	blockgen.voxelGenPath = voxelGenPath
	blockgen.genOffset = genOffset
	blockgen.placeOffset = -get_position()
	blockgen.continuousGeneration = continuousGeneration
	blockgen.animationAction = animationAction
	
	blockgen._initprocesscompute()
