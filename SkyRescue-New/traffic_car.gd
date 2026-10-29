extends Node3D

# Shared rounded street circuits, sampled by distance for constant speed.
var route: Curve3D
var distance: float = 0.0
var direction: float = 1.0
var speed: float = 11.0

func configure(path: Curve3D, start: float, travel_direction: float) -> void:
	route = path
	distance = start
	direction = travel_direction
	update_pose()

func _process(delta: float) -> void:
	if route == null:
		return
	distance = fposmod(distance + speed * direction * delta, route.get_baked_length())
	update_pose()

func update_pose() -> void:
	var length: float = route.get_baked_length()
	position = route.sample_baked(fposmod(distance, length))
	var ahead: Vector3 = route.sample_baked(fposmod(distance + direction * 0.5, length))
	look_at_from_position(position, ahead, Vector3.UP)

static func street_loop(inset: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.4
	var left: float = -185.0 + inset
	var right: float = 185.0 - inset
	var top: float = -115.0 + inset
	var bottom: float = 165.0 - inset
	var radius: float = 7.0
	var centers: Array[Vector2] = [Vector2(right-radius, top+radius), Vector2(right-radius, bottom-radius), Vector2(left+radius, bottom-radius), Vector2(left+radius, top+radius)]
	for corner in range(4):
		for step in range(13):
			var angle: float = -PI/2.0 + corner*PI/2.0 + step*PI/24.0
			var point: Vector2 = centers[corner] + Vector2(cos(angle), sin(angle))*radius
			curve.add_point(Vector3(point.x, 2.6, point.y))
	curve.add_point(curve.get_point_position(0))
	return curve
