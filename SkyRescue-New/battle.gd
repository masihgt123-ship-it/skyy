extends Node

var g: Node3D
var wave := 1
var total := 5
var delay := -1.0
var missile_cd := 0.0
var shots: Array = []
var rockets: AudioStreamPlayer
var display: Label
var tank_mat: Material
var steel: Material
var finished := false
var difficulty: float = 0.0
var effects: Node3D

func _ready() -> void:
	g = get_parent()
	tank_mat = g.material(Color("59634a"), 0.45)
	steel = g.material(Color("435565"), 0.65, 0.3)
	rockets = AudioStreamPlayer.new()
	rockets.stream = preload("res://audio/rlaunch.wav")
	rockets.volume_db = -9
	add_child(rockets)
	var layer := CanvasLayer.new()
	add_child(layer)
	display = Label.new()
	display.position = Vector2(540, 25)
	display.add_theme_font_size_override("font_size", 23)
	display.add_theme_color_override("font_shadow_color", Color.BLACK)
	display.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(display)
	var overlay := Control.new()
	overlay.set_script(preload("res://lock_overlay.gd"))
	overlay.battle = self
	layer.add_child(overlay)
	effects = Node3D.new()
	effects.set_script(preload("res://combat_effects.gd"))
	add_child(effects)
	g.button(layer_control(layer), "موشک", Vector2(975,435), Vector2(155,96), "missile")
	# Extra player armor, stub wings and missile pods; original flight components stay intact.
	for side in [-1, 1]:
		g.box(g.model, Vector3(side*2.2,-0.4,0.6), Vector3(2.2,0.18,1.3), steel)
		for z in [-0.1, 0.6]:
			g.tube(g.model, Vector3(side*2.8,-0.7,z-1), Vector3(side*2.8,-0.7,z+1), 0.22, g.materials.black)
		g.box(g.model, Vector3(side*1.58,-0.6,0.5), Vector3(0.12,0.65,2.2), steel)
	restart()

func layer_control(layer: CanvasLayer) -> Control:
	var ui := Control.new()
	ui.layout_direction = Control.LAYOUT_DIRECTION_LTR
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	return ui

func clear_units() -> void:
	if is_instance_valid(effects):
		effects.clear()
	for t in g.targets:
		t.node.queue_free()
		t.tag.queue_free()
	g.targets.clear()
	for b in shots:
		b.node.queue_free()
	shots.clear()

func restart() -> void:
	clear_units()
	wave = 1
	finished = false
	delay = -1
	missile_cd = 0
	spawn_wave()

func spawn_wave() -> void:
	clear_units()
	difficulty = float(maxi(0, wave-2))
	total = wave*5
	g.hits = 0
	for i in range(total):
		var kind: int = i % mini(4, 1 + (wave-1)/2)
		# First wave mixes tanks and helicopters; jets arrive later.
		if wave == 1:
			kind = i % 2
		var angle := TAU*float(i)/float(total)
		var radius := 260.0 + float(i%3)*35.0
		var p := Vector3(cos(angle)*radius, 0, sin(angle)*radius)
		p.y = g.ground(p.x,p.z) + (2.0 if kind == 0 or kind == 2 else 48.0 + float(i%4)*12.0)
		var unit := Node3D.new()
		g.add_child(unit)
		unit.position = p
		var spin := Node3D.new()
		unit.add_child(spin)
		if kind == 0 or kind == 2:
			g.box(unit, Vector3.ZERO, Vector3(4.6,1.6,7), tank_mat)
			for side in [-1,1]:
				g.box(unit,Vector3(side*2.6,-0.5,0),Vector3(1.1,1.7,7.8),g.materials.black)
				for z in [-2.5,-1.25,0,1.25,2.5]:
					g.ellipsoid(unit,Vector3(side*3.16,-0.6,z),Vector3(0.12,0.57,0.57),steel)
			spin.position.y = 1.3
			g.box(spin,Vector3.ZERO,Vector3(2.8,1.4,3.2),tank_mat)
			for side in ([-1,1] if kind == 2 else [0]):
				g.tube(spin,Vector3(side*0.65,0.4,-0.5),Vector3(side*0.65,1.0,-6),0.17,steel)
		else:
			g.ellipsoid(unit,Vector3.ZERO,Vector3(1.9,1.5,4.2),steel)
			g.ellipsoid(unit,Vector3(0,0.4,-2.6),Vector3(1.5,1.0,1.7),g.materials.glass)
			g.box(unit,Vector3(0,0.2,2),Vector3(10,0.18,1.4),tank_mat)
			g.tube(unit,Vector3(0,0,2),Vector3(0,0.7,9),0.7,steel,0.15)
			g.box(unit,Vector3(0,1.5,8),Vector3(0.2,2.6,1.6),tank_mat)
			if kind == 1:
				spin.position.y = 2.3
				g.box(spin,Vector3.ZERO,Vector3(14,0.1,0.35),g.materials.black)
				g.box(spin,Vector3.ZERO,Vector3(0.35,0.1,14),g.materials.black)
			else:
				g.box(unit,Vector3(0,0,1),Vector3(17,0.2,2.8),steel)
		var tag: Label3D = g.label3d(["تانک","هلیکوپتر","ضدهوایی","جنگنده"][kind],p+Vector3.UP*9,Color("ff8970"))
		g.targets.append({"node":unit,"tag":tag,"hp":3+wave/5+int(difficulty/3),"cooldown":g.rng.randf_range(2,7),"kind":kind,"spin":spin,"phase":angle})
	g.tell("موج %d از ۲۰ — %d دشمن" % [wave,total],5)

func emit_shot(p: Vector3, direction: Vector3, enemy: bool, missile := false) -> void:
	var node: Node3D = g.ellipsoid(g,p,Vector3(0.18,0.18,1.3) if missile else Vector3.ONE*0.24,g.materials.trim if not enemy else g.materials.red)
	if missile:
		g.box(node,Vector3(0,0,0.8),Vector3(1.2,0.12,0.5),steel)
		g.ellipsoid(node,Vector3(0,0,1.6),Vector3(0.18,0.18,0.7),g.materials.red)
	shots.append({"node":node,"velocity":direction*(130 if missile else (95+wave*2+difficulty*2 if enemy else 230)),"life":5.0,"enemy":enemy,"missile":missile})
	if not enemy and g.sound_enabled:
		if missile:
			rockets.play()
		else:
			g.combat_audio.fire()

func aim_target(cone: float) -> Node3D:
	var best: Node3D = null
	var forward := Vector3(-g.heli.basis.z.x,0,-g.heli.basis.z.z).normalized()
	for t in g.targets:
		var offset: Vector3 = t.node.position-g.heli.position
		if t.hp <= 0 or offset.length() > 500:
			continue
		var alignment: float = forward.dot(Vector3(offset.x,0,offset.z).normalized())
		if alignment > cone:
			var ray := PhysicsRayQueryParameters3D.create(g.heli.position-g.heli.basis.z*4,t.node.position)
			ray.exclude = [g.heli.get_rid()]
			if not g.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				continue
			cone = alignment
			best = t.node
	return best

