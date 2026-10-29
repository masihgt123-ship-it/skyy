extends Node3D

# Original procedural prototype: all geometry is generated locally.
const MODES := ["پرواز آزاد", "نبرد", "نجات"]
var mode: int = 1
var heli: CharacterBody3D
var model: Node3D
var rotor: Node3D
var tail_rotor: Node3D
var camera: Camera3D
var hud: Label
var health_bar: ProgressBar
var health_label: Label
var mission: Label
var notice: Label
var controls: Dictionary = {}
var touch_buttons: Dictionary = {}
var fingers: Dictionary = {}
var reticle: Label
var sound_enabled: bool = true
var speed: float = 0.0
var health: float = 100.0
var mode_time: float = 0.0
var rotor_angle: float = 0.0
var fire_cooldown: float = 0.0
var interact_time: float = 0.0
var rescued: int = 0
var onboard: bool = false
var hits: int = 0
var targets: Array = []
var bullets: Array = []
var rescue_sites: Array[Vector3] = []
var survivors: Array[Node3D] = []
var status_timer: float = 0.0
var invulnerable: float = 0.0
var respawning: bool = false
var base := Vector3(0, 2.2, 70)
var rng := RandomNumberGenerator.new()
var materials: Dictionary = {}
var markers: Array[Node3D] = []

func material(color: Color, metal: float = 0.0, rough: float = 0.65, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, pos, mat)

func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

func ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var n := mesh_node(parent, mesh, pos, mat)
	n.scale = size
	return n

func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	var n := mesh_node(parent, mesh, (a + b) * 0.5, mat)
	var direction := (b - a).normalized()
	n.quaternion = Quaternion(Vector3.UP, direction)
	return n

func ground(x: float, z: float) -> float:
	var radius := Vector2(x / 1.05, z).length()
	var coast := clampf((510.0 - radius) / 100.0, 0, 1)
	var hills := maxf(0, (-z - 95) / 220.0)
	var ridge := pow(maxf(0, sin(x * 0.009 + 1.2) * 0.45 + cos(z * 0.013) * 0.3 + 0.28), 1.5)
	ridge += absf(sin(x*0.027+z*0.018))*0.12+absf(sin(z*0.037))*0.07
	return lerpf(-7, 2.0 + hills * ridge * 125.0, coast)

func _ready() -> void:
	rng.seed = 912408
	materials.body = material(Color("163e4c"), 0.65, 0.3)
	materials.glass = material(Color("072e46"), 0.65, 0.16)
	materials.trim = material(Color("fbad43"), 0.45, 0.3)
	materials.black = material(Color("15202b"), 0.3, 0.6)
	materials.white = material(Color("e6ece8"))
	materials.red = material(Color("ef524b"), 0.3, 0.4, true)
	materials.cyan = material(Color("48e3df"), 0.2, 0.3, true)
	build_environment()
	build_island()
	build_city()
	build_base()
	build_objectives()
	build_helicopter()
	build_ui()
	build_audio()
	get_viewport().msaa_3d = Viewport.MSAA_2X
	set_mode(1)
	var battle := preload("res://battle.gd").new()
	battle.name = "Battle"
	add_child(battle)

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2876a9")
	sky_mat.sky_horizon_color = Color("c3dce3")
	sky_mat.ground_bottom_color = Color("486f7d")
	sky_mat.ground_horizon_color = Color("c3dce3")
	sky_mat.sun_angle_max = 7
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("9bc7d5")
	env.fog_density = 0.0006
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-33, -35, 0)
	sun.light_color = Color("ffe5bd")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	add_child(sun)
	var water_shader := Shader.new()
	water_shader.code = "shader_type spatial; uniform vec4 tint : source_color = vec4(0.035,0.31,0.43,1.0); varying vec3 world_pos; void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float ripple=sin(world_pos.x*0.32+TIME*1.4)*sin(world_pos.z*0.21-TIME)*0.025; ALBEDO=tint.rgb+vec3(ripple); ROUGHNESS=0.24; METALLIC=0.35; NORMAL=normalize(vec3(ripple*0.8,0.0,1.0));}"
	var wm := ShaderMaterial.new()
	wm.shader = water_shader
	var plane := PlaneMesh.new()
	plane.size = Vector2(5000, 5000)
	mesh_node(self, plane, Vector3(0, -0.5, 0), wm)

