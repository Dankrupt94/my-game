extends CharacterBody3D

signal stats_changed(health: int, max_health: int, resolve: int, max_resolve: int)
signal action_feedback(message: String)
signal target_changed(target: Node3D)

const WALK_SPEED := 6.4
const JUMP_VELOCITY := 5.2
const MOUSE_SENSITIVITY := 0.0032
const BASIC_RANGE := 3.4
const FROST_RANGE := 16.0

var max_health := 120
var health := 120
var max_resolve := 100
var resolve := 100
var target

var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _camera_pivot: Node3D
var _camera: Camera3D
var _visual_root: Node3D
var _yaw := 0.0
var _pitch := -0.22
var _basic_cooldown := 0.0
var _frost_cooldown := 0.0
var _mend_cooldown := 0.0
var _resolve_regen_bank := 0.0

func _ready() -> void:
	_build_player_body()
	stats_changed.emit(health, max_health, resolve, max_resolve)

func _unhandled_input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENSITIVITY, -0.72, 0.32)
		_camera_pivot.rotation = Vector3(_pitch, _yaw, 0.0)

func _physics_process(delta: float) -> void:
	_tick_cooldowns(delta)
	_regenerate_resolve(delta)
	_move_player(delta)
	_camera.look_at(global_position + Vector3(0.0, 1.25, 0.0), Vector3.UP)

func set_target(new_target: Node3D) -> void:
	target = new_target
	target_changed.emit(target)

func use_hotbar_slot(slot: int) -> void:
	match slot:
		1:
			_basic_attack()
		2:
			_frost_spark()
		3:
			_mend()
		_:
			action_feedback.emit("That hotbar slot is empty.")

func _basic_attack() -> void:
	if _basic_cooldown > 0.0:
		action_feedback.emit("Training Strike is not ready yet.")
		return

	if not _has_valid_target(BASIC_RANGE):
		return

	_basic_cooldown = 1.0
	target.call("take_damage", 12, "Training Strike")
	action_feedback.emit("Training Strike hits the dummy for 12.")

func _frost_spark() -> void:
	if _frost_cooldown > 0.0:
		action_feedback.emit("Frost Spark is not ready yet.")
		return

	if resolve < 20:
		action_feedback.emit("Not enough resolve.")
		return

	if not _has_valid_target(FROST_RANGE):
		return

	_frost_cooldown = 3.0
	resolve -= 20
	stats_changed.emit(health, max_health, resolve, max_resolve)
	target.call("take_damage", 24, "Frost Spark")
	action_feedback.emit("Frost Spark cracks through the cold air for 24.")

func _mend() -> void:
	if _mend_cooldown > 0.0:
		action_feedback.emit("Mend is not ready yet.")
		return

	if resolve < 15:
		action_feedback.emit("Not enough resolve.")
		return

	_mend_cooldown = 6.0
	resolve -= 15
	health = min(max_health, health + 28)
	stats_changed.emit(health, max_health, resolve, max_resolve)
	action_feedback.emit("Mend restores your health.")

func _has_valid_target(required_range: float) -> bool:
	if target == null or not is_instance_valid(target):
		action_feedback.emit("No target selected. Press Tab.")
		return false

	if not target.has_method("take_damage"):
		action_feedback.emit("That target cannot be attacked.")
		return false

	var distance := global_position.distance_to(target.global_position)
	if distance > required_range:
		action_feedback.emit("Move closer to your target.")
		return false

	return true

func _tick_cooldowns(delta: float) -> void:
	_basic_cooldown = maxf(0.0, _basic_cooldown - delta)
	_frost_cooldown = maxf(0.0, _frost_cooldown - delta)
	_mend_cooldown = maxf(0.0, _mend_cooldown - delta)

func _regenerate_resolve(delta: float) -> void:
	if resolve >= max_resolve:
		return

	_resolve_regen_bank += 12.0 * delta
	if _resolve_regen_bank < 1.0:
		return

	var recovered := int(_resolve_regen_bank)
	_resolve_regen_bank -= float(recovered)
	resolve = mini(max_resolve, resolve + recovered)
	stats_changed.emit(health, max_health, resolve, max_resolve)

func _move_player(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := _camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := right * input_vector.x + forward * -input_vector.y
	if direction.length() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * WALK_SPEED
		velocity.z = direction.z * WALK_SPEED
		_visual_root.look_at(global_position + direction, Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * 5.0)

	move_and_slide()

func _build_player_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.35
	capsule_shape.height = 1.65
	collision.shape = capsule_shape
	collision.position.y = 0.82
	add_child(collision)

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.65
	body.mesh = body_mesh
	body.material_override = _material(Color(0.16, 0.28, 0.46), 0.58, 0.2)
	body.position.y = 0.85
	_visual_root.add_child(body)

	var scarf := MeshInstance3D.new()
	var scarf_mesh := BoxMesh.new()
	scarf_mesh.size = Vector3(0.78, 0.16, 0.12)
	scarf.mesh = scarf_mesh
	scarf.material_override = _material(Color(0.72, 0.16, 0.14), 0.7, 0.0)
	scarf.position = Vector3(0.0, 1.43, -0.26)
	_visual_root.add_child(scarf)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 0.9, 0.12)
	blade.mesh = blade_mesh
	blade.material_override = _material(Color(0.7, 0.82, 0.9), 0.32, 0.55)
	blade.position = Vector3(0.45, 0.92, 0.0)
	blade.rotation_degrees.z = -12.0
	_visual_root.add_child(blade)

	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.35, 0.0)
	_camera_pivot.rotation = Vector3(_pitch, _yaw, 0.0)
	add_child(_camera_pivot)

	_camera = Camera3D.new()
	_camera.name = "ThirdPersonCamera"
	_camera.position = Vector3(0.0, 1.15, 6.2)
	_camera.current = true
	_camera.fov = 67.0
	_camera_pivot.add_child(_camera)

func _material(albedo: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	return material