func tick(dt: float) -> void:
	missile_cd = maxf(0,missile_cd-dt)
	var alive := 0
	for t in g.targets:
		if t.hp <= 0:
			continue
		alive += 1
		var n: Node3D = t.node
		var offset: Vector3 = g.heli.position-n.position
		var flat := Vector3(offset.x,0,offset.z)
		if flat.length() > 0.1:
			n.rotation.y = lerp_angle(n.rotation.y,atan2(-flat.x,-flat.z),dt*1.2)
		if t.kind == 0:
			if flat.length() > 100:
				n.position += flat.normalized()*dt*(3+wave*0.15)
			n.position.y = g.ground(n.position.x,n.position.z)+2
		elif t.kind != 2:
			t.phase += dt*(0.3 if t.kind == 1 else 0.65)
			var velocity := flat.normalized()* (10.0 if t.kind == 1 else 25.0) if flat.length()>120 else Vector3(cos(t.phase),0,sin(t.phase))*18
			n.position += velocity*dt
			n.position.y = maxf(g.ground(n.position.x,n.position.z)+25,move_toward(n.position.y, g.heli.position.y+8,dt*3))
			if t.kind == 1:
				t.spin.rotation.y += dt*40
		t.tag.position = n.position+Vector3.UP*9
		t.cooldown -= dt
		if offset.length()<360 and t.cooldown<=0:
			var muzzle := n.position+Vector3.UP*3
			var lead: float = minf(1.5,offset.length()/(95+wave*2+difficulty*2))
			var spread: float = maxf(0.8,8-wave*0.35-difficulty*0.15)
			var aim: Vector3 = g.heli.position+g.heli.velocity*lead*0.8+Vector3(g.rng.randf_range(-spread,spread),g.rng.randf_range(-spread,spread),g.rng.randf_range(-spread,spread))
			var ray := PhysicsRayQueryParameters3D.create(muzzle,g.heli.position)
			ray.exclude = [g.heli.get_rid()]
			if g.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				emit_shot(muzzle,(aim-muzzle).normalized(),true)
			t.cooldown = maxf(0.9,5.5-wave*0.16-difficulty*0.12)+g.rng.randf_range(0,1.5)
	if not finished:
		if g.pressed("action",KEY_SPACE) and g.fire_cooldown<=0:
			var target := aim_target(0.965)
			var direction: Vector3 = (target.position-(g.heli.position-g.heli.basis.z*4)).normalized() if target else -g.heli.basis.z
			emit_shot(g.heli.position-g.heli.basis.z*4,direction,false)
			g.fire_cooldown = 0.14
		if g.pressed("missile",KEY_M) and missile_cd<=0:
			var target := aim_target(0.85)
			var direction: Vector3 = (target.position-(g.heli.position-g.heli.basis.z*5)).normalized() if target else -g.heli.basis.z
			emit_shot(g.heli.position-g.heli.basis.z*5,direction,false,true)
			missile_cd = 4
	update_shots(dt)
	display.text = "موج %d از ۲۰ | دشمن: %d از %d\nموشک: %s" % [wave,alive,total,"آماده" if missile_cd<=0 else "%d ثانیه" % ceili(missile_cd)]
	if alive == 0 and not finished:
		if wave == 20:
			finished = true
			g.tell("پیروزی! هر ۲۰ موج را پشت سر گذاشتید.",60)
		elif delay < 0:
			delay = 6
			g.tell("موج تمام شد؛ موج بعدی تا ۶ ثانیه دیگر",6)
		else:
			delay -= dt
			if delay <= 0:
				wave += 1
				delay = -1
				g.health = minf(100,g.health+20)
				spawn_wave()

func blast(position: Vector3) -> void:
	effects.explode(position)
	var flash: Node3D = g.ellipsoid(g,position,Vector3.ONE*2,g.materials.trim)
	var tween := create_tween()
	tween.tween_property(flash,"scale",Vector3.ONE*8,0.3)
	tween.parallel().tween_property(flash,"transparency",1.0,0.45)
	tween.tween_callback(flash.queue_free)

func update_shots(dt: float) -> void:
	for i in range(shots.size()-1,-1,-1):
		var b: Dictionary = shots[i]
		var old: Vector3 = b.node.position
		var next: Vector3 = old+b.velocity*dt
		b.life -= dt
		b.node.position = next
		if b.velocity.normalized().cross(Vector3.UP).length()>0.01:
			b.node.look_at(next+b.velocity,Vector3.UP)
		var ray := PhysicsRayQueryParameters3D.create(old,next)
		ray.exclude = [g.heli.get_rid()]
		var blocked: bool = not g.get_world_3d().direct_space_state.intersect_ray(ray).is_empty() or next.y<g.ground(next.x,next.z)
		if blocked:
			b.life = 0
		elif b.enemy:
			if Geometry3D.get_closest_point_to_segment(g.heli.position,old,next).distance_to(g.heli.position)<2.5:
				if g.invulnerable<=0:
					g.damage(6+wave*0.2+difficulty*0.25)
					g.invulnerable = 0.3
				b.life = 0
		else:
			for t in g.targets:
				if t.hp>0 and Geometry3D.get_closest_point_to_segment(t.node.position,old,next).distance_to(t.node.position)<5:
					t.hp -= 8 if b.missile else 1
					b.life = 0
					if t.hp<=0:
						effects.down(t)
						blast(t.node.position)
						t.node.hide()
						t.tag.hide()
						g.hits += 1
						if g.sound_enabled:
							g.combat_audio.explode()
					break
		if b.life<=0:
			b.node.queue_free()
			shots.remove_at(i)