func build_island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colors := [Color("b3af7b"), Color("5e855a"), Color("66886c"), Color("7b8b81")]
	for iz in range(100):
		for ix in range(100):
			var x: float = ix * 12.0 - 600.0
			var z: float = iz * 12.0 - 600.0
			var points := [Vector3(x, ground(x,z),z), Vector3(x+12,ground(x+12,z),z), Vector3(x,ground(x,z+12),z+12), Vector3(x+12,ground(x+12,z+12),z+12)]
			for j in [0,2,1,1,2,3]:
				var p: Vector3 = points[j]
				var c: Color = colors[0] if p.y < 1.5 else (colors[3] if p.y > 45 else colors[1 + (ix + iz) % 2])
				st.set_color(c)
				st.add_vertex(p)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node(self, st.commit(), Vector3.ZERO, mat)
	var bark := material(Color("70624b"))
	var leaves := material(Color("306b56"))
	for i in range(180):
		var x := rng.randf_range(-430,430)
		var z := rng.randf_range(-440,350)
		var y := ground(x,z)
		if y < 1.8 or (absf(x) < 205 and z > -115 and z < 210):
			continue
		var h := rng.randf_range(4,9)
		tube(self,Vector3(x,y,z),Vector3(x,y+h,z),0.28,bark)
		ellipsoid(self,Vector3(x,y+h,z),Vector3(h*0.48,h*0.6,h*0.48),leaves)

func solid_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	box(body, Vector3.ZERO, size, mat)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)

func build_city() -> void:
	var road := material(Color("343f48"))
	var pavement := material(Color("b8bcb1"))
	var buildings := [material(Color("b9cccb")), material(Color("d6d4bd")), material(Color("77969c"))]
	var windows := material(Color("366079"),0.4,0.27)
	for x in [-180, -90, 0, 90, 180]:
		box(self,Vector3(x,2.05,40),Vector3(15,0.12,340),road)
		for z in range(-115,211,15):
			box(self,Vector3(x,2.13,z),Vector3(0.3,0.02,6),materials.white)
	for z in [-110,-20,70,160]:
		box(self,Vector3(0,2.07,z),Vector3(390,0.12,15),road)
	for x in [-135,-45,45,135]:
		for z in [-65,25,115]:
			box(self,Vector3(x,2.02,z),Vector3(67,0.15,67),pavement)
			for dx in [-17,17]:
				for dz in [-17,17]:
					var h := rng.randf_range(12,48)
					var p := Vector3(x+dx,2+h/2,z+dz)
					solid_box(p,Vector3(23,h,24),buildings[rng.randi_range(0,2)])
					box(self,Vector3(p.x,2+h+0.5,p.z),Vector3(24,1,25),materials.white)
					box(self,Vector3(p.x+5,3.5+h,p.z+4),Vector3(5,2,4),materials.black)
					var solar := box(self,Vector3(p.x-4,3+h,p.z-3),Vector3(8,0.15,6),windows)
					solar.rotation_degrees.x = -12
					for y in range(6,int(h),6):
						box(self,Vector3(p.x,2+y,p.z+12.03),Vector3(19,2,0.08),windows)
						box(self,Vector3(p.x+11.53,2+y,p.z),Vector3(0.08,2,19),windows)
	# Two separated lanes on the existing perimeter streets.
	var traffic_script = preload("res://traffic_car.gd")
	var routes: Array[Curve3D] = [traffic_script.street_loop(0.0), traffic_script.street_loop(10.0)]
	for i in range(26):
		var lane: int = i % 2
		var route: Curve3D = routes[lane]
		var car := Node3D.new()
		car.set_script(traffic_script)
		add_child(car)
		car.configure(route, float(i / 2) * route.get_baked_length() / 13.0, 1.0 if lane == 0 else -1.0)
		box(car,Vector3.ZERO,Vector3(1.8,0.8,4.1),materials.trim if i%3 == 0 else materials.body)
		box(car,Vector3(0,0.6,-0.3),Vector3(1.5,0.7,2.1),windows)
		for sx in [-1,1]:
			for sz in [-1,1]:
				ellipsoid(car,Vector3(sx*0.9,-0.25,sz*1.3),Vector3(0.16,0.35,0.35),materials.black)
	# Coastal promenade and a small harbor.
	box(self,Vector3(260,1.4,180),Vector3(15,2,170),pavement)
	for z in [130,190,250]:
		box(self,Vector3(305,0.7,z),Vector3(90,1.5,9),pavement)
		var boat := Node3D.new()
		boat.position = Vector3(325,0,z+13)
		add_child(boat)
		ellipsoid(boat,Vector3.ZERO,Vector3(4,2,12),materials.white)
		box(boat,Vector3(0,2,0),Vector3(5,3,7),materials.body)

