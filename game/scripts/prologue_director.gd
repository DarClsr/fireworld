extends Node
## 序章流程导演（线性协程驱动）：开场喊话 → 三段教学 → 授火仪式 → 领星籽
## → 村口烽火推夜预演 → 告别。stage 字段全程可观测，供冒烟测试与截图演出快进。

enum Stage {
	WAKE, T_MOVE, T_ATTACK, T_ROLL, TO_KILN,
	TALK, CEREMONY, TO_GATE, GATE_LIT, FAREWELL, DONE,
}

var main
var player
var dummy
var swarm
var beacon
var village
var dialogue

var stage: int = Stage.WAKE
var _move_accum := 0.0
var _attacks := 0
var _rolls := 0
var _prev_pos := Vector3.ZERO


func run() -> void:
	_prev_pos = player.global_position
	dummy.damaged.connect(func(_n): _attacks += 1)
	player.rolled.connect(func(): _rolls += 1)

	main.fade_from_black(1.4)
	await _wait_phys(95)

	# 开场喊话
	stage = Stage.WAKE
	player.set_active(false)
	dialogue.start([{"speaker": "陶婆婆", "text":
		"灯芽！日头都落干净了——起来，到院子里活动活动筋骨。"}])
	await dialogue.finished
	player.set_active(true)

	# 移动教学
	stage = Stage.T_MOVE
	main.set_objective("移动：W A S D")
	while _move_accum < 4.0:
		await _wait_phys(1)
		_move_accum += Vector2(player.global_position.x - _prev_pos.x,
				player.global_position.z - _prev_pos.z).length()
		_prev_pos = player.global_position

	# 攻击教学
	stage = Stage.T_ATTACK
	main.set_objective("攻击木桩：左键轻击，右键蓄力重击")
	while _attacks < 3:
		await _wait_phys(1)

	# 翻滚教学
	stage = Stage.T_ROLL
	main.set_objective("翻滚：Shift")
	while _rolls < 2:
		await _wait_phys(1)

	# 去灰窑
	stage = Stage.TO_KILN
	main.set_objective("去灰窑找陶婆婆")
	while player.global_position.distance_to(
			village.to_global(village.grandma_local)) > 2.6:
		await _wait_phys(1)

	# 授火对话
	stage = Stage.TALK
	player.set_active(false)
	dialogue.start([
		{"speaker": "陶婆婆", "text": "来得正好。灶膛里这块火，比你还大几岁。"},
		{"speaker": "陶婆婆", "text": "守灰人的规矩就一条——有人记得，火就不灭。"},
		{"speaker": "陶婆婆", "text": "把手伸出来。往后路黑，你怀里这捧薪火，就是唯一的白天。"},
	])
	await dialogue.finished

	# 仪式演出
	stage = Stage.CEREMONY
	await _play_ceremony()
	swarm.add_seed(3)
	player.set_active(true)
	main.set_objective("星籽已随你！去村口点亮迎宾烽火 [F]")
	stage = Stage.TO_GATE
	dialogue.start([
		{"speaker": "陶婆婆", "text": "三颗星籽认得火气，往后它们跟着你。"},
		{"speaker": "陶婆婆", "text": "去村口把迎宾烽火点了，让老邻居们抬头看看——天，还没塌完。"},
	])
	await dialogue.finished

	# 等玩家点亮烽火
	while not beacon.is_lit():
		await _wait_phys(1)
	stage = Stage.GATE_LIT
	main.push_back_night()
	await _wait_phys(95)

	# 告别
	stage = Stage.FAREWELL
	player.set_active(false)
	dialogue.start([
		{"speaker": "陶婆婆", "text": "看见没，夜是推得开的。去吧，青竹渡的渡船佬还在等火种。"},
		{"speaker": "陶婆婆", "text": "……灶我看着。你只管记得回来的路。"},
	])
	await dialogue.finished
	player.set_active(true)

	stage = Stage.DONE
	main.set_objective("前往青竹渡（建造中）")
	main.show_banner("序章 · 灰窑村  完", "下一站：青竹渡")


# ---------------------------------------------------------------- 仪式演出

func _play_ceremony() -> void:
	player.set_active(false)
	var spark_from: Vector3 = village.to_global(village.kiln_spark_local)
	var cam := Camera3D.new()
	cam.fov = 50.0
	main.add_child(cam)
	cam.global_position = spark_from + Vector3(-2.4, 2.3, 3.6)
	var mid: Vector3 = (spark_from + player.global_position) * 0.5 + Vector3.UP * 1.1
	cam.look_at(mid, Vector3.UP)
	cam.make_current()

	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.095
	sm.height = 0.19
	spark.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.3)
	mat.emission_energy_multiplier = 3.0
	spark.material_override = mat
	main.add_child(spark)
	spark.global_position = spark_from

	var target: Vector3 = player.global_position + Vector3.UP * 1.15
	var setter := func(t: float) -> void:
		var p := spark_from.lerp(target, t)
		p.y += sin(t * PI) * 0.5
		spark.global_position = p
	var tw := create_tween()
	tw.tween_method(setter, 0.0, 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	spark.queue_free()
	player.celebrate_spark()

	await _wait_phys(35)
	player.camera.current = true
	cam.queue_free()


# ---------------------------------------------------------------- 调试接口

## 冒烟/截图快进：把教学计数直接灌满，运行中的协程会自然通过。
func debug_ff_tutorials() -> void:
	_move_accum = 99.0
	_attacks = 99
	_rolls = 99


func _wait_phys(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame
