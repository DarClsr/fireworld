extends Node
## 自动加载：注册输入映射（全代码定义，避免手写 project.godot 输入序列化出错）。


func _ready() -> void:
	InputDefs.ensure_actions()