func label3d(text: String, pos: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = preload("res://fonts/DejaVuSans.ttf")
	label.language = "fa"
	label.text_direction = TextServer.DIRECTION_RTL
	label.position = pos
	label.font_size = 48
	label.pixel_size = 0.06
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)
	return label

func pad(pos: Vector3, radius: float, mat: Material) -> void:
	tube(self,pos-Vector3(0,0.2,0),pos+Vector3(0,0.05,0),radius,mat)
	box(self,pos+Vector3(-radius*0.36,0.1,0),Vector3(0.8,0.04,radius*1.15),materials.white)
	box(self,pos+Vector3(radius*0.36,0.1,0),Vector3(0.8,0.04,radius*1.15),materials.white)
	box(self,pos+Vector3(0,0.1,0),Vector3(radius*0.72,0.04,0.8),materials.white)

func build_base() -> void:
	pad(base,10,materials.body)
	label3d("شهر آسمان",base+Vector3(0,12,0),Color("7affdf"))
	for x in [-11,11]:
		for z in [-11,11]:
			ellipsoid(self,base+Vector3(x,0.3,z),Vector3(0.35,0.35,0.35),materials.cyan)
	# Hangar off the road, behind the launch point.
	solid_box(Vector3(-28,8,205),Vector3(40,12,30),materials.body)
	box(self,Vector3(-28,7,189.9),Vector3(28,9,0.2),materials.black)
	label3d("پایگاه هوایی آسمان",Vector3(-28,17,202),Color.WHITE)

func build_objectives() -> void:
	for p in [Vector2(-270,-160),Vector2(180,-270),Vector2(350,55)]:
		var pos := Vector3(p.x,ground(p.x,p.y)+0.3,p.y)
		rescue_sites.append(pos)
		pad(pos,9,materials.trim)
		var person := Node3D.new()
		person.position = pos+Vector3(3,0.1,2)
		add_child(person)
		tube(person,Vector3(0,0.5,0),Vector3(0,1.4,0),0.3,materials.trim)
		ellipsoid(person,Vector3(0,1.8,0),Vector3.ONE*0.28,materials.white)
		for side in [-1,1]:
			tube(person,Vector3(side*0.15,0.7,0),Vector3(side*0.25,0,0),0.1,materials.black)
			tube(person,Vector3(side*0.2,1.3,0),Vector3(side*0.65,1.9,0),0.09,materials.trim)
		survivors.append(person)
		markers.append(label3d("درخواست نجات",pos+Vector3(0,14,0),Color("ffd383")))
	for i in range(5):
		var x: float = -260.0 + i*115.0
		var z: float = -220.0 - (i%2)*110.0
		var pos := Vector3(x,ground(x,z)+12,z)
		var drone := Node3D.new()
		drone.position = pos
		add_child(drone)
		ellipsoid(drone,Vector3.ZERO,Vector3(2.5,1.1,2),materials.black)
		box(drone,Vector3(0,0,-1.8),Vector3(1.3,0.4,0.3),materials.red)
		for side in [-1,1]:
			box(drone,Vector3(side*3,0,0),Vector3(5,0.2,0.4),materials.body)
			tube(drone,Vector3(side*5,-0.1,0),Vector3(side*5,0.1,0),1.8,materials.black)
		var tag := label3d("دشمن",pos+Vector3(0,7,0),Color("ff7770"))
		targets.append({"node":drone,"origin":pos,"hp":3,"cooldown":float(i)+2.0,"tag":tag})

