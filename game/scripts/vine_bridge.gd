extends Node3D
## 枯藤锚点 + 藤桥：木籽命中任一锚点后，藤蔓沿弧线生长成可通行桥。

const GROW_SEG_TIME := 0.09
const ARC_HEIGHT := 0.22

var grown := false

var _anchor_a: Node3D
var _anchor_b: Node3D
var _seg_root: Node3D
var _collider: CollisionShape3D
var _span := 0.0
var _tip_mat_a: StandardMaterial3D
var _tip_mat_b: StandardMaterial3D


func _ready() -> void:
	var a := Vector3(0, 0, -21.2)
	var b := Vector3(0, 0, -30.8)
	_span = a.distance_to(b)

	_anchor_a = _make_anchor(a)
	_anchor_b = _make_anchor(b)
	add_child(_anchor_a)
	add_child(_anchor_b)

	_seg_root = Node3D.new()
	_seg_root.visible = false
	add_child(_seg_root)
	_build_segments(a, b)

	_collider = CollisionShape3D.new()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.16, _span - 0.6)
	_collider.shape = box
	_collider.position = Vector3(0, -0.03, (a.z + b.z) * 0.5)
	_collider.disabled = true
	body.add_child(_collider)
	add_child(body)


func _make_anchor(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.add_to_group("vine_anchor")
	root.set_meta("bridge", self)

	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.07
	pm.bottom_radius = 0.1
	pm.height = 1.25
	pole.mesh = pm
	pole.position.y = 0.62
	pole.material_override = _wood(Color(0.30, 0.24, 0.17))
	root.add_child(pole)

	var wrap := MeshInstance3D.new()
	var wm := TorusMesh.new()
	wm.inner_radius = 0.10
	wm.outer_radius = 0.17
	wrap.mesh = wm
	wrap.position.y = 0.95
	var tip := StandardMaterial3D.new()
	tip.albedo_color = Color(0.25, 0.34, 0.18)
	tip.emission_enabled = true
	tip.emission = Color(0.45, 0.85, 0.3)
	tip.emission_energy_multiplier = 0.25
	wrap.material_override = tip
	root.add_child(wrap)
	if _tip_mat_a == null:
		_tip_mat_a = tip
	else:
		_tip_mat_b = tip

	var area := Area3D.new()
	area.monitoring = false
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.0
	cs.shape = sph
	cs.position.y = 0.9
	area.add_child(cs)
	root.add_child(area)
	return root


func _build_segments(a: Vector3, b: Vector3) -> void:
	var segs := 8
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var p0 := _arc_point(a, b, t0)
		var p1 := _arc_point(a, b, t1)
		var mid := (p0 + p1) * 0.5
		var dir := (p1 - p0).normalized()

		var y_ax := dir
		var x_ax := y_ax.cross(Vector3.UP)
		if x_ax.length_squared() < 0.0001:
			x_ax = Vector3.RIGHT
		x_ax = x_ax.normalized()
		var z_ax := x_ax.cross(y_ax).normalized()

		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.055
		cm.bottom_radius = 0.055
		cm.height = p0.distance_to(p1) * 1.12
		cm.radial_segments = 7
		mi.mesh = cm
		mi.transform = Basis(x_ax, y_ax, z_ax)
		mi.position = mid
		var vine := StandardMaterial3D.new()
		vine.albedo_color = Color(0.30, 0.42, 0.20)
		vine.emission_enabled = true
		vine.emission = Color(0.4, 0.7, 0.25)
		vine.emission_energy_multiplier = 0.45
		vine.roughness = 0.9
		mi.material_override = vine
		mi.scale = Vector3.ONE * 0.02
		_seg_root.add_child(mi)


func _arc_point(a: Vector3, b: Vector3, t: float) -> Vector3:
	var p := a.lerp(b, t)
	var bell := 1.0 - pow(2.0 * t - 1.0, 2.0)
	p.y += ARC_HEIGHT * bell + 0.12
	return p


func notify_seed_hit() -> void:
	if grown:
		return
	grow()


func grow() -> void:
	if grown:
		return
	grown = true
	_seg_root.visible = true
	_collider.set_deferred("disabled", false)
	var segs := _seg_root.get_children()
	for i in range(segs.size()):
		var seg: Node3D = segs[i]
		var tw := create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(seg, "scale", Vector3.ONE, GROW_SEG_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw2 := create_tween()
	tw2.tween_property(_tip_mat_a, "emission_energy_multiplier", 1.5, 0.6)
	tw2.parallel().tween_property(_tip_mat_b, "emission_energy_multiplier", 1.5, 0.6)


func is_grown() -> bool:
	return grown


func _wood(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m
