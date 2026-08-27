extends CharacterBody3D
## 灰盒第三人称控制器：SpringArm 相机 + 移动/跳跃 + 拨火棍轻三连/蓄力重击。
## 全代码占位建模；攻击动画用程序化 tween 挥舞。

const SPEED := 6.2
const ACCEL_GROUND := 36.0
const ACCEL_AIR := 11.0
const JUMP_VELOCITY := 4.7
const MOUSE_SENS := 0.0024
const PITCH_MIN_DEG := -62.0
const PITCH_MAX_DEG := 22.0
const ROLL_TIME := 0.34
const ROLL_SPEED := 8.6
const ROLL_CD := 0.65

enum State { MOVE, CHARGE, ATTACK, DODGE }
enum Phase { NONE, WINDUP, ACTIVE, RECOVER }

signal rolled

const LIGHT_STAGES: Array[Dictionary] = [
	{"windup": 0.12, "active": 0.13, "recover": 0.17, "damage": 8.0, "knock": 2.0},
	{"windup": 0.11, "active": 0.12, "recover": 0.17, "damage": 8.0, "knock": 2.2},
	{"windup": 0.15, "active": 0.15, "recover": 0.26, "damage": 15.0, "knock": 4.5},
]
const HEAVY_CFG: Dictionary = {"windup": 0.42, "active": 0.17, "recover": 0.30, "damage": 26.0, "knock": 7.0}
const HEAVY_FULL_CHARGE := 0.85   # 蓄满时长
const HEAVY_MIN_RATIO := 0.45     # 最短松开的威力比例

var state: int = State.MOVE
var phase: int = Phase.NONE

var swarm                       # SeedSwarm，main 注入（投掷消耗用）
var selected_form := 0          # 0 原始 / 1 木
var model_root: Node3D
var cam_yaw: Node3D
var cam_arm: SpringArm3D
var camera: Camera3D
var hitbox: Area3D

var _stage := 0
var _cfg: Dictionary = {}
var _phase_left := 0.0
var _queued_next := false
var _charge_time := 0.0
var _heavy_ratio := 1.0
var _pending_damage := 0.0
var _pending_knock := 0.0
var _pending_heavy := false
var _hit_set: Dictionary = {}
var _swing_tw: Tween
var _debug_move_dir := Vector3.ZERO
var _pitch_deg := -14.0
var _throw_cd := 0.0
var _roll_left := 0.0
var _roll_cd := 0.0
var _roll_dir := Vector3.ZERO
var _active := true
var _invincible := false
var _tip_warm := Color(1.0, 0.72, 0.35)
var _tip_green := Color(0.45, 0.9, 0.35)
var staff_pivot: Node3D
var _tip_mat: StandardMaterial3D
var _tip_rest_energy := 1.6
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	col.shape = cap
	col.position.y = 0.8
	add_child(col)

	_build_model()
	_build_camera()
	_build_hitbox()


func _build_model() -> void:
	model_root = Node3D.new()
	model_root.name = "Model"
	model_root.position.y = 0.05
	add_child(model_root)

	var body_mi := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.5
	body_mi.mesh = body_mesh
	body_mi.position.y = 0.85
	body_mi.material_override = _flat(Color(0.35, 0.42, 0.58))
	model_root.add_child(body_mi)

	# 围巾（一点原色点缀）
	var scarf := MeshInstance3D.new()
	var scarf_mesh := CylinderMesh.new()
	scarf_mesh.top_radius = 0.21
	scarf_mesh.bottom_radius = 0.24
	scarf_mesh.height = 0.1
	scarf.mesh = scarf_mesh
	scarf.position.y = 1.38
	scarf.material_override = _flat(Color(0.72, 0.24, 0.18))
	model_root.add_child(scarf)

	# 两只眼点：萌感 + 一眼看出朝向
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.042
		em.height = 0.084
		eye.mesh = em
		eye.position = Vector3(0.115 * side, 1.27, -0.315)
		eye.material_override = _glow(Color(1.0, 0.97, 0.9), 0.9)
		model_root.add_child(eye)

	# 拨火棍：右手侧立杆，铜色杖头微光
	staff_pivot = Node3D.new()
	staff_pivot.position = Vector3(0.34, 1.02, 0.06)
	staff_pivot.rotation_degrees.z = -16.0
	model_root.add_child(staff_pivot)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.024
	shaft_mesh.bottom_radius = 0.034
	shaft_mesh.height = 1.1
	shaft.mesh = shaft_mesh
	shaft.position.y = 0.42
	shaft.material_override = _metal(Color(0.42, 0.30, 0.19))
	staff_pivot.add_child(shaft)

	var tip := MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.05
	tip_mesh.height = 0.1
	tip.mesh = tip_mesh
	tip.position.y = 1.02
	_tip_mat = StandardMaterial3D.new()
	_tip_mat.albedo_color = Color(0.9, 0.62, 0.3)
	_tip_mat.emission_enabled = true
	_tip_mat.emission = _tip_warm
	_tip_mat.emission_energy_multiplier = _tip_rest_energy
	tip.material_override = _tip_mat
	staff_pivot.add_child(tip)