func build_helicopter() -> void:
	heli = CharacterBody3D.new()
	heli.name = "Helicopter"
	heli.position = base+Vector3(0,4,0)
	add_child(heli)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.7
	col.shape = shape
	heli.add_child(col)
	model = Node3D.new()
	heli.add_child(model)
	ellipsoid(model,Vector3(0,0,0),Vector3(1.65,1.55,3.0),materials.body)
	ellipsoid(model,Vector3(0,0.35,-1.8),Vector3(1.45,1.23,1.65),materials.glass)
	# Cockpit framing and yellow rescue stripe.
	tube(model,Vector3(0,1.6,-0.9),Vector3(0,0.2,-3.4),0.055,materials.trim)
	for side in [-1,1]:
		box(model,Vector3(side*1.57,-0.3,-0.1),Vector3(0.07,0.25,3.5),materials.trim)
		box(model,Vector3(side*1.55,0.4,0.7),Vector3(0.08,1.6,1.25),materials.black)
		box(model,Vector3(side*1.6,0.65,0.65),Vector3(0.05,0.65,0.9),materials.glass)
		tube(model,Vector3(side*1.15,-1,0.9),Vector3(side*1.85,-2,1.2),0.09,materials.black)
		tube(model,Vector3(side*1.15,-1,-1.3),Vector3(side*1.85,-2,-1.7),0.09,materials.black)
		tube(model,Vector3(side*1.85,-2,2.0),Vector3(side*1.85,-2,-2.7),0.12,materials.black)
		tube(model,Vector3(side*1.85,-2,-2.7),Vector3(side*1.85,-1.7,-3.1),0.12,materials.black)
		ellipsoid(model,Vector3(side*1.7,0.15,-0.6),Vector3(0.12,0.12,0.12),materials.red if side < 0 else materials.cyan)
	tube(model,Vector3(0,0.3,2),Vector3(0,1.1,8.4),0.65,materials.body,0.15)
	box(model,Vector3(0,2,7.7),Vector3(0.15,2.6,1.6),materials.trim)
	box(model,Vector3(0,0.95,6.5),Vector3(4,0.12,0.9),materials.body)
	for side in [-1,1]:
		tube(model,Vector3(side*0.65,1.1,0.8),Vector3(side*0.65,1.7,1.7),0.38,materials.black)
	tube(model,Vector3(0,1.3,0),Vector3(0,2.6,0),0.18,materials.black)
	rotor = Node3D.new()
	rotor.position.y = 2.6
	model.add_child(rotor)
	for angle in [0,90]:
		var blade := box(rotor,Vector3.ZERO,Vector3(13,0.07,0.3),materials.black)
		blade.rotation_degrees.y = angle
	ellipsoid(rotor,Vector3.ZERO,Vector3(0.45,0.2,0.45),materials.trim)
	tail_rotor = Node3D.new()
	tail_rotor.position = Vector3(0.3,1.4,8)
	model.add_child(tail_rotor)
	box(tail_rotor,Vector3.ZERO,Vector3(0.08,2.5,0.18),materials.black)
	box(tail_rotor,Vector3.ZERO,Vector3(0.08,0.18,2.5),materials.black)
	camera = Camera3D.new()
	camera.fov = 66
	camera.far = 2400
	add_child(camera)
	camera.position = heli.position+Vector3(0,9,22)
	camera.current = true

