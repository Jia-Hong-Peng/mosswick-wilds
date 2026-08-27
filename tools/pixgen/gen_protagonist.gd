class_name GenProtagonist
extends RefCounted
## 主角官方設定圖 → 遊戲內高解析素材（HD 角色 × 3D 立體場景路線）。
## 來源：docs/character/protagonist-model-sheet.png（使用者提供之原創設定圖）。
## 產出：
##   assets/characters/hero/front|side|back.png —— 全身視圖去背立牌（世界角色）
##   assets/portraits/player_*.png —— 表情頭像高解析直出（對話立繪）
## 設定圖不存在時跳過（世界角色退回 pixgen 圖層、立繪保留舊檔）。

const SHEET := "res://docs/character/protagonist-model-sheet.png"
const HERO_DIR := "res://assets/characters/hero"

## 全身視圖裁切框（1672×941 座標；站立圖 y 38–710，去背後自動修邊）
const BODY_CROPS := {
	"front": Rect2i(615, 30, 295, 685),
	"side": Rect2i(1185, 30, 258, 685),
	"back": Rect2i(1441, 30, 231, 685),
}
## 表情頭像裁切框
const FACE_CROPS := {
	"smile": Rect2i(668, 702, 190, 234),
	"surprised": Rect2i(962, 702, 190, 234),
	"determined": Rect2i(1256, 702, 190, 234),
}
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HERO_DIR))
	for view: String in BODY_CROPS:
		var body := sheet.get_region(Rect2i(BODY_CROPS[view]))
		_cutout(body)
		_trim_save(body, "%s/%s.png" % [HERO_DIR, view])
	var cache := {}
	for expr: String in EXPR_MAP:
		var key: String = EXPR_MAP[expr]
		if not cache.has(key):
			var face := sheet.get_region(Rect2i(FACE_CROPS[key]))
			_cutout(face)
			cache[key] = face
		Pix.save((cache[key] as Image).duplicate(), "res://assets/portraits/player_%s.png" % expr)


## 灰底去背：由邊框洪水填充移除攝影棚灰背景（含輕微漸層與接地陰影），
## 不會挖掉角色內部的淺色（白襯衫）——只有與邊框相連的背景會被移除。
static func _cutout(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	# 背景基準：四角平均
	var bg := Color(0, 0, 0)
	for corner: Vector2i in [Vector2i(1, 1), Vector2i(w - 2, 1), Vector2i(1, h - 2), Vector2i(w - 2, h - 2)]:
		bg += img.get_pixel(corner.x, corner.y)
	bg = Color(bg.r / 4.0, bg.g / 4.0, bg.b / 4.0)
	var visited := PackedByteArray()
	visited.resize(w * h)
	var queue: Array[Vector2i] = []
	for x in range(w):
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in range(h):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var idx := p.y * w + p.x
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		var color := img.get_pixel(p.x, p.y)
		# 灰背景判定：低彩度且亮度接近基準（陰影稍暗也吃進來）
		var sat := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
		var close := absf(color.r - bg.r) + absf(color.g - bg.g) + absf(color.b - bg.b) < 0.34
		if sat < 0.09 and close:
			img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
			queue.append(p + Vector2i(1, 0))
			queue.append(p + Vector2i(-1, 0))
			queue.append(p + Vector2i(0, 1))
			queue.append(p + Vector2i(0, -1))


## 裁掉透明邊、縮到遊戲用高度（240px ≈ 畫面高度的 2×，LINEAR 縮放不需 mipmap）
static func _trim_save(img: Image, path: String) -> void:
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		img = img.get_region(used)
	var target_h := 240
	var target_w := int(round(float(img.get_width()) * float(target_h) / float(img.get_height())))
	img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
	Pix.save(img, path)
