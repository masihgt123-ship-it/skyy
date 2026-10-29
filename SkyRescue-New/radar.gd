extends Control

var game: Node3D

func _process(_delta: float) -> void:
	queue_redraw()

func dot_at(world: Vector3, color: Color, radius: float = 4.0) -> void:
	var offset := Vector2(world.x-game.heli.position.x,world.z-game.heli.position.z)*0.14
	if offset.length() > 72:
		offset = offset.normalized()*72
	draw_circle(Vector2(90,90)+offset,radius,color)

func _draw() -> void:
	if game == null or game.heli == null:
		return
	var center := Vector2(90,90)
	draw_circle(center,84,Color(0.02,0.07,0.09,0.85))
	for radius in [28,56,82]:
		draw_arc(center,radius,0,TAU,64,Color(0.35,0.7,0.7,0.35),1,true)
	draw_line(Vector2(8,90),Vector2(172,90),Color(0.3,0.7,0.7,0.25))
	draw_line(Vector2(90,8),Vector2(90,172),Color(0.3,0.7,0.7,0.25))
	draw_string(preload("res://fonts/DejaVuSans.ttf"),Vector2(85,19),"ش",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
	dot_at(game.base,Color("48e3df"),5)
	if game.mode == 1:
		for t in game.targets:
			if t.hp > 0:
				dot_at(t.node.position,Color("ff6e61"))
	if game.mode == 2 and not game.onboard and game.rescued < 3:
		dot_at(game.rescue_sites[game.rescued],Color("ffcc72"),6)
	var points := PackedVector2Array()
	for p in [Vector2(0,-9),Vector2(-5,6),Vector2(0,3),Vector2(5,6)]:
		points.append(center+p.rotated(-game.heli.rotation.y))
	draw_colored_polygon(points,Color.WHITE)
	draw_string(preload("res://fonts/DejaVuSans.ttf"),Vector2(39,190),"رادار / ۵۷۰ متر",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("acd9d8"))