func _build_camera() -> void:
	cam_yaw = Node3D.new()
	cam_yaw.name = "CamYaw"
	cam_yaw.position.y = 1.5
	add_child(cam_yaw)
	cam_arm = SpringArm3D.new()
	cam_arm.spring_length = 4.3
	cam_arm.margin = 0.25
	cam_arm.collision_mask = 1
	cam_arm.rotation_degrees.x = _pitch_deg
	cam_yaw.add_child(cam_arm)
	camera = Camera3D.new()
	camera.fov = 70.0
	cam_arm.add_child(camera)
	camera.current = true


func _build_hitbox() -> void:
	hitbox = Area3D.new()
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox.collision_layer = 0
	hitbox.collision_mask = 4   # hurtbox 层
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.25, 1.95)
	cs.shape = box
	cs.position = Vector3(0.05, 0.95, -1.2)
	hitbox.add_child(cs)
	add_child(hitbox)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw.rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch_deg = clampf(_pitch_deg - event.relative.y * MOUSE_SENS * rad_to_deg(1.0),
				PITCH_MIN_DEG, PITCH_MAX_DEG)
		cam_arm.rotation_degrees.x = _pitch_deg


func _physics_process(delta: float) -> void:
	_throw_cd = maxf(_throw_cd - delta, 0.0)
	_roll_cd = maxf(_roll_cd - delta, 0.0)
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var mul := _move_scale()
	var wish := Vector3.ZERO
	if _debug_move_dir != Vector3.ZERO:
		wish = _debug_move_dir
	else:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wish = cam_yaw.global_basis * Vector3(iv.x, 0.0, iv.y)
	wish.y = 0.0
	if wish.length_squared() > 1.0:
		wish = wish.normalized()
	var target := wish * SPEED * mul
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	move_and_slide()
	_face_movement(delta)
	_tick_state(delta)
	_tick_hits()


func _face_movement(delta: float) -> void:
	if state == State.DODGE:
		return
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.25:
		return
	if state == State.CHARGE or (state == State.ATTACK and phase != Phase.RECOVER):
		return
	var target_yaw := atan2(flat.x, flat.z) + PI
	model_root.rotation.y = lerp_angle(model_root.rotation.y, target_yaw,
			1.0 - exp(-13.0 * delta))


func _move_scale() -> float:
	match state:
		State.CHARGE:
			return 0.45
		State.DODGE:
			return 0.0
		State.ATTACK:
			match phase:
				Phase.WINDUP:
					return 0.55
				Phase.ACTIVE:
					return 0.15
				Phase.RECOVER:
					return 0.75
	return 1.0


# ---------------------------------------------------------------- 战斗状态机

func _tick_state(delta: float) -> void:
	if not _active:
		return
	match state:
		State.MOVE:
			if Input.is_action_just_pressed("attack_heavy"):
				_begin_charge()
			elif Input.is_action_just_pressed("attack_light"):
				_start_stage(1)
			elif Input.is_action_just_pressed("jump") and is_on_floor():
				velocity.y = JUMP_VELOCITY
			elif Input.is_action_just_pressed("dodge") and is_on_floor() and _roll_cd <= 0.0:
				_start_roll()
			elif Input.is_action_just_pressed("form_raw"):
				_set_form(0)
			elif Input.is_action_just_pressed("form_wood"):
				_set_form(1)
			elif Input.is_action_just_pressed("throw_seed"):
				_do_throw()
		State.DODGE:
			_roll_left -= delta
			var spd := ROLL_SPEED * clampf(_roll_left / ROLL_TIME, 0.25, 1.0)
			velocity.x = _roll_dir.x * spd
			velocity.z = _roll_dir.z * spd
			if _roll_left <= 0.0:
				state = State.MOVE
				_invincible = false
		State.CHARGE:
			_charge_time += delta
			_tip_mat.emission_energy_multiplier = lerpf(_tip_rest_energy, 4.2,
					clampf(_charge_time / HEAVY_FULL_CHARGE, 0.0, 1.0))
			if Input.is_action_just_released("attack_heavy") or not Input.is_action_pressed("attack_heavy"):
				_fire_heavy(clampf(_charge_time / HEAVY_FULL_CHARGE, HEAVY_MIN_RATIO, 1.0))
		State.ATTACK:
			_phase_left -= delta
			if Input.is_action_just_pressed("attack_light") and phase != Phase.WINDUP:
				_queued_next = true
			if _phase_left <= 0.0:
				_advance_phase()


