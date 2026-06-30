extends Node3D

var label: Label3D

func _ready() -> void:
	if not has_node("Label3D"):
		label = Label3D.new()
		label.name = "Label3D"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		add_child(label)
	else:
		label = get_node("Label3D")

func setup(amount: String, color: Color) -> void:
	# Ensure label is loaded
	if not label:
		_ready()
	label.text = amount
	label.modulate = color
	
	var tween := create_tween().set_parallel(true)
	
	# Float upward
	tween.tween_property(self, "position:y", position.y + 1.8, 1.0)\
		.set_trans(Tween.TRANS_OUT)\
		.set_ease(Tween.EASE_QUAD)
		
	# Scale size down slightly toward end
	tween.tween_property(label, "font_size", int(label.font_size * 0.7), 1.0)
	
	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	
	# Cleanup on completion
	tween.chain().tween_callback(queue_free)
