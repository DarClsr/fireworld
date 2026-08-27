extends Node3D
## 灰窑村全程序化搭建：山坳石壁、村舍、大灰窑、灯笼、陶婆婆、村口栅栏。
## 布局用局部坐标（村庄实例放在原点，局部=世界）。

var font: Font

# 关键点位（director / main 通过 to_global 换算）
var spawn_local := Vector3(-6.5, 0.06, 12.0)
var grandma_local := Vector3(7.2, 0.0, -8.0)
var kiln_spark_local := Vector3(7.9, 1.15, -8.6)
var gate_local := Vector3(2.8, 0.0, -14.4)
var dummy_local := Vector3(-4.5, 0.0, -9.5)

var lantern_lights: Array[OmniLight3D] = []

var _ember_light: OmniLight3D
var _noise := FastNoiseLite.new()
var _t := 0.0

const HOUSES := [
	{"pos": Vector3(-9.5, 0, 12.5), "rot": 25.0, "home": true},
	{"pos": Vector3(5.5, 0, 10.5), "rot": -18.0, "home": false},
	{"pos": Vector3(-12.0, 0, 1.5), "rot": 80.0, "home": false},
	{"pos": Vector3(11.5, 0, 3.5), "rot": -70.0, "home": false},
	{"pos": Vector3(-8.5, 0, -12.5), "rot": 130.0, "home": false},
]
const LANTERNS := [
	Vector3(-4.0, 0, 6.5), Vector3(1.5, 0, 3.0), Vector3(-2.5, 0, -3.0),
	Vector3(3.5, 0, -7.0), Vector3(-1.5, 0, -11.0), Vector3(6.5, 0, -5.5),
]


func _ready() -> void:
	_noise.seed = 55
	_noise.frequency = 9.0
	for h: Dictionary in HOUSES:
		_build_house(h)
	_build_kiln()
	for p: Vector3 in LANTERNS:
		_build_lantern(p)
	_build_props()
	_build_grandma()
	_build_rocks()


func _process(delta: float) -> void:
	_t += delta
	if _ember_light != null:
		_ember_light.light_energy = 1.3 * (0.86 + 0.14 * _noise.get_noise_1d(_t * 7.0))


# ---------------------------------------------------------------- 村舍

func _build_house(cfg: Dictionary) -> void:
	var root := Node3D.new()
	root.position = cfg.pos
	root.rotation_degrees.y = cfg.rot
	add_child(root)

	var walls := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(3.6, 2.3, 4.4)
	walls.mesh = wm
	walls.position.y = 1.15
	walls.material_override = _mat(Color(0.56, 0.52, 0.46))
	root.add_child(walls)

	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(4.4, 1.5, 5.1)
	roof.mesh = rm
	roof.position.y = 2.3 + 0.74
	roof.material_override = _mat(Color(0.27, 0.19, 0.14))
	root.add_child(roof)

	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.9, 1.5, 0.12)
	door.mesh = dm
	door.position = Vector3(0, 0.75, -2.24)
	door.material_override = _mat(Color(0.23, 0.16, 0.11))
	root.add_child(door)

	# 窗：炉火余光（家宅两扇，其他一扇）
	var win_count := 2 if cfg.home else 1
	for i in range(win_count):
		var win := MeshInstance3D.new()
		var wmesh := BoxMesh.new()
		wmesh.size = Vector3(0.7, 0.55, 0.08)
		win.mesh = wmesh
		win.position = Vector3(-1.1 + 2.2 * float(i), 1.35, -2.22)
		win.material_override = _glow(Color(1.0, 0.76, 0.42), 1.1)
		root.add_child(win)

	if cfg.home:
		var chim := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.5, 1.1, 0.5)
		chim.mesh = cm
		chim.position = Vector3(1.0, 3.4, 1.0)
		chim.material_override = _mat(Color(0.4, 0.38, 0.36))
		root.add_child(chim)


# ---------------------------------------------------------------- 灰窑

func _build_kiln() -> void:
	var root := Node3D.new()
	root.position = Vector3(9.4, 0, -10.2)
	root.rotation_degrees.y = -42.0
	add_child(root)

	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 2.5
	bm.bottom_radius = 2.9
	bm.height = 0.9
	base.mesh = bm
	base.position.y = 0.45
	base.material_override = _mat(Color(0.3, 0.3, 0.32))
	root.add_child(base)

	var body := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 1.75
	km.bottom_radius = 2.15
	km.height = 3.1
	body.mesh = km
	body.position.y = 2.4
	body.material_override = _mat(Color(0.34, 0.34, 0.37))
	root.add_child(body)

	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 1.75
	dm.height = 3.5
	dome.mesh = dm
	dome.scale = Vector3(1.0, 0.55, 1.0)
	dome.position.y = 3.95
	dome.material_override = _mat(Color(0.31, 0.31, 0.34))
	root.add_child(dome)

	# 窑口：黑洞 + 余烬
	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(1.1, 1.5, 0.5)
	mouth.mesh = mm
	mouth.position = Vector3(-1.95, 1.6, 0)
	mouth.material_override = _mat(Color(0.04, 0.03, 0.03))
	root.add_child(mouth)

	var ember := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3(0.7, 0.8, 0.1)
	ember.mesh = em
	ember.position = Vector3(-1.75, 1.35, 0)
	ember.material_override = _glow(Color(1.0, 0.45, 0.15), 1.5)
	root.add_child(ember)

	_ember_light = OmniLight3D.new()
	_ember_light.position = Vector3(-2.6, 1.6, 0)
	_ember_light.light_color = Color(1.0, 0.58, 0.28)
	_ember_light.omni_range = 8.0
	_ember_light.light_energy = 1.3
	_ember_light.shadow_enabled = false
	root.add_child(_ember_light)


# ---------------------------------------------------------------- 灯笼 / 杂物

func _build_lantern(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)

	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.07
	pm.height = 2.3
	pole.mesh = pm
	pole.position.y = 1.15
	pole.material_override = _mat(Color(0.25, 0.19, 0.14))
	root.add_child(pole)

	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.3, 0.36, 0.3)
	head.mesh = hm
	head.position.y = 2.28
	head.material_override = _glow(Color(1.0, 0.78, 0.45), 1.6)
	root.add_child(head)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.25, 0)
	light.light_color = Color(1.0, 0.72, 0.42)
	light.omni_range = 6.5
	light.light_energy = 1.1
	light.shadow_enabled = false
	root.add_child(light)
	lantern_lights.append(light)


func _build_props() -> void:
	# 柴堆
	for pos: Vector3 in [Vector3(-1.0, 0, 8.6), Vector3(7.6, 0, -6.6), Vector3(-10.8, 0, -2.0)]:
		for i in range(3):
			var log := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.09
			lm.bottom_radius = 0.1
			lm.height = 0.85
			log.mesh = lm
			log.rotation_degrees = Vector3(0, 15.0 * float(i) + 20.0, 90)
			log.position = pos + Vector3(0, 0.11 + 0.19 * float(i / 2), 0)
			log.material_override = _mat(Color(0.3, 0.22, 0.15))
			add_child(log)
	# 村口拒马
	for spec: Array in [
		[Vector3(0.4, 0.95, -16.2), Vector3(0.0, 0.0, 32.0)],
		[Vector3(0.4, 0.95, -16.2), Vector3(0.0, 0.0, -32.0)],
		[Vector3(0.4, 0.55, -16.2), Vector3(0.0, 0.0, 0.0)],
	]:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(2.8, 0.22, 0.22)
		plank.mesh = pm
		plank.position = spec[0]
		plank.rotation_degrees = spec[1]
		plank.material_override = _mat(Color(0.36, 0.27, 0.18))
		add_child(plank)


func _build_grandma() -> void:
	var root := Node3D.new()
	root.position = grandma_local
	root.rotation_degrees.y = 138.0
	add_child(root)

	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.3
	bm.height = 1.25
	body.mesh = bm
	body.position.y = 0.68
	body.material_override = _mat(Color(0.47, 0.5, 0.58))
	root.add_child(body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.34
	head.mesh = hm
	head.position.y = 1.46
	head.material_override = _mat(Color(0.78, 0.64, 0.52))
	root.add_child(head)

	var bun := MeshInstance3D.new()
	var um := SphereMesh.new()
	um.radius = 0.09
	um.height = 0.18
	bun.mesh = um
	bun.position = Vector3(0, 1.62, 0.1)
	bun.material_override = _mat(Color(0.62, 0.62, 0.6))
	root.add_child(bun)

	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.025
	sm.bottom_radius = 0.03
	sm.height = 1.3
	stick.mesh = sm
	stick.position = Vector3(0.4, 0.65, 0.15)
	stick.rotation_degrees.z = -8.0
	stick.material_override = _mat(Color(0.32, 0.24, 0.16))
	root.add_child(stick)

	var plate := Label3D.new()
	plate.text = "陶婆婆"
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.font_size = 42
	plate.outline_size = 12
	plate.pixel_size = 0.006
	plate.position.y = 2.0
	plate.modulate = Color(0.93, 0.85, 0.66)
	if font != null:
		plate.font = font
	root.add_child(plate)


# ---------------------------------------------------------------- 山坳石壁

func _build_rocks() -> void:
	for i in range(14):
		var ang := TAU * float(i) / 14.0 + 0.2
		var r := 27.0 + 6.0 * float(i % 3)
		var pos := Vector3(sin(ang) * r, 0.0, cos(ang) * r)
		if pos.z < -13.0 and absf(pos.x) < 8.0:
			continue   # 村口留豁口
		var size := Vector3(5.0 + float(i % 4) * 1.6, 8.0 + float(i % 3) * 3.0, 5.0 + float(i % 5) * 1.2)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		body.rotation_degrees.y = float(i) * 37.0
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = _mat(Color(0.14, 0.15, 0.18))
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		add_child(body)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
