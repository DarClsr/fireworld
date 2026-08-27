extends Node3D
## 飘出的伤害数字，升腾淡出后自毁。

var amount := 0.0
var strong := false


func _ready() -> void:
	var lb := Label3D.new()
	lb.text = "-%d" % roundi(amount)
	var col := Color(1.0, 0.62, 0.25)
	if not strong:
		col = Color(1.0, 0.95, 0.85)
	lb.modulate = col
	lb.font_size = 96
	if not strong:
		lb.font_size = 64
	lb.outline_size = 20
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.pixel_size = 0.008
	add_child(lb)

	position.y = randf_range(1.55, 1.78)
	position.x = randf_range(-0.2, 0.2)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y + 0.9, 0.75) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lb, "modulate:a", 0.0, 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
