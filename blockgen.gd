extends MeshInstance3D

@export var collisionShape : CollisionShape3D
@export var voxelGenPath : String
@export var genOffset : Vector3
@export var placeOffset : Vector3
@export var autoGenerate : bool = true
@export var continuousGeneration : bool = false
@export var animationAction : String

const BLOCKSWIDTH = 8
const TOTALBYTECOUNT = 294912#6 verts * 6 sides * 8 * 8 * 8 blocks * 16 bytes
const VERTCOUNT = 24576#6 verts * 6 sides * 8 * 8 * 8 blocks

var image3D_bytes
var image_format

var render_device_blocks
var render_device_mesh
var vert_bytes : PackedByteArray
var uv_bytes : PackedByteArray
var normal_bytes : PackedByteArray
var indice_bytes : PackedByteArray

var vert_buffer
var normal_buffer
var uv_buffer
var indice_buffer

var gpu_texture
var other_gpu_texture

var block_pipeline
var block_uniform_set

var mesh_pipeline
var mesh_uniform_set

var time_buffer

# Called when the node enters the scene tree for the first time.
func _ready():
	if autoGenerate:
		_initprocesscompute()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _setvalueatpos(point : Vector3, value : int):
	
	var offsetpoint = Vector3(point.x + placeOffset.x, point.y + placeOffset.y, point.z + placeOffset.z)
	
	if(value > 255 || value < 0 || offsetpoint.x < 0 || offsetpoint.y < 0  || offsetpoint.z < 0):
		print("failed")
		return

	var byte_offset = int(round(offsetpoint.x)) + int(round(offsetpoint.y)) * BLOCKSWIDTH + int(round(offsetpoint.z)) * BLOCKSWIDTH * BLOCKSWIDTH
	
	image3D_bytes.encode_u8(byte_offset, value)
	
	
	#_printpackedbytesas8bitint(image3D_bytes)
	render_device_mesh.texture_update(other_gpu_texture, 0, image3D_bytes)
	
	var compute_list = render_device_mesh.compute_list_begin()
	render_device_mesh.compute_list_bind_compute_pipeline(compute_list, mesh_pipeline)
	render_device_mesh.compute_list_bind_uniform_set(compute_list, mesh_uniform_set, 0)
	render_device_mesh.compute_list_dispatch(compute_list, 1, 1, 1)
	render_device_mesh.compute_list_end()
	
	render_device_mesh.submit()
	await get_tree().process_frame
	render_device_mesh.sync()
	#await get_tree().process_frame
	
	vert_bytes = render_device_mesh.buffer_get_data(vert_buffer)
	uv_bytes = render_device_mesh.buffer_get_data(uv_buffer)
	normal_bytes = render_device_mesh.buffer_get_data(normal_buffer)
	indice_bytes = render_device_mesh.buffer_get_data(indice_buffer)

	_convertmesh()
	
