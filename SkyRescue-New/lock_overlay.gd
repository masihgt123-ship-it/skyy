extends Control
var battle: Node
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_dt: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(battle) or battle.finished:
		return
	var target: Node3D = battle.aim_target(0.85)
	var camera := get_viewport().get_camera_3d()
	if target == null or camera == null or camera.is_position_behind(target.global_position):
		return
	var p := camera.unproject_position(target.global_position)
	var color := Color(1,0.2,0.12,0.95)
	for x in [-1,1]:
		for y in [-1,1]:
			var corner := p+Vector2(x*30,y*30)
			draw_line(corner,corner-Vector2(x*14,0),color,2.5,true)
			draw_line(corner,corner-Vector2(0,y*14),color,2.5,true)
	draw_circle(p,3,color)
	var distance := int(battle.g.heli.global_position.distance_to(target.global_position))
	draw_string(ThemeDB.fallback_font,p+Vector2(-24,49),"%d m" % distance,HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