func button(parent: Control, title: String, pos: Vector2, size: Vector2, action: String = "") -> Button:
	var b := Button.new()
	b.text = title
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size",18)
	b.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.075,0.105,0.83)
	style.border_color = Color(0.3,0.75,0.78,0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal",style)
	var active := style.duplicate() as StyleBoxFlat
	active.bg_color = Color(0.1,0.5,0.53,0.9)
	b.add_theme_stylebox_override("pressed",active)
	parent.add_child(b)
	if not action.is_empty():
		controls[action] = false
		touch_buttons[action] = b
		b.button_down.connect(func(): controls[action] = true)
		b.button_up.connect(func(): controls[action] = false)
	return b

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.layout_direction = Control.LAYOUT_DIRECTION_LTR
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var shade := ColorRect.new()
	shade.position = Vector2(20,18)
	shade.size = Vector2(505,140)
	shade.color = Color(0.015,0.045,0.065,0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	shade.hide()
	hud = Label.new()
	hud.position = Vector2(36,27)
	hud.add_theme_font_size_override("font_size",23)
	ui.add_child(hud)
	hud.hide()
	var health_panel := VBoxContainer.new()
	ui.add_child(health_panel)
	health_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	health_panel.offset_left = -230
	health_panel.offset_right = -30
	health_panel.offset_top = -65
	health_panel.offset_bottom = -5
	health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label = Label.new()
	health_label.text = "سلامت ۱۰۰٪"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 24)
	health_panel.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(200, 24)
	health_bar.show_percentage = false
	health_bar.value = 100
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_panel.add_child(health_bar)
	mission = Label.new()
	mission.position = Vector2(36,96)
	mission.add_theme_font_size_override("font_size",16)
	ui.add_child(mission)
	mission.hide()
	var radar := preload("res://radar.gd").new()
	radar.game = self
	radar.position = Vector2(775,464)
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(radar)
	reticle = Label.new()
	reticle.text = "+"
	reticle.add_theme_font_size_override("font_size",34)
	reticle.add_theme_color_override("font_color",Color("ffcb77"))
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(reticle)
	notice = Label.new()
	notice.position = Vector2(36,171)
	notice.add_theme_font_size_override("font_size",19)
	notice.add_theme_color_override("font_color",Color("ffdc96"))
	ui.add_child(notice)
	var hint := Label.new()
	hint.text = "حرکت: W/S   چرخش: A/D   حرکت جانبی: Q/E   ارتفاع: R/F   شلیک: Space"
	hint.position = Vector2(30,682)
	hint.visible = not (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	hint.add_theme_font_size_override("font_size",16)
	ui.add_child(hint)
	button(ui,"چرخش\nچپ",Vector2(25,552),Vector2(100,105),"left")
	button(ui,"چرخش\nراست",Vector2(135,552),Vector2(100,105),"right")
	button(ui,"جلو",Vector2(80,435),Vector2(130,96),"forward")
	button(ui,"عقب",Vector2(245,552),Vector2(100,105),"back")
	button(ui,"بالا",Vector2(1145,435),Vector2(105,96),"up")
	button(ui,"پایین",Vector2(1145,552),Vector2(105,105),"down")
	button(ui,"شلیک",Vector2(975,552),Vector2(155,105),"action")

func pressed(action: String, key: Key) -> bool:
	return bool(controls.get(action,false)) or action in fingers.values() or Input.is_physical_key_pressed(key)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			track_finger(event.index,event.position)
		else:
			fingers.erase(event.index)
	elif event is InputEventScreenDrag:
		track_finger(event.index,event.position)

func track_finger(index: int, point: Vector2) -> void:
	fingers.erase(index)
	for action in touch_buttons:
		if touch_buttons[action].get_global_rect().has_point(point):
			fingers[index] = action
			break

var combat_audio: Node

func build_audio() -> void:
	combat_audio = preload("res://combat_audio.gd").new()
	add_child(combat_audio)

func update_audio() -> void:
	combat_audio.update_state(health, speed, sound_enabled)

func tell(text: String, duration: float = 4.0) -> void:
	notice.text = text
	status_timer = duration

func set_mode(_value: int) -> void:
	mode = 1
	reticle.visible = mode == 1
	mode_time = 0
	interact_time = 0
	for t in targets:
		t.node.visible = mode == 1 and t.hp > 0
		t.tag.visible = mode == 1 and t.hp > 0
	for i in range(markers.size()):
		markers[i].visible = mode == 2 and i >= rescued and not (onboard and i == rescued)
		survivors[i].visible = mode == 2 and i >= rescued and not (onboard and i == rescued)
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	tell(["جزیره را کشف کنید؛ با بالا اوج بگیرید و با پایین فرود بیایید.","۲۰ موج دشمن را پشت سر بگذارید؛ شلیک با Space و موشک با M.","بالای محل نجات بمانید؛ سپس به پایگاه برگردید."][mode],7)

func reset_helicopter() -> void:
	heli.position = base+Vector3(0,4,0)
	heli.rotation = Vector3.ZERO
	heli.velocity = Vector3.ZERO
	speed = 0
	health = 100
	invulnerable = 3
	interact_time = 0
	onboard = false
	rescued = 0
	hits = 0
	for t in targets:
		t.hp = 3
		t.cooldown = 3.0
	if has_node("Battle"):
		get_node("Battle").restart()
	set_mode(mode)
	tell("پرواز تازه آماده است.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		fingers.clear()
		for key in controls:
			controls[key] = false

func _physics_process(delta: float) -> void:
	mode_time += delta
	fire_cooldown = maxf(0,fire_cooldown-delta)
	invulnerable = maxf(0,invulnerable-delta)
	status_timer -= delta
	if status_timer <= 0:
		notice.text = ""
	var forward_input := float(pressed("forward",KEY_W))-float(pressed("back",KEY_S))
	var turn := float(pressed("left",KEY_A))-float(pressed("right",KEY_D))
	var lift := float(pressed("up",KEY_R))-float(pressed("down",KEY_F))
	heli.rotation.y += turn*delta*0.9
	speed = move_toward(speed,forward_input*48.0,delta*14.0)
	var sideways := float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q))
	var desired := -heli.basis.z*speed+heli.basis.x*sideways*14.0
	heli.velocity.x = desired.x
	heli.velocity.z = desired.z
	heli.velocity.y = move_toward(heli.velocity.y,lift*15.0,delta*16.0)
	var collision_speed := heli.velocity.length()
	heli.move_and_slide()
	if heli.get_slide_collision_count() > 0 and collision_speed > 10 and invulnerable <= 0:
		damage(12)
		speed *= -0.15
		invulnerable = 1
	var floor_height := maxf(0.0,ground(heli.position.x,heli.position.z))+2.15
	if heli.position.y < floor_height:
		if heli.velocity.y < -8 and invulnerable <= 0:
			damage(15)
			invulnerable = 1
		heli.position.y = floor_height
		heli.velocity.y = maxf(0,heli.velocity.y)
	heli.position.y = minf(heli.position.y,280)
	if Vector2(heli.position.x,heli.position.z).length() > 1000:
		tell("به مرز پرواز رسیدید؛ بازگشت به پایگاه.")
		heli.position = base+Vector3(0,35,0)
		speed = 0
	model.rotation.x = lerp_angle(model.rotation.x,-speed*0.003,delta*4)
	model.rotation.z = lerp_angle(model.rotation.z,turn*0.2-sideways*0.12,delta*4)
	rotor_angle += delta*43
	rotor.rotation.y = rotor_angle
	tail_rotor.rotation.x = rotor_angle*1.5
	update_camera(delta)
	if mode == 1:
		var aim_point := heli.position-heli.basis.z*120
		reticle.position = camera.unproject_position(aim_point)-Vector2(10,22)
	update_audio()
	update_combat(delta)
	if mode == 2:
		update_rescue(delta)
	if heli.position.distance_to(base) < 15 and absf(speed) < 3:
		health = minf(100,health+delta*7)
	health_bar.value = clampf(health, 0, 100)
	health_label.text = "سلامت %d٪" % maxi(0, int(health))
	health_label.modulate = Color("ff6666") if health <= 30 else Color("79ffb0")
	var altitude := maxf(0,heli.position.y-maxf(0,ground(heli.position.x,heli.position.z))-2.15)
	hud.text = "نگهبان آسمان / " + MODES[mode] + "\nسرعت %03d     ارتفاع %03d     سلامت %d٪" % [absf(speed)*3.6,altitude,health]
	if mode == 0:
		mission.text = "جزیرهٔ آسمان؛ شهر، بندر و کوهستان\nبرای تعمیر در پایگاه فرود بیایید."
	elif mode == 1:
		mission.text = "دشمنان نابودشده: %d از ۵\nبه سمت نشان‌های قرمز شلیک کنید؛ برد سلاح ۲۵۰ متر است." % hits
	else:
		var destination := base if onboard or rescued >= 3 else rescue_sites[rescued]
		mission.text = "نجات‌یافته: %d از ۳ | %s | %d متر\nزیر ۱۲ متر بمانید و دکمه را ۳ ثانیه نگه دارید." % [rescued,"بازگشت به پایگاه" if onboard else "به سوی محل نجات",heli.position.distance_to(destination)]

func update_camera(delta: float) -> void:
	var target := heli.position+Vector3.UP*1.7
	var desired := heli.position+heli.basis.z*(21+absf(speed)*0.09)+heli.basis.x*6+Vector3.UP*8
	desired.y = maxf(desired.y,ground(desired.x,desired.z)+4)
	var ray := PhysicsRayQueryParameters3D.create(target,desired)
	ray.exclude = [heli.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		desired = hit.position+hit.normal*1.5
	camera.position = camera.position.lerp(desired,1-exp(-delta*4))
	camera.look_at(target-heli.basis.z*7,Vector3.UP)

func damage(amount: float) -> void:
	health -= amount
	if health <= 0 and not respawning:
		respawning = true
		call_deferred("respawn_after_crash")

func respawn_after_crash() -> void:
	reset_helicopter()
	respawning = false
	tell("هلیکوپتر از دست رفت؛ پرواز تازه در پایگاه آماده است.",6)

func shoot(pos: Vector3, direction: Vector3, enemy: bool) -> void:
	if not enemy and sound_enabled:
		combat_audio.fire()
	var node := ellipsoid(self,pos,Vector3(0.2,0.2,0.85) if not enemy else Vector3.ONE*0.42,materials.trim if not enemy else materials.red)
	if direction.cross(Vector3.UP).length() > 0.01:
		node.look_at(pos+direction,Vector3.UP)
	bullets.append({"node":node,"velocity":direction*(70.0 if enemy else 190.0),"life":4.0 if enemy else 1.35,"enemy":enemy})

func update_combat(delta: float) -> void:
	if has_node("Battle"):
		get_node("Battle").tick(delta)
		return
	if mode == 1:
		if pressed("action",KEY_SPACE) and fire_cooldown <= 0:
			var direction := -heli.basis.z
			var best_alignment := 0.985
			for t in targets:
				var offset: Vector3 = t.node.position-heli.position
				if t.hp > 0 and offset.length() < 250:
					var alignment := (-heli.basis.z).dot(offset.normalized())
					if alignment > best_alignment:
						best_alignment = alignment
						direction = offset.normalized()
			shoot(heli.position-heli.basis.z*4,direction,false)
			fire_cooldown = 0.14
		for t in targets:
			if t.hp <= 0:
				continue
			var node: Node3D = t.node
			node.position = t.origin+Vector3(sin(mode_time*0.3+float(t.origin.x))*5,sin(mode_time*1.2)*1.7,0)
			t.tag.position = node.position+Vector3.UP*7
			t.cooldown -= delta
			if node.position.distance_to(heli.position) < 210 and t.cooldown <= 0:
				shoot(node.position,(heli.position-node.position).normalized(),true)
				t.cooldown = 3.5
	for i in range(bullets.size()-1,-1,-1):
		var b: Dictionary = bullets[i]
		var old: Vector3 = b.node.position
		var next: Vector3 = old+b.velocity*delta
		b.life -= delta
		b.node.position = next
		if b.enemy:
			if Geometry3D.get_closest_point_to_segment(heli.position,old,next).distance_to(heli.position) < 2.5:
				if invulnerable <= 0:
					damage(8)
					invulnerable = 0.3
				b.life = 0
		else:
			for t in targets:
				if t.hp > 0 and Geometry3D.get_closest_point_to_segment(t.node.position,old,next).distance_to(t.node.position) < 4:
					t.hp -= 1
					b.life = 0
					if t.hp <= 0:
						if sound_enabled:
							combat_audio.explode()
						t.node.hide()
						t.tag.hide()
						hits += 1
						tell("دشمن نابود شد: %d از ۵" % hits)
						if hits == 5:
							tell("مأموریت کامل شد؛ آسمان جزیره امن است!",12)
					break
		# Buildings and terrain stop shots.
		var ray := PhysicsRayQueryParameters3D.create(old,next)
		ray.exclude = [heli.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty() or next.y < maxf(-0.5,ground(next.x,next.z)):
			b.life = 0
		if b.life <= 0:
			b.node.queue_free()
			bullets.remove_at(i)

func update_rescue(delta: float) -> void:
	if rescued >= rescue_sites.size():
		return
	var destination := base if onboard else rescue_sites[rescued]
	var flat_dist := Vector2(heli.position.x-destination.x,heli.position.z-destination.z).length()
	var height := heli.position.y-destination.y
	var eligible := flat_dist < 10 and height >= 1.5 and height < 14 and absf(speed) < 4 and absf(heli.velocity.y) < 3
	if eligible and pressed("action",KEY_SPACE):
		interact_time += delta
		tell(("پیاده‌کردن" if onboard else "بالاکشیدن")+"  %d%%" % mini(100,int(interact_time/3*100)),0.3)
		if interact_time >= 3:
			interact_time = 0
			if onboard:
				onboard = false
				rescued += 1
				tell("بازمانده تحویل داده شد؛ به محل بعدی بروید." if rescued < 3 else "مأموریت کامل شد؛ هر سه بازمانده نجات یافتند!",10)
			else:
				onboard = true
				survivors[rescued].hide()
				markers[rescued].hide()
				tell("بازمانده سوار شد؛ به پایگاه برگردید.",7)
	else:
		interact_time = 0