func _initblockscompute():
	
	render_device_blocks = RenderingServer.create_local_rendering_device()
	
	var shader_file_blocks := load(voxelGenPath)
	var shader_spirv_blocks: RDShaderSPIRV = shader_file_blocks.get_spirv()
	var shader_blocks = render_device_blocks.shader_create_from_spirv(shader_spirv_blocks)
	
	
	var baseImage = Image.create(BLOCKSWIDTH,BLOCKSWIDTH,false,Image.FORMAT_R8)
	image3D_bytes = PackedByteArray()
	for i in range(BLOCKSWIDTH):
		image3D_bytes.append_array(baseImage.get_data())
	#var image3D = ImageTexture3D.new()
	#image3D.create(Image.FORMAT_R8, BLOCKSWIDTH, BLOCKSWIDTH, BLOCKSWIDTH, false, array)
	
	image_format = RDTextureFormat.new()
	image_format.width = BLOCKSWIDTH;
	image_format.height = BLOCKSWIDTH;
	image_format.depth = BLOCKSWIDTH;
	image_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT  | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_INPUT_ATTACHMENT_BIT 
	image_format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	image_format.texture_type = RenderingDevice.TEXTURE_TYPE_3D
	
	gpu_texture = render_device_blocks.texture_create(image_format, RDTextureView.new(), [image3D_bytes])
	
	var uniform_img = RDUniform.new()
	uniform_img.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_img.binding = 0 # this needs to match the "binding" in our shader file
	uniform_img.add_id(gpu_texture)
	
	var offset_array = PackedVector3Array()
	offset_array.resize(1)
	offset_array[0] = genOffset
	var offset_bytes = offset_array.to_byte_array()
	var offset_buffer = render_device_blocks.storage_buffer_create(offset_bytes.size(), offset_bytes)
	
	var offset_uniform := RDUniform.new()
	offset_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	offset_uniform.binding = 1 # this needs to match the "binding" in our shader file
	offset_uniform.add_id(offset_buffer)
	
	var time_array = PackedFloat32Array()
	time_array.resize(1)
	time_array[0] = Time.get_ticks_msec()/1000.0
	var time_bytes = time_array.to_byte_array()

	time_buffer = render_device_blocks.storage_buffer_create(time_bytes.size(), time_bytes)
	
	var time_uniform := RDUniform.new()
	time_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	time_uniform.binding = 2 # this needs to match the "binding" in our shader file
	time_uniform.add_id(time_buffer)
	
	block_uniform_set = render_device_blocks.uniform_set_create([uniform_img, offset_uniform, time_uniform], shader_blocks, 0)
	
	
	# Create a compute pipeline
	block_pipeline = render_device_blocks.compute_pipeline_create(shader_blocks)
	var compute_list = render_device_blocks.compute_list_begin()
	render_device_blocks.compute_list_bind_compute_pipeline(compute_list, block_pipeline)
	render_device_blocks.compute_list_bind_uniform_set(compute_list, block_uniform_set, 0)
	render_device_blocks.compute_list_dispatch(compute_list, 1, 1, 1)
	render_device_blocks.compute_list_end()
	
func _initmeshcompute():
	
	render_device_mesh = RenderingServer.create_local_rendering_device()
	
	var shader_file_mesh := load("res://compute_mesh.glsl")
	var shader_spirv_mesh: RDShaderSPIRV = shader_file_mesh.get_spirv()
	var shader_mesh = render_device_mesh.shader_create_from_spirv(shader_spirv_mesh)
	

	var verts = PackedVector3Array()
	verts.resize(VERTCOUNT)
	vert_bytes = verts.to_byte_array()
	vert_buffer = render_device_mesh.storage_buffer_create(vert_bytes.size(), vert_bytes)
	
	var normals = PackedVector3Array()
	normals.resize(VERTCOUNT)
	normal_bytes = normals.to_byte_array()
	normal_buffer = render_device_mesh.storage_buffer_create(normal_bytes.size(), normal_bytes)
	
	var uvs = PackedVector2Array()
	uvs.resize(VERTCOUNT)
	uv_bytes = uvs.to_byte_array()
	uv_buffer = render_device_mesh.storage_buffer_create(uv_bytes.size(), uv_bytes)
	
	var indices = PackedInt32Array()
	indices.resize(VERTCOUNT)
	indice_bytes = indices.to_byte_array()
	indice_buffer = render_device_mesh.storage_buffer_create(indice_bytes.size(), indice_bytes)
	
	other_gpu_texture = render_device_mesh.texture_create(image_format, RDTextureView.new(), [image3D_bytes])
	
	var uniform_img = RDUniform.new()
	uniform_img.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_img.binding = 0 # this needs to match the "binding" in our shader file
	uniform_img.add_id(other_gpu_texture)
	
	var vert_uniform := RDUniform.new()
	vert_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	vert_uniform.binding = 1 # this needs to match the "binding" in our shader file
	vert_uniform.add_id(vert_buffer)
	
	var normal_uniform := RDUniform.new()
	normal_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	normal_uniform.binding = 2 # this needs to match the "binding" in our shader file
	normal_uniform.add_id(normal_buffer)
	
	var uv_uniform := RDUniform.new()
	uv_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uv_uniform.binding = 3 # this needs to match the "binding" in our shader file
	uv_uniform.add_id(uv_buffer)
	
	var indice_uniform := RDUniform.new()
	indice_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	indice_uniform.binding = 4 # this needs to match the "binding" in our shader file
	indice_uniform.add_id(indice_buffer)
	
	mesh_uniform_set = render_device_mesh.uniform_set_create([uniform_img, vert_uniform, normal_uniform, uv_uniform, indice_uniform], shader_mesh, 0)
	
	# Create a compute pipeline
	mesh_pipeline = render_device_mesh.compute_pipeline_create(shader_mesh)
	var compute_list = render_device_mesh.compute_list_begin()
	render_device_mesh.compute_list_bind_compute_pipeline(compute_list, mesh_pipeline)
	render_device_mesh.compute_list_bind_uniform_set(compute_list, mesh_uniform_set, 0)
	render_device_mesh.compute_list_dispatch(compute_list, 1, 1, 1)
	render_device_mesh.compute_list_end()

