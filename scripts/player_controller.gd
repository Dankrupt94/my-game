extends CharacterBody3D

@export var speed := 7.0
@export var jump_velocity := 4.5
@export var rotation_speed := 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera_pivot: Node3D = $CameraPivot
@onready var state_machine: Node = $StateMachine

func _ready() -> void:
	if has_node("StateMachine"):
		state_machine.init(self)

func _physics_process(delta: float) -> void:
	# Add gravity if in the air.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction relative to the Camera's orientation
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	var cam_forward := -camera_pivot.global_basis.z
	var cam_right := camera_pivot.global_basis.x
	
	cam_forward.y = 0.0
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	
	var direction := (cam_right * input_dir.x + cam_forward * input_dir.y).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		var target_rotation := atan2(-direction.x, -direction.z)
		rotation.y = rotate_toward(rotation.y, target_rotation, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)

	move_and_slide()
