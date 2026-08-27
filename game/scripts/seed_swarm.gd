extends Node3D
## 星籽群管理：玩家身后环形槽位 + 相互分离 + 噪声浮沉。
## 故意不用 RVO——该规模下 boids 手写即可（见 wuxing 项目实测结论）。

const MAX_SEEDS := 12
const START_SEEDS := 3
const SEED_RETURN_DELAY := 6.0   # 消耗后延迟归还（模拟“飞回来”）
const RING_RADIUS := 0.62
const RING_ELLIPSE_X := 1.3       # 环带稍扁，队形更自然
const FOLLOW_DAMP := 6.5          # 指数趋近速率
const SEP_DIST := 0.32            # 两两分离阈值
const BACK_OFFSET := 1.35         # 锚点落后于玩家的距离
const ANCHOR_HEIGHT := 1.05

const SeedScript := preload("res://scripts/star_seed.gd")

var player_body   # CharacterBody3D（player.gd），留 Duck typing 避免 Type 循环依赖
var auto_start := true   # 序章门控：授火仪式前不发放星籽

var _units: Array[Node3D] = []
var _noises: Array[FastNoiseLite] = []
var _times: Array[float] = []


func _ready() -> void:
	if auto_start:
		add_seed(START_SEEDS)


func seed_count() -> int:
	return _units.size()


## 消耗一颗（投掷等），延迟后自动归还。不足时返回 false。
func consume_one() -> bool:
	if _units.is_empty():
		return false
	var u: Node3D = _units.pop_back()
	u.queue_free()
	_noises.pop_back()
	_times.pop_back()
	get_tree().create_timer(SEED_RETURN_DELAY).timeout.connect(func():
		if is_inside_tree():
			add_seed(1))
	return true


func add_seed(n: int) -> int:
	var added := 0
	for i in range(n):
		if _units.size() >= MAX_SEEDS:
			break
		var idx := _units.size()
		var unit: Node3D = SeedScript.new()
		unit.setup(idx)
		add_child(unit)
		unit.global_position = _anchor_center()
		_units.append(unit)

		var nz := FastNoiseLite.new()
		nz.seed = idx * 401 + 13
		nz.frequency = 1.4
		_noises.append(nz)
		_times.append(randf() * TAU)
		added += 1
	return added


func all_positions_finite() -> bool:
	for u in _units:
		if not u.global_position.is_finite():
			return false
	return true


func _anchor_center() -> Vector3:
	if player_body == null:
		return global_position + Vector3.UP * ANCHOR_HEIGHT
	var back: Vector3 = -player_body.model_root.global_basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		back = Vector3.BACK
	else:
		back = back.normalized()
	return player_body.global_position + back * BACK_OFFSET


func _physics_process(delta: float) -> void:
	if player_body == null or _units.is_empty():
		return
	var n := _units.size()
	var center := _anchor_center()
	var basis := _flat_basis(player_body.model_root.global_basis)

	for i in range(n):
		_times[i] += delta
		var ang := TAU * float(i) / float(n) + _times[i] * 0.55
		var hover: float = _noises[i].get_noise_1d(_times[i] * 3.0) * 0.16
		var local_slot := Vector3(
				cos(ang) * RING_RADIUS * RING_ELLIPSE_X,
				ANCHOR_HEIGHT + hover,
				sin(ang) * RING_RADIUS)
		var target := center + basis * local_slot
		var k := 1.0 - exp(-FOLLOW_DAMP * delta)
		var u := _units[i]
		u.global_position = u.global_position.lerp(target, k)

	_separate()


func _separate() -> void:
	var n := _units.size()
	for i in range(n):
		for j in range(i + 1, n):
			var pa: Vector3 = _units[i].global_position
			var pb: Vector3 = _units[j].global_position
			var d := pb - pa
			d.y *= 0.5
			var dist := d.length()
			if dist < SEP_DIST and dist > 0.0001:
				var push := d / dist * (SEP_DIST - dist) * 0.5
				push.y *= 0.5
				_units[i].global_position -= push
				_units[j].global_position += push


static func _flat_basis(src: Basis) -> Basis:
	var fwd := -src.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return Basis.IDENTITY
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	return Basis(side, Vector3.UP, -fwd)
