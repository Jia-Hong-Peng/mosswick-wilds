class_name GenCreaturesHd
extends RefCounted
## 使用者提供之高解析戰鬥立繪／表情集 → 覆蓋 GenCreatures 的程式生成版
## （美術方向 v2；來源在 docs/character/，.gdignore 不進 pck）。
## 來源缺檔時整隻跳過＝自動退回程式生成版，缺圖不擋遊戲。
##
## 覆蓋輸出（幀畫布一律 512×512，戰鬥程式依材質高度自動換算 pixel_size）：
## <id>_front.png（1024×512 兩幀呼吸）、_back/_antic/_attack/_weak/_calm、
## _hit（FOAM 白剪影）、_icon（32）、_mini（16）、rockbadger_shell、
## assets/portraits/<id>_<expr>.png（六表情，331×398 直接縮進 40×48 立繪槽）。

const SRC_DIR := "res://docs/character"

const BATTLE_SHEETS := {
	"sproutwing": "secret_pangolin_battle_sheet_v2.png",
	"emberhorn": "codeql_woodpecker_battle_sheet_v2.png",
	"tidecrest": "code_quality_beaver_battle_sheet_v2.png",
	"rockbadger": "legacy_tortoise_battle_sheet_v2.png",
}
const EXPR_SHEETS := {
	"sproutwing": "secret_pangolin_expressions_v2.png",
	"emberhorn": "codeql_woodpecker_expressions_v2.png",
	"tidecrest": "code_quality_beaver_expressions_v2.png",
}
const SHELL_SHEET := "legacy_tortoise_shell_v2.png"

## NPC 走路圖（7 或 6 列 × 4 欄、灰底棋格）→ 世界圖集（6 欄 × 4 向、128×192 格）
## 來源列序：0=正面(down)、1=背面(up)、2=側面朝左(left)；right 由左向鏡射
const NPC_WALKS := {
	"npc_kui": { "file": "an_walk_sheet_v2.png", "rows": 6 },
	"npc_sang": { "file": "sang_walk_sheet_v2.png", "rows": 7 },
}
const WALK_CELL_W := 128
const WALK_CELL_H := 192
const WALK_FIG_H := 176

## NPC 設定圖：下排 4 表情等分；表情名 → 欄位索引（可多對一）
const NPC_SHEETS := {
	"kui": { "file": "advisor_an_model_sheet_v2.png",
		"map": { "neutral": 0, "smiling": 1, "relieved": 1, "concerned": 2, "observing": 3 } },
	"sang": { "file": "veteran_sang_model_sheet_v2.png",
		"map": { "neutral": 0, "smug": 1, "surprised": 2, "determined": 3 } },
}

const FRAME := 512
const BASELINE := 448          # 腳底基準（0.875×FRAME，與 64px 版的 56/64 一致）
const FIT_W := 481             # 圖形最大寬（0.94×FRAME）
const FIT_H := 410             # 圖形最大高（0.80×FRAME）
## 表情集：2 欄 × 3 列、順序同 GenCreatures.EXPRESSIONS
const EXPRESSIONS: Array[String] = ["neutral", "curious", "happy", "nervous", "determined", "hurt"]


