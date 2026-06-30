extends Node3D

@export var targeting_radius := 20.0
@export var click_range := 100.0

var current_target: Node3D = null
var nearby_candidates: Array[Node3D] = []
var tab_index := 0

signal target_changed(new_target: Node3D)

var detection_area: Area3D

func _ready() -> void:
	# Programmatically setup detection area if missing
	if not has_node("DetectionArea"):
		detection_area = Area3D.new()
		detection_area.name = "DetectionArea"
		add_child(detection_area)
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = targeting_radius
		shape.shape = sphere
		detection_area.add_child(shape)
	else:
		detection_area = get_node("DetectionArea")

	detection_area.body_entered.connect(_on_entity_entered)
	detection_area.body_exited.connect(_on_entity_exited)

func _on_entity_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") or body.is_in_group("npcs"):
		if not nearby_candidates.has(body):
			nearby_candidates.append(body)

func _on_entity_exited(body: Node3D) -> void:
	nearby_candidates.erase(body)
	if current_target == body:
		select_target(null)

func select_target(target: Node3D) -> void:
	if current_target == target:
		return
	
	if current_target and current_target.has_method("set_selection_ring"):
		current_target.set_selection_ring(false)
		
	current_target = target
	
	if current_target and current_target.has_method("set_selection_ring"):
		current_target.set_selection_ring(true)
		
	target_changed.emit(current_target)

func cycle_tab_target() -> void:
	var player_pos := global_position
	nearby_candidates.clear()
	
	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group("enemies") or body.is_in_group("npcs"):
			nearby_candidates.append(body)
			
	nearby_candidates.sort_custom(
		func(a, b): 
			return player_pos.distance_to(a.global_position) < player_pos.distance_to(b.global_position)
	)
	
	if nearby_candidates.is_empty():
		select_target(null)
		return
		
	tab_index = tab_index % nearby_candidates.size()
	select_target(nearby_candidates[tab_index])
	tab_index += 1

func handle_click_targeting(camera: Camera3D, screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * click_range
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)
	
	if result and result.collider.is_in_group("entities"):
		select_target(result.collider)
	else:
		select_target(null)
