class_name GenProtagonist
extends RefCounted
## 主角官方設定圖 → 遊戲內高解析素材（HD 角色 × 3D 立體場景路線）。
## 來源：docs/character/protagonist-model-sheet.png（使用者提供之原創設定圖）。
## 產出：
##   assets/characters/hero/front|side|back.png —— 全身視圖去背立牌（世界角色）
##   assets/portraits/player_*.png —— 表情頭像高解析直出（對話立繪）
## 設定圖不存在時跳過（世界角色退回 pixgen 圖層、立繪保留舊檔）。

const SHEET := "res://docs/character/protagonist-model-sheet.png"
const WALK_SHEET := "res://docs/character/protagonist-walk-sheet.png"
const HERO_DIR := "res://assets/characters/hero"

## 走路圖：7 排 × 4 幀；取 正面/側面(朝左)/背面 三排（其餘為 ¾ 視圖備用）
const WALK_ROW_DOWN := 0
const WALK_ROW_LEFT := 2
const WALK_ROW_UP := 4
const WALK_FRAME_W := 208
const WALK_FRAME_H := 272
const WALK_TARGET_H := 260

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
	_export_walk()


## 走路圖 → 四幀行走動畫（down/left/up；right 由遊戲內鏡射）。
## 烤死的棋盤格底：先全圖鍵控（雙色調）＋邊框洪水去背，再依透明度自動切排切幀。
static func _export_walk() -> void:
	var path := ProjectSettings.globalize_path(WALK_SHEET)
	if not FileAccess.file_exists(path):
		return
	var sheet := Image.load_from_file(path)
	if sheet == null:
		return
	sheet.convert(Image.FORMAT_RGBA8)
	_key_out_checker(sheet)
	_cutout(sheet)
	# 混合投影分割：先全圖找直欄帶（欄距乾淨），再於每欄內找橫帶（每欄 7 格）
	var w := sheet.get_width()
	var h := sheet.get_height()
	var col_counts: Array[int] = []
	for x in range(w):
		var count := 0
		for y in range(0, h, 3):
			if sheet.get_pixel(x, y).a > 0.5:
				count += 1
		col_counts.append(count)
	var cols := _project_bands(col_counts, 8, 60, 1)
	if cols.size() != 4:
		push_warning("walk sheet: expected 4 columns, got %d" % cols.size())
		return
	var per_column_rows: Array = []
	for col: Vector2i in cols:
		var row_counts: Array[int] = []
		for y in range(h):
			var count := 0
			for x in range(col.x, col.y + 1, 2):
				if sheet.get_pixel(x, y).a > 0.5:
					count += 1
			row_counts.append(count)
		var bands := _project_bands(row_counts, 2, 80, 1)
		per_column_rows.append(_split_tall(bands, row_counts, float(h) / 7.0))
	for col_index in range(4):
		if Array(per_column_rows[col_index]).size() < 5:
			push_warning("walk sheet column %d: expected >=5 rows, got %d" % [col_index, Array(per_column_rows[col_index]).size()])
			return
	var rows := {"down": WALK_ROW_DOWN, "left": WALK_ROW_LEFT, "up": WALK_ROW_UP}
	for dir_name: String in rows:
		var row: int = rows[dir_name]
		var frames: Array[Image] = []
		for col_index in range(4):
			var col: Vector2i = cols[col_index]
			var band := _pick_band(Array(per_column_rows[col_index]), row, h)
			var frame := sheet.get_region(Rect2i(col.x, band.x, col.y - col.x + 1, band.y - band.x + 1))
			var used := frame.get_used_rect()
			if used.size.x > 10 and used.size.y > 10:
				frames.append(frame.get_region(used))
		if frames.size() != 4:
			push_warning("walk sheet row %s: expected 4 frames, got %d" % [dir_name, frames.size()])
			continue
		# 同排統一縮放（保留步態的上下起伏），底部置中對齊
		var max_h := 0
		for frame: Image in frames:
			max_h = maxi(max_h, frame.get_height())
		var scale := float(WALK_TARGET_H) / float(maxi(1, max_h))
		for i in range(frames.size()):
			var frame: Image = frames[i]
			var fw := maxi(1, int(round(float(frame.get_width()) * scale)))
			var fh := maxi(1, int(round(float(frame.get_height()) * scale)))
			frame.resize(fw, fh, Image.INTERPOLATE_LANCZOS)
			var canvas := Image.create(WALK_FRAME_W, WALK_FRAME_H, false, Image.FORMAT_RGBA8)
			canvas.blit_rect(frame, Rect2i(0, 0, fw, fh),
				Vector2i((WALK_FRAME_W - fw) / 2, WALK_FRAME_H - 4 - fh))
			Pix.save(canvas, "%s/walk_%s_%d.png" % [HERO_DIR, dir_name, i])