func _begin_charge() -> void:
	state = State.CHARGE
	_charge_time = 0.0
	_kill_swing()
	_swing_tw = create_tween()
	_swing_tw.tween_property(staff_pivot, "rotation",
			Vector3(deg_to_rad(-105.0), deg_to_rad(18.0), deg_to_rad(-10.0)), 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _fire_heavy(ratio: float) -> void:
	_cfg = HEAVY_CFG
	_heavy_ratio = ratio
	_pending_damage = HEAVY_CFG.damage * ratio
	_pending_knock = HEAVY_CFG.knock * ratio
	_pending_heavy = ratio > 0.75
	_enter_windup(HEAVY_CFG.windup,
			Vector3(deg_to_rad(-105.0), deg_to_rad(18.0), deg_to_rad(-10.0)),
			Vector3(deg_to_rad(28.0), deg_to_rad(-6.0), deg_to_rad(-24.0)))


func _start_stage(stage: int) -> void:
	if stage < 1 or stage > LIGHT_STAGES.size():
		return
	state = State.ATTACK
	_stage = stage
	_cfg = LIGHT_STAGES[stage - 1]
	_pending_damage = _cfg.damage
	_pending_knock = _cfg.knock
	_pending_heavy = stage >= 3
	var from_pose: Vector3
	var to_pose: Vector3
	match stage:
		1:
			from_pose = Vector3(0, deg_to_rad(72.0), deg_to_rad(-30.0))
			to_pose = Vector3(0, deg_to_rad(-78.0), deg_to_rad(-16.0))
		2:
			from_pose = Vector3(0, deg_to_rad(-78.0), deg_to_rad(-16.0))
			to_pose = Vector3(0, deg_to_rad(66.0), deg_to_rad(-30.0))
		_:
			from_pose = Vector3(deg_to_rad(-118.0), deg_to_rad(10.0), deg_to_rad(-14.0))
			to_pose = Vector3(deg_to_rad(26.0), deg_to_rad(-6.0), deg_to_rad(-26.0))
	_enter_windup(_cfg.windup, from_pose, to_pose)


func _enter_windup(windup: float, from_pose: Vector3, to_pose: Vector3) -> void:
	state = State.ATTACK
	phase = Phase.WINDUP
	_phase_left = windup
	_queued_next = false
	_kill_swing()
	_swing_tw = create_tween()
	_swing_tw.tween_property(staff_pivot, "rotation", from_pose, maxf(windup, 0.01)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swing_tw.finished.connect(func(): _on_windup_done(to_pose), CONNECT_ONE_SHOT)


func _on_windup_done(to_pose: Vector3) -> void:
	if state != State.ATTACK or phase != Phase.WINDUP:
		return
	phase = Phase.ACTIVE
	var active_dur: float = maxf(float(_cfg.get("active", 0.13)), 0.01)
	_phase_left = active_dur
	_hit_set.clear()
	hitbox.monitoring = true
	_kill_swing()
	_swing_tw = create_tween()
	_swing_tw.tween_property(staff_pivot, "rotation", to_pose, active_dur) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _advance_phase() -> void:
	match phase:
		Phase.WINDUP:
			pass   # 由 tween finished 驱动，到点兜底
			phase = Phase.ACTIVE
			_phase_left = float(_cfg.get("active", 0.13))
			_hit_set.clear()
			hitbox.monitoring = true
		Phase.ACTIVE:
			phase = Phase.RECOVER
			_phase_left = float(_cfg.get("recover", 0.2))
			hitbox.monitoring = false
			var rest := Vector3(0.0, 0.0, deg_to_rad(-16.0))
			_kill_swing()
			_swing_tw = create_tween()
			_swing_tw.tween_property(staff_pivot, "rotation", rest,
					float(_cfg.get("recover", 0.2))) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		Phase.RECOVER:
			if _queued_next and _stage < LIGHT_STAGES.size():
				_start_stage(_stage + 1)
			else:
				_back_to_move()


func _back_to_move() -> void:
	state = State.MOVE
	phase = Phase.NONE
	hitbox.monitoring = false
	_tip_mat.emission_energy_multiplier = _tip_rest_energy
	_stage = 0
	_queued_next = false


func _tick_hits() -> void:
	if state != State.ATTACK or phase != Phase.ACTIVE:
		return
	for area in hitbox.get_overlapping_areas():
		var target := area.get_parent()
		if target != null and target.has_method("receive_hit"):
			var id: int = target.get_instance_id()
			if not _hit_set.has(id):
				_hit_set[id] = true
				var dir: Vector3 = target.global_position - global_position
				dir.y = 0.0
				if dir.length_squared() > 0.0001:
					dir = dir.normalized()
				target.receive_hit(_pending_damage, dir, _pending_knock, _pending_heavy)


func _kill_swing() -> void:
	if _swing_tw != null and _swing_tw.is_valid():
		_swing_tw.kill()


# ---------------------------------------------------------------- 形态与投掷

func _set_form(form: int) -> void:
	selected_form = form
	if form == 1:
		_tip_mat.emission = _tip_green
	else:
		_tip_mat.emission = _tip_warm


func _do_throw() -> void:
	if selected_form != 1 or _throw_cd > 0.0 or swarm == null:
		return
	if not swarm.consume_one():
		return
	_throw_cd = 0.8
	var info := _resolve_throw_target()
	_spawn_flying_seed(info.target, info.anchor)


func _resolve_throw_target() -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_basis.z
	var best_node = null
	var best_dist := 2.8
	for a in get_tree().get_nodes_in_group("vine_anchor"):
		var to_a: Vector3 = a.global_position - origin
		var t: float = clampf(to_a.dot(dir), 1.5, 16.0)
		var closest: Vector3 = origin + dir * t
		var d: float = closest.distance_to(a.global_position)
		if d < best_dist:
			best_dist = d
			best_node = a
	if best_node != null:
		return {"target": best_node.global_position + Vector3(0, 0.95, 0), "anchor": best_node}
	return {"target": origin + dir * 10.0, "anchor": null}


func _spawn_flying_seed(target: Vector3, anchor) -> void:
	var start: Vector3 = swarm.global_position + Vector3.UP * 1.1
	var flyer := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	flyer.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.85, 0.35)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.9, 0.35)
	m.emission_energy_multiplier = 1.4
	flyer.material_override = m
	add_child(flyer)
	flyer.global_position = start

	var setter := func(t: float) -> void:
		var p := start.lerp(target, t)
		p.y += sin(t * PI) * 1.1
		flyer.global_position = p
	var tw := create_tween()
	tw.tween_method(setter, 0.0, 1.0, 0.38)
	tw.tween_callback(func():
		flyer.queue_free()
		if anchor != null and anchor.has_meta("bridge"):
			var bridge_node = anchor.get_meta("bridge")
			if bridge_node != null and bridge_node.has_method("notify_seed_hit"):
				bridge_node.notify_seed_hit())


