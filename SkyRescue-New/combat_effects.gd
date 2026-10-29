extends Node3D
var g: Node3D
var debris: Array = []
var wrecks: Array = []
var smoke_material: Material
func _ready() -> void:
	g = get_parent().g
	smoke_material = g.material(Color(0.16,0.17,0.19,0.75))
func puff(p: Vector3) -> void:
	var n: MeshInstance3D = g.ellipsoid(self,p,Vector3.ONE*1.4,smoke_material)
	var tween := n.create_tween().set_parallel(true)
	tween.tween_property(n,"position",p+Vector3(1,7,0),1.5)
	tween.tween_property(n,"scale",Vector3.ONE*3,1.5)
	tween.tween_property(n,"transparency",1.0,1.5)
	tween.chain().tween_callback(n.queue_free)
func explode(p: Vector3) -> void:
	for i in range(7):
		var n: Node3D = g.box(self,p,Vector3.ONE*g.rng.randf_range(0.3,0.9),g.materials.black)
		debris.append({"node":n,"velocity":Vector3(g.rng.randf_range(-13,13),g.rng.randf_range(8,20),g.rng.randf_range(-13,13)),"life":2.5})
	for i in range(3):
		puff(p+Vector3(0,i,0))
func down(t: Dictionary) -> void:
	if t.kind != 1 and t.kind != 3:
		return
	var wreck: Node3D = t.node.duplicate()
	add_child(wreck)
	wreck.global_transform = t.node.global_transform
	wreck.show()
	wrecks.append({"node":wreck,"velocity":Vector3(4,-3,2),"life":6.0,"smoke":0.0})
func clear() -> void:
	debris.clear()
	wrecks.clear()
	for child in get_children():
		child.queue_free()
func _process(dt: float) -> void:
	for i in range(debris.size()-1,-1,-1):
		var d: Dictionary = debris[i]
		d.life -= dt
		d.velocity.y -= 24*dt
		d.node.position += d.velocity*dt
		d.node.rotate_x(dt*4)
		d.node.rotate_z(dt*3)
		if d.life <= 0 or d.node.position.y < g.ground(d.node.position.x,d.node.position.z):
			d.node.queue_free()
			debris.remove_at(i)
	for i in range(wrecks.size()-1,-1,-1):
		var w: Dictionary = wrecks[i]
		w.life -= dt
		w.smoke -= dt
		w.velocity.y -= 13*dt
		w.node.position += w.velocity*dt
		w.node.rotate_z(dt*1.3)
		w.node.rotate_y(dt*0.7)
		if w.smoke <= 0:
			puff(w.node.position)
			w.smoke = 0.2
		if w.life <= 0 or w.node.position.y <= g.ground(w.node.position.x,w.node.position.z)+1:
			get_parent().blast(w.node.position)
			w.node.queue_free()
			wrecks.remove_at(i)