static func generate() -> void:
	for id: String in BATTLE_SHEETS:
		var sheet := _load(String(BATTLE_SHEETS[id]))
		if sheet == null:
			continue
		var half_w := sheet.get_width() / 2
		var front_fig := sheet.get_region(Rect2i(0, 0, half_w, sheet.get_height()))
		var back_fig := sheet.get_region(Rect2i(half_w, 0, half_w, sheet.get_height()))
		_cutout(front_fig)
		_cutout(back_fig)
		front_fig = _trim(front_fig)
		back_fig = _trim(back_fig)
		front_fig = _fit(front_fig)
		back_fig = _fit(back_fig)
		# 前視兩幀（第二幀微沉＝呼吸）
		var front_sheet := Pix.img(FRAME * 2, FRAME)
		Pix.blit(front_sheet, _frame(front_fig, 0, 0), 0, 0)
		Pix.blit(front_sheet, _frame(front_fig, 0, 5), FRAME, 0)
		Pix.save(front_sheet, "res://assets/creatures/%s_front.png" % id)
		Pix.save(_frame(back_fig, 0, 0), "res://assets/creatures/%s_back.png" % id)
		# 姿勢幀：前搖／攻擊／虛弱／安定
		Pix.save(_frame(front_fig, 20, 12), "res://assets/creatures/%s_antic.png" % id)
		Pix.save(_frame(front_fig, -44, 6), "res://assets/creatures/%s_attack.png" % id)
		Pix.save(_dim(_frame(front_fig, 0, 26), 0.45), "res://assets/creatures/%s_weak.png" % id)
		Pix.save(_frame(front_fig, 0, 8), "res://assets/creatures/%s_calm.png" % id)
		# 受擊白剪影
		var hit := _frame(front_fig, 0, 0)
		for y in range(hit.get_height()):
			for x in range(hit.get_width()):
				if hit.get_pixel(x, y).a > 0.5:
					hit.set_pixel(x, y, Pal.FOAM)
				else:
					hit.set_pixel(x, y, Color(0, 0, 0, 0))
		Pix.save(hit, "res://assets/creatures/%s_hit.png" % id)
		# 圖示：方形置中
		var icon_src := _frame(front_fig, 0, 0)
		var icon := icon_src.duplicate() as Image
		icon.resize(32, 32, Image.INTERPOLATE_LANCZOS)
		Pix.save(icon, "res://assets/creatures/%s_icon.png" % id)
		var mini := icon_src.duplicate() as Image
		mini.resize(16, 16, Image.INTERPOLATE_LANCZOS)
		Pix.save(mini, "res://assets/creatures/%s_mini.png" % id)
		print("hd creature: ", id)
	_export_shell()
	_export_portraits()
	_export_npc_portraits()
	_export_npc_walks()


## 馱庫龜「縮甲」特寫
static func _export_shell() -> void:
	var img := _load(SHELL_SHEET)
	if img == null:
		return
	_cutout(img)
	img = _fit(_trim(img))
	Pix.save(_frame(img, 0, 0), "res://assets/creatures/rockbadger_shell.png")


## 表情集：2 欄 × 3 列（列優先），置中裁成 40:48 直式後存檔（保留灰底當立繪底色）
static func _export_portraits() -> void:
	for id: String in EXPR_SHEETS:
		var sheet := _load(String(EXPR_SHEETS[id]))
		if sheet == null:
			continue
		var cell_w := sheet.get_width() / 2
		var cell_h := sheet.get_height() / 3
		for i in range(EXPRESSIONS.size()):
			var col := i % 2
			var row := i / 2
			var inset := 10
			var cell := sheet.get_region(Rect2i(col * cell_w + inset, row * cell_h + inset, cell_w - inset * 2, cell_h - inset * 2))
			var crop_w := int(float(cell.get_height()) * 40.0 / 48.0)
			var crop_x := (cell.get_width() - crop_w) / 2
			var portrait := cell.get_region(Rect2i(crop_x, 0, crop_w, cell.get_height()))
			Pix.save(portrait, "res://assets/portraits/%s_%s.png" % [id, EXPRESSIONS[i]])


## NPC 設定圖下排 4 表情 → 對話立繪（40:48 直式，保留灰底）
static func _export_npc_portraits() -> void:
	for npc: String in NPC_SHEETS:
		var spec: Dictionary = NPC_SHEETS[npc]
		var sheet := _load(String(spec["file"]))
		if sheet == null:
			continue
		var col_w := sheet.get_width() / 4
		var band_y := int(float(sheet.get_height()) * 0.672) + 4
		var band_h := sheet.get_height() - band_y - 4
		var crop_w := int(float(band_h) * 40.0 / 48.0)
		var cache := {}
		for expr: String in Dictionary(spec["map"]):
			var col := int(Dictionary(spec["map"])[expr])
			if not cache.has(col):
				var x := col * col_w + (col_w - crop_w) / 2
				cache[col] = sheet.get_region(Rect2i(x, band_y, crop_w, band_h))
			Pix.save((cache[col] as Image).duplicate(), "res://assets/portraits/%s_%s.png" % [npc, expr])
		print("hd npc portraits: ", npc)