func _initprocesscompute():

	_initblockscompute()
	
	render_device_blocks.submit()
	await get_tree().process_frame
	render_device_blocks.sync()
	#await get_tree().process_frame

	image3D_bytes = render_device_blocks.texture_get_data(gpu_texture, 0)
	_initmeshcompute()
	
	render_device_mesh.submit()
	await get_tree().process_frame
	render_device_mesh.sync()
	#await get_tree().process_frame
	
	vert_bytes = render_device_mesh.buffer_get_data(vert_buffer)
	uv_bytes = render_device_mesh.buffer_get_data(uv_buffer)
	normal_bytes = render_device_mesh.buffer_get_data(normal_buffer)
	indice_bytes = render_device_mesh.buffer_get_data(indice_buffer)
	
	_convertmesh()
	
	await get_tree().process_frame
	
	if continuousGeneration:
		_loopprocesscompute()

func _loopprocesscompute():
	
	while true:
		
		var time_array = PackedFloat32Array()
		time_array.resize(1)
		time_array[0] = Time.get_ticks_msec()/1000.0
		var time_bytes = time_array.to_byte_array()
		
		render_device_blocks.buffer_update(time_buffer, 0, time_bytes.size(), time_bytes)
		
		var compute_list_blocks = render_device_blocks.compute_list_begin()
		render_device_blocks.compute_list_bind_compute_pipeline(compute_list_blocks, block_pipeline)
		render_device_blocks.compute_list_bind_uniform_set(compute_list_blocks, block_uniform_set, 0)
		render_device_blocks.compute_list_dispatch(compute_list_blocks, 1, 1, 1)
		render_device_blocks.compute_list_end()
		
		render_device_blocks.submit()
		await get_tree().process_frame
		render_device_blocks.sync()
		
		image3D_bytes = render_device_blocks.texture_get_data(gpu_texture, 0)
		
		render_device_mesh.texture_update(other_gpu_texture, 0, image3D_bytes)
		
		var compute_list = render_device_mesh.compute_list_begin()
		render_device_mesh.compute_list_bind_compute_pipeline(compute_list, mesh_pipeline)
		render_device_mesh.compute_list_bind_uniform_set(compute_list, mesh_uniform_set, 0)
		render_device_mesh.compute_list_dispatch(compute_list, 1, 1, 1)
		render_device_mesh.compute_list_end()
		
		render_device_mesh.submit()
		await get_tree().process_frame
		render_device_mesh.sync()
		#await get_tree().process_frame
		
		vert_bytes = render_device_mesh.buffer_get_data(vert_buffer)
		uv_bytes = render_device_mesh.buffer_get_data(uv_buffer)
		normal_bytes = render_device_mesh.buffer_get_data(normal_buffer)
		indice_bytes = render_device_mesh.buffer_get_data(indice_buffer)

		_convertmesh()
		
		while !Input.is_action_pressed(animationAction):
			await get_tree().process_frame
		await get_tree().process_frame

func _convertmesh():
	
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)

	# PackedVector**Arrays for mesh construction.
	var verts = _packedbytestovec3(vert_bytes)
	#var uvs = _packedbytestovec2(uv_bytes)
	var normals = _packedbytestovec3(normal_bytes)
	#var indices = _packedbytestoint(indice_bytes)
	#print(verts)

	
	# Assign arrays to surface array.
	surface_array[Mesh.ARRAY_VERTEX] = verts
	#surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_NORMAL] = normals
	#surface_array[Mesh.ARRAY_INDEX] = indices
	
	# Create mesh surface from mesh array.
	# No blendshapes, lods, or compression used.
	mesh.clear_surfaces ( )
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	
	collisionShape.shape.set_faces(verts)

