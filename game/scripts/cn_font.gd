class_name CnFont
## 中文字体加载：开发期直接用系统字库（微软雅黑→黑体→宋体）。
## 发行前必须换成随包开源字体（如思源黑体），见 docs/05 风险表。

static var _cached: FontFile = null
static var _tried := false

const CANDIDATES := [
	"C:/Windows/Fonts/msyh.ttc",
	"C:/Windows/Fonts/simhei.ttf",
	"C:/Windows/Fonts/simsun.ttc",
]


static func get_font() -> FontFile:
	if _tried:
		return _cached
	_tried = true
	for p in CANDIDATES:
		if FileAccess.file_exists(p):
			var f := FontFile.new()
			if f.load_dynamic_font(p) == OK:
				_cached = f
				break
	return _cached
