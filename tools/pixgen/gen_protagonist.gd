class_name GenProtagonist
extends RefCounted
## 主角官方設定圖 → 對話立繪。
## 來源：docs/character/protagonist-model-sheet.png（使用者提供之原創角色設定圖，
## 依本專案原創性規範產出；見 docs/asset-licenses.md）。
## 流程：裁切底部三個表情頭像 → LANCZOS 縮至 40×48 → 灰底去背 →
## 量化回全域色盤（GLITCH 系除外）→ INK 描邊——與其他 pixgen 立繪同語言。
## 設定圖不存在時跳過，保留 pixgen 程序立繪。

const SHEET := "res://docs/character/protagonist-model-sheet.png"
const OUT := "res://assets/portraits/player_%s.png"

## 表情頭像在設定圖上的裁切框（1672×941 座標）
const CROPS := {
	"smile": Rect2i(668, 702, 190, 234),
	"surprised": Rect2i(962, 702, 190, 234),
	"determined": Rect2i(1256, 702, 190, 234),
}
## 遊戲表情 → 設定圖頭像
const EXPR_MAP := {
	"neutral": "smile", "happy": "smile", "thinking": "smile",
	"surprised": "surprised", "worried": "surprised",
	"determined": "determined", "focused": "determined",
}


static func generate() -> void:
	var path := ProjectSettings.globalize_path(SHEET)
	if not FileAccess.file_exists(path):
		return
	var sheet := Image.load_from_file(path)
	if sheet == null:
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var cache := {}
	for expr: String in EXPR_MAP:
		var key: String = EXPR_MAP[expr]
		if not cache.has(key):
			cache[key] = _make_portrait(sheet, Rect2i(CROPS[key]))
		Pix.save((cache[key] as Image).duplicate(), OUT % expr)


static func _make_portrait(sheet: Image, crop: Rect2i) -> Image:
	var region := sheet.get_region(crop)
	region.resize(40, 48, Image.INTERPOLATE_LANCZOS)
	# 灰底去背：以四角平均色為背景基準
	var bg := Color(0, 0, 0)
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 47), Vector2i(39, 47)]:
		bg += region.get_pixel(corner.x, corner.y)
	bg = Color(bg.r / 4.0, bg.g / 4.0, bg.b / 4.0)
	for y in range(48):
		for x in range(40):
			var color := region.get_pixel(x, y)
			if _dist(color, bg) < 0.1:
				region.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				region.set_pixel(x, y, _nearest(color))
	Pix.outline_sprite(region)
	return region


static func _dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## 最近色量化（排除異常紫紅——GLITCH 只留給異常訊號）
static func _nearest(color: Color) -> Color:
	var best := Pal.INK
	var best_d := 99.0
	for entry: Variant in Pal.ORDER:
		var name := String(Array(entry)[0])
		if name.begins_with("GLITCH"):
			continue
		var candidate: Color = Array(entry)[1]
		var d := _dist(color, candidate)
		if d < best_d:
			best_d = d
			best = candidate
	return best