## NPC 走路圖 → 世界圖集（rows: down/up/left/right(鏡射)；欄序 0,1,2,3,1,3）
static func _export_npc_walks() -> void:
	for npc: String in NPC_WALKS:
		var spec: Dictionary = NPC_WALKS[npc]
		var sheet := _load(String(spec["file"]))
		if sheet == null:
			continue
		# 全圖去背後以透明度投影找列帶（來源格高非整數、固定切格會切碎人）
		_cutout(sheet)
		var bands := _alpha_row_bands(sheet)
		if bands.size() < 3:
			print("npc walk 列帶不足，跳過：", npc)
			continue
		var cell_w := sheet.get_width() / 4
		var figs: Array = []
		for row in range(3):
			var band: Vector2i = bands[row]
			var row_figs: Array[Image] = []
			for col in range(4):
				var cell := sheet.get_region(Rect2i(col * cell_w + 4, band.x, cell_w - 8, band.y - band.x))
				row_figs.append(_trim(cell))
			figs.append(row_figs)
		var ref_h := 1
		for col in range(4):
			ref_h = maxi(ref_h, (figs[0][col] as Image).get_height())
		var scale := float(WALK_FIG_H) / float(ref_h)
		var out := Pix.img(WALK_CELL_W * 6, WALK_CELL_H * 4)
		var col_order: Array[int] = [0, 1, 2, 3, 1, 3]
		for dir in range(4):  # 0 down, 1 up, 2 left, 3 right
			var src_row := dir if dir < 3 else 2
			for out_col in range(6):
				var fig := (figs[src_row][col_order[out_col]] as Image).duplicate() as Image
				fig.resize(maxi(1, int(round(fig.get_width() * scale))), maxi(1, int(round(fig.get_height() * scale))), Image.INTERPOLATE_LANCZOS)
				if dir == 3:
					fig.flip_x()
				var x := out_col * WALK_CELL_W + (WALK_CELL_W - fig.get_width()) / 2
				var y := dir * WALK_CELL_H + WALK_CELL_H - 6 - fig.get_height()
				Pix.blit(out, fig, x, y)
		Pix.save(out, "res://assets/characters/%s.png" % npc)
		print("hd npc walk: ", npc, " bands=", bands.size())


## 有不透明像素的連續列 → 列帶（間隙 ≥6px 分段；忽略高度 <40 的雜訊帶）
static func _alpha_row_bands(img: Image) -> Array:
	var bands: Array = []
	var start := -1
	var gap := 0
	for y in range(img.get_height()):
		var has := false
		for x in range(0, img.get_width(), 3):
			if img.get_pixel(x, y).a > 0.05:
				has = true
				break
		if has:
			if start < 0:
				start = y
			gap = 0
		elif start >= 0:
			gap += 1
			if gap >= 6:
				if y - gap - start >= 40:
					bands.append(Vector2i(start, y - gap + 1))
				start = -1
				gap = 0
	if start >= 0 and img.get_height() - start >= 40:
		bands.append(Vector2i(start, img.get_height()))
	return bands


static func _load(file: String) -> Image:
	var path := ProjectSettings.globalize_path("%s/%s" % [SRC_DIR, file])
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


## 邊框洪水去背：低彩度灰（含腳下柔影）視為背景
static func _cutout(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
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
		var sat := maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b))
		var bright := maxf(color.r, maxf(color.g, color.b))
		if sat < 0.10 and bright > 0.3:
			img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
			queue.append(p + Vector2i(1, 0))
			queue.append(p + Vector2i(-1, 0))
			queue.append(p + Vector2i(0, 1))
			queue.append(p + Vector2i(0, -1))


static func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		return img.get_region(used)
	return img


## 等比縮到 FIT_W×FIT_H 內
static func _fit(img: Image) -> Image:
	var scale := minf(float(FIT_W) / float(img.get_width()), float(FIT_H) / float(img.get_height()))
	var out := img.duplicate() as Image
	out.resize(int(round(float(img.get_width()) * scale)), int(round(float(img.get_height()) * scale)), Image.INTERPOLATE_LANCZOS)
	return out


## 圖形放進 512×512 幀：底邊貼齊 BASELINE、水平置中，再加位移
static func _frame(fig: Image, dx: int, dy: int) -> Image:
	var out := Pix.img(FRAME, FRAME)
	var x := (FRAME - fig.get_width()) / 2 + dx
	var y := BASELINE - fig.get_height() + dy
	Pix.blit(out, fig, x, y)
	return out


static func _dim(img: Image, amount: float) -> Image:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var color := img.get_pixel(x, y)
			if color.a > 0.05:
				img.set_pixel(x, y, color.lerp(Pal.SLATE, amount))
	return img