## 全圖鍵控：移除棋盤格的兩個低彩度色調（暖白襯衫彩度較高，不受影響）
static func _key_out_checker(img: Image) -> void:
	var tone_a := img.get_pixel(2, 2)
	var tone_b := tone_a
	for x in range(4, 80):
		var candidate := img.get_pixel(x, 2)
		if _dist(candidate, tone_a) > 0.03:
			tone_b = candidate
			break
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var color := img.get_pixel(x, y)
			var sat := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
			if sat < 0.08 and (_dist(color, tone_a) < 0.08 or _dist(color, tone_b) < 0.08):
				img.set_pixel(x, y, Color(0, 0, 0, 0))


static func _dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## 相鄰兩排黏成一帶（過高）時，在帶內「最弱掃描線」切開（遞迴至正常高度）
static func _split_tall(bands: Array, counts: Array[int], row_h: float) -> Array:
	var queue: Array = bands.duplicate()
	var out: Array = []
	var guard := 0
	while not queue.is_empty() and guard < 40:
		guard += 1
		var band := Vector2i(queue.pop_front())
		if float(band.y - band.x) > row_h * 1.35:
			var lo := band.x + int(row_h * 0.55)
			var hi := band.y - int(row_h * 0.55)
			if hi > lo:
				var best_y := lo
				var best_count := 1 << 30
				for y in range(lo, hi + 1):
					if counts[y] < best_count:
						best_count = counts[y]
						best_y = y
				queue.push_front(Vector2i(best_y + 1, band.y))
				queue.push_front(Vector2i(band.x, best_y))
				continue
		out.append(band)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return out


## 取第 row 排：依期望中心位置選最近的帶
static func _pick_band(bands: Array, row: int, sheet_h: int) -> Vector2i:
	var row_h := float(sheet_h) / 7.0
	var expected := (float(row) + 0.5) * row_h
	var best := Vector2i(int(float(row) * row_h), int((float(row) + 1.0) * row_h))
	var best_d := 1.0e9
	for band: Variant in bands:
		var b := Vector2i(band)
		var center := float(b.x + b.y) * 0.5
		var d := absf(center - expected)
		if d < best_d:
			best_d = d
			best = b
	return best


## 一維投影帶偵測：counts[i] > threshold 視為內容，間隔 > gap_needed 分段
static func _project_bands(counts: Array[int], gap_needed: int, min_size: int, threshold: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start := -1
	var gap := 0
	for i in range(counts.size()):
		if counts[i] > threshold:
			if start < 0:
				start = i
			gap = 0
		elif start >= 0:
			gap += 1
			if gap > gap_needed:
				if i - gap - start > min_size:
					result.append(Vector2i(start, i - gap))
				start = -1
	if start >= 0 and counts.size() - start > min_size:
		result.append(Vector2i(start, counts.size() - 1))
	return result


## 水平帶偵測：回傳各排的 (y0, y1)
static func _bands(img: Image) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var h := img.get_height()
	var w := img.get_width()
	var start := -1
	var gap := 0
	for y in range(h):
		var opaque := 0
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > 0.5:
				opaque += 1
		if opaque > 2:
			if start < 0:
				start = y
			gap = 0
		elif start >= 0:
			gap += 1
			if gap > 6:
				if y - gap - start > 40:
					result.append(Vector2i(start, y - gap))
				start = -1
	if start >= 0 and h - start > 40:
		result.append(Vector2i(start, h - 1))
	return result


## 帶內直欄切割：回傳去邊後的 4 幀
static func _split_frames(img: Image, band: Vector2i) -> Array[Image]:
	var result: Array[Image] = []
	var w := img.get_width()
	var start := -1
	var gap := 0
	for x in range(w):
		var opaque := 0
		for y in range(band.x, band.y + 1, 2):
			if img.get_pixel(x, y).a > 0.5:
				opaque += 1
		if opaque > 1:
			if start < 0:
				start = x
			gap = 0
		elif start >= 0:
			gap += 1
			if gap > 5:
				_append_frame(img, band, start, x - gap, result)
				start = -1
	if start >= 0:
		_append_frame(img, band, start, w - 1, result)
	return result


static func _append_frame(img: Image, band: Vector2i, x0: int, x1: int, out: Array[Image]) -> void:
	if x1 - x0 < 30:
		return
	var frame := img.get_region(Rect2i(x0, band.x, x1 - x0 + 1, band.y - band.x + 1))
	var used := frame.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		frame = frame.get_region(used)
	out.append(frame)


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
	var target_h := 320
	var target_w := int(round(float(img.get_width()) * float(target_h) / float(img.get_height())))
	img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
	Pix.save(img, path)
