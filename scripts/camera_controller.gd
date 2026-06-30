extends SpringArm3D

@export var mouse_sensitivity := 0.15
@export var min_pitch := -50.0
@export var max_pitch := 30.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_excluded_object(get_parent().get_rid())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		
		rotation_degrees.x = clamp(
			rotation_degrees.x - event.relative.y * mouse_sensitivity, 
			min_pitch, 
			max_pitch
		)

	if event.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