func debug_throw() -> void:
	cancel_to_move()
	_set_form(1)
	_do_throw()


func debug_roll() -> void:
	if state == State.MOVE:
		_roll_cd = 0.0
		_start_roll()


func celebrate_spark() -> void:
	var tw := create_tween()
	tw.tween_property(_tip_mat, "emission_energy_multiplier", 5.0, 0.25)
	tw.tween_interval(0.4)
	tw.tween_property(_tip_mat, "emission_energy_multiplier", _tip_rest_energy, 0.8)


func set_active(v: bool) -> void:
	_active = v
	if not v:
		cancel_to_move()


func is_invincible() -> bool:
	return _invincible


func _start_roll() -> void:
	var wish := Vector3.ZERO
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	wish = cam_yaw.global_basis * Vector3(iv.x, 0.0, iv.y)
	wish.y = 0.0
	if wish.length_squared() < 0.01:
		wish = -model_root.global_basis.z
		wish.y = 0.0
	if wish.length_squared() < 0.01:
		wish = Vector3.BACK
	_roll_dir = wish.normalized()
	_roll_left = ROLL_TIME
	_roll_cd = ROLL_TIME + ROLL_CD
	_invincible = true
	_kill_swing()
	_hit_set.clear()
	hitbox.monitoring = false
	state = State.DODGE
	phase = Phase.NONE
	var body_tween := create_tween()
	body_tween.tween_property(model_root, "rotation:x", TAU, ROLL_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	body_tween.tween_callback(func(): model_root.rotation.x = 0.0)
	rolled.emit()


# ---------------------------------------------------------------- 测试接口

func cancel_to_move() -> void:
	_kill_swing()
	_debug_move_dir = Vector3.ZERO
	_back_to_move()


func debug_attack(heavy: bool) -> void:
	cancel_to_move()
	if heavy:
		_cfg = HEAVY_CFG
		_fire_heavy(1.0)
		_phase_left = 0.12   # 压缩蓄力起手，测试确定性
	else:
		_start_stage(1)


func debug_set_move(world_dir: Vector3) -> void:
	if world_dir == Vector3.ZERO:
		_debug_move_dir = Vector3.ZERO
	else:
		_debug_move_dir = world_dir.normalized()


func debug_clear_move() -> void:
	_debug_move_dir = Vector3.ZERO


# ---------------------------------------------------------------- 材质小工具

func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _metal(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.65
	m.roughness = 0.45
	return m