func _convertmeshineigths():
	
	mesh.clear_surfaces()
	
	for i in 8:
		_convertmesheighth(i)

	var verts = _packedbytestovec3(vert_bytes)
	
	collisionShape.shape.set_faces(verts)

func _convertmesheighth(eighth : int):
	
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)

	# PackedVector**Arrays for mesh construction.
	var verts = _packedbytestovec3eighth(vert_bytes, eighth)
	#var uvs = _packedbytestovec2(uv_bytes)
	var normals = _packedbytestovec3eighth(normal_bytes, eighth)
	#var indices = _packedbytestoint(indice_bytes)
	#print(verts)

	
	# Assign arrays to surface array.
	surface_array[Mesh.ARRAY_VERTEX] = verts
	#surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_NORMAL] = normals
	#surface_array[Mesh.ARRAY_INDEX] = indices
	
	# Create mesh surface from mesh array.
	# No blendshapes, lods, or compression used.
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)

func _packedbytestovec3(packed_byte_array: PackedByteArray) -> PackedVector3Array:
	var packed_vector3_array := PackedVector3Array()

	var byte_index := 0
	while byte_index < packed_byte_array.size():
		var x := packed_byte_array.decode_float(byte_index)
		var y := packed_byte_array.decode_float(byte_index + 4)
		var z := packed_byte_array.decode_float(byte_index + 8)

		var vector3 := Vector3(x, y, z)
		packed_vector3_array.append(vector3)

		byte_index += 16

	return packed_vector3_array

func _packedbytestovec3eighth(packed_byte_array: PackedByteArray, eighth : int) -> PackedVector3Array:
	var packed_vector3_array := PackedVector3Array()
	
	var eighthSize := packed_byte_array.size() / 8
	
	var byte_index := eighthSize * eighth
	while byte_index < eighthSize * (eighth + 1):
		var x := packed_byte_array.decode_float(byte_index)
		var y := packed_byte_array.decode_float(byte_index + 4)
		var z := packed_byte_array.decode_float(byte_index + 8)

		var vector3 := Vector3(x, y, z)
		packed_vector3_array.append(vector3)

		byte_index += 16

	return packed_vector3_array


func _packedbytestovec3flipped(packed_byte_array: PackedByteArray) -> PackedVector3Array:
	var packed_vector3_array := PackedVector3Array()

	var byte_index := packed_byte_array.size()
	while byte_index >= 16:
		var x := packed_byte_array.decode_float(byte_index - 8)
		var y := packed_byte_array.decode_float(byte_index - 12)
		var z := packed_byte_array.decode_float(byte_index - 16)

		var vector3 := Vector3(x, y, z)
		packed_vector3_array.append(vector3)

		byte_index -= 16

	return packed_vector3_array
	

func _packedbytestovec2(packed_byte_array: PackedByteArray) -> PackedVector2Array:
	var packed_vector2_array := PackedVector2Array()

	var byte_index := 0
	while byte_index < packed_byte_array.size():
		var x := packed_byte_array.decode_float(byte_index)
		var y := packed_byte_array.decode_float(byte_index + 4)

		var vector3 := Vector2(x, y)
		packed_vector2_array.append(vector3)

		byte_index += 8

	return packed_vector2_array
	
func _packedbytestoint(packed_byte_array: PackedByteArray) -> PackedInt32Array:
	var packed_int_array := PackedInt32Array()

	var byte_index := 0
	while byte_index < packed_byte_array.size():
		var x := packed_byte_array.decode_s32(byte_index)
		packed_int_array.append(x)
		byte_index += 4

	return packed_int_array

func _printpackedbytesas8bitint(packed_byte_array: PackedByteArray):
	var byte_index := 0
	while byte_index < packed_byte_array.size():
		print(packed_byte_array.decode_u8(byte_index))
		byte_index += 1

func _printpackedbytesasfloat(packed_byte_array: PackedByteArray):
	var byte_index := 0
	while byte_index < packed_byte_array.size():
		print(packed_byte_array.decode_float(byte_index))
		byte_index += 1
