class_name GenCharacters
extends RefCounted
## 角色表產生器：16×24 視覺、16×16 佔地。
## 表格 96×96：6 欄（idle、走1–4、替代姿勢）× 4 列（下、上、左、右）。
## 走路規則（art-bible §5）：接觸—抬升交替、手腳異相、頭部 1px 慣性、
## 腳底貼齊畫布底、自動 INK 外描邊。

const W := 16
const H := 24
const GROUND := 23  # 腳底列

enum Pose { IDLE, W1, W2, W3, W4, ALT }
enum Dir { DOWN, UP, LEFT, RIGHT }


static func generate() -> void:
	_gen("res://assets/characters/player.png", _player_cfg())
	_gen("res://assets/characters/npc_rei.png", _rei_cfg())
	_gen("res://assets/characters/npc_haibo.png", _haibo_cfg())
	_gen("res://assets/characters/npc_xiaoman.png", _xiaoman_cfg())


static func _player_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK,
		"hair": Pal.WOOD_DK, "hat": "cap", "hat_color": Pal.CORAL, "hat_dark": Pal.BRICK_DK,
		"torso": Pal.SEA_DK, "torso_lt": Pal.SEA, "collar": Pal.FOG,
		"legs": Pal.NIGHT, "boots": Pal.WOOD_DK,
		"bag": true, "torso_w": 8, "leg_h": 5, "head_h": 8,
	}


static func _rei_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK,
		"hair": Pal.NIGHT, "hat": "bun", "hat_color": Pal.NIGHT, "hat_dark": Pal.INK,
		"torso": Pal.STEEL, "torso_lt": Pal.MIST, "collar": Pal.FOG,
		"legs": Pal.SLATE, "boots": Pal.INK,
		"bag": false, "coat": true, "scarf": Pal.FOG,
		"torso_w": 7, "leg_h": 4, "head_h": 8, "glasses": true,
	}


static func _haibo_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN_DK, "skin_dk": Pal.WOOD_LT,
		"hair": Pal.GRAY, "hat": "straw", "hat_color": Pal.SAND_LT, "hat_dark": Pal.SAND_DK,
		"torso": Pal.PAPER, "torso_lt": Pal.FOAM, "collar": Pal.PAPER_DIM,
		"legs": Pal.MIST_DK, "boots": Pal.WOOD,
		"bag": false, "apron": Pal.BRICK, "stout": true,
		"torso_w": 10, "leg_h": 4, "head_h": 7,
	}


static func _xiaoman_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK,
		"hair": Pal.NIGHT, "hat": "clip", "hat_color": Pal.CORAL, "hat_dark": Pal.CORAL,
		"torso": Pal.SEA_LT, "torso_lt": Pal.FOAM, "collar": Pal.FOAM,
		"legs": Pal.SLATE, "boots": Pal.AMBER,
		"bag": false, "stripes": true, "kid": true,
		"torso_w": 6, "leg_h": 4, "head_h": 7,
	}


static func _gen(path: String, cfg: Dictionary) -> void:
	var sheet := Pix.img(W * 6, H * 4)
	for dir in range(4):
		for col in range(6):
			var frame := Pix.img(W, H)
			_draw_frame(frame, cfg, dir, col)
			Pix.outline_sprite(frame)
			_bake_shadow(frame)
			Pix.blit(sheet, frame, col * W, dir * H)
	Pix.save(sheet, path)


static func _bake_shadow(frame: Image) -> void:
	for x in range(3, 13):
		var dx := absf(float(x) - 7.5)
		if dx < 4.5:
			Pix.blend(frame, x, GROUND, Pal.INK, 0.2)


## pose 欄位 → 走路參數
## lift: 抬腳側（0 無、1 左腳、2 右腳）；bob: 身體上抬 1px
static func _pose_params(col: int) -> Dictionary:
	match col:
		1: return {"lift": 1, "bob": 1, "swing": 1}
		2: return {"lift": 0, "bob": 0, "swing": 0}
		3: return {"lift": 2, "bob": 1, "swing": -1}
		4: return {"lift": 0, "bob": 0, "swing": 0}
		5: return {"lift": 0, "bob": 0, "swing": 0, "alt": true}
		_: return {"lift": 0, "bob": 0, "swing": 0}


static func _draw_frame(c: Image, cfg: Dictionary, dir: int, col: int) -> void:
	var p := _pose_params(col)
	var bob := int(p["bob"])
	var lift := int(p["lift"])
	var swing := int(p["swing"])
	var alt := bool(p.get("alt", false))
	var kid := bool(cfg.get("kid", false))
	var leg_h := int(cfg["leg_h"])
	var torso_h := 6 if not kid else 5
	var head_h := int(cfg["head_h"])
	if kid:
		leg_h = 3
	var torso_top := GROUND + 1 - leg_h - torso_h - bob
	var head_top := torso_top - head_h + 1
	if dir == Dir.LEFT or dir == Dir.RIGHT:
		_draw_side(c, cfg, dir, torso_top, head_top, leg_h, torso_h, head_h, lift, swing, bob, alt)
	else:
		_draw_front(c, cfg, dir, torso_top, head_top, leg_h, torso_h, head_h, lift, swing, bob, alt)


# ---------- 正面／背面 ----------

static func _draw_front(c: Image, cfg: Dictionary, dir: int, torso_top: int, head_top: int, leg_h: int, torso_h: int, head_h: int, lift: int, swing: int, bob: int, alt: bool) -> void:
	var torso_w := int(cfg["torso_w"])
	var tx := 8 - torso_w / 2
	var facing_down := dir == Dir.DOWN
	# --- 腿 ---
	var leg_top := torso_top + torso_h
	var lw := 2
	var lx := 8 - torso_w / 2 + 1
	var rx := 8 + torso_w / 2 - 1 - lw
	_leg(c, cfg, lx, leg_top, lw, leg_h + bob, lift == 1)
	_leg(c, cfg, rx, leg_top, lw, leg_h + bob, lift == 2)
	# --- 軀幹 ---
	Pix.rect(c, tx, torso_top, torso_w, torso_h, cfg["torso"])
	Pix.vline(c, tx, torso_top, torso_h, cfg["torso_lt"])
	if bool(cfg.get("stripes", false)):
		for y in range(torso_top + 1, torso_top + torso_h, 2):
			Pix.hline(c, tx + 1, y, torso_w - 2, Pal.FOAM)
	if bool(cfg.get("coat", false)):
		Pix.rect(c, tx, leg_top, torso_w, 2, cfg["torso"])
		Pix.vline(c, tx + torso_w / 2, torso_top + 1, torso_h + 1, cfg["torso_lt"] if facing_down else cfg["torso"])
	if cfg.has("apron") and facing_down:
		Pix.rect(c, tx + 1, torso_top + 2, torso_w - 2, torso_h - 2, cfg["apron"])
		Pix.hline(c, tx + 2, torso_top + 3, torso_w - 4, Pal.BRICK_LT)
	if cfg.has("scarf"):
		Pix.hline(c, tx, torso_top, torso_w, cfg["scarf"])
		Pix.px(c, tx + torso_w - 1, torso_top + 1, cfg["scarf"])
	elif facing_down:
		Pix.hline(c, tx + 1, torso_top, torso_w - 2, cfg["collar"])
	# --- 手臂（前後擺相位相反）---
	var arm_h := torso_h - 1
	Pix.vline(c, tx - 1, torso_top + 1 + maxi(0, swing), arm_h - absi(swing), cfg["torso"])
	Pix.vline(c, tx + torso_w, torso_top + 1 + maxi(0, -swing), arm_h - absi(swing), cfg["torso"])
	Pix.px(c, tx - 1, torso_top + arm_h + maxi(0, swing), cfg["skin"])
	Pix.px(c, tx + torso_w, torso_top + arm_h + maxi(0, -swing), cfg["skin"])
	if alt and facing_down:
		# 替代姿勢：雙手向前收攏（互動／接收）
		Pix.px(c, tx + 1, torso_top + torso_h - 1, cfg["skin"])
		Pix.px(c, tx + torso_w - 2, torso_top + torso_h - 1, cfg["skin"])
	# --- 工具包（正面在右髖、背面在背上）---
	if bool(cfg.get("bag", false)):
		if facing_down:
			Pix.rect(c, tx + torso_w - 1, torso_top + torso_h - 2, 3, 3, Pal.WOOD_LT)
			Pix.px(c, tx + torso_w, torso_top + torso_h - 1, Pal.AMBER)
			for i in range(torso_w - 2):
				Pix.px(c, tx + 1 + i, torso_top + 1 + i / 2, Pal.WOOD_DK)
		else:
			Pix.rect(c, 8 - 3, torso_top + 1, 6, 4, Pal.WOOD_LT)
			Pix.hline(c, 8 - 3, torso_top + 1, 6, Pal.WOOD)
			Pix.px(c, 8, torso_top + 3, Pal.AMBER)
	# --- 頭 ---
	var head_w := 8
	var hx := 4
	Pix.rect(c, hx, head_top, head_w, head_h - 1, cfg["skin"])
	if facing_down:
		Pix.hline(c, hx, head_top, head_w, cfg["hair"])
		Pix.hline(c, hx, head_top + 1, head_w, cfg["hair"])
		Pix.px(c, hx, head_top + 2, cfg["hair"])
		Pix.px(c, hx + head_w - 1, head_top + 2, cfg["hair"])
		var eye_y := head_top + head_h - 4
		if bool(cfg.get("glasses", false)):
			Pix.px(c, hx + 1, eye_y, Pal.MIST_LT)
			Pix.px(c, hx + head_w - 2, eye_y, Pal.MIST_LT)
		Pix.px(c, hx + 2, eye_y, Pal.INK)
		Pix.px(c, hx + 5, eye_y, Pal.INK)
		Pix.px(c, hx + 1, head_top + head_h - 2, cfg["skin_dk"])
		Pix.px(c, hx + head_w - 2, head_top + head_h - 2, cfg["skin_dk"])
	else:
		Pix.rect(c, hx, head_top, head_w, head_h - 2, cfg["hair"])
		Pix.px(c, hx + 2, head_top + 2, Color(cfg["hair"]).lightened(0.15))
	_hat(c, cfg, dir, hx, head_top, head_w)


# ---------- 側面 ----------

static func _draw_side(c: Image, cfg: Dictionary, dir: int, torso_top: int, head_top: int, leg_h: int, torso_h: int, head_h: int, lift: int, swing: int, bob: int, alt: bool) -> void:
	var torso_w := maxi(5, int(cfg["torso_w"]) - 2)
	var tx := 8 - torso_w / 2
	var flip := dir == Dir.RIGHT
	# --- 腿（側面剪刀步：前後分開）---
	var leg_top := torso_top + torso_h
	var spread := 0
	if lift == 1:
		spread = 2
	elif lift == 2:
		spread = -2
	var front_x := 8 - 1 + spread / 2
	var back_x := 8 - 1 - spread / 2 - (1 if spread != 0 else 2)
	if spread == 0:
		back_x = front_x - 2
	_leg(c, cfg, back_x, leg_top, 2, leg_h + bob - (1 if spread != 0 else 0), false)
	_leg(c, cfg, front_x, leg_top, 2, leg_h + bob, false)
	# --- 軀幹 ---
	Pix.rect(c, tx, torso_top, torso_w, torso_h, cfg["torso"])
	Pix.vline(c, tx if not flip else tx + torso_w - 1, torso_top, torso_h, cfg["torso_lt"])
	if bool(cfg.get("stripes", false)):
		for y in range(torso_top + 1, torso_top + torso_h, 2):
			Pix.hline(c, tx + 1, y, torso_w - 2, Pal.FOAM)
	if bool(cfg.get("coat", false)):
		Pix.rect(c, tx, leg_top, torso_w, 2, cfg["torso"])
	if cfg.has("scarf"):
		Pix.hline(c, tx, torso_top, torso_w, cfg["scarf"])
	# --- 單臂（擺動）---
	var arm_x := 8 + (1 if flip else -2)
	Pix.vline(c, arm_x, torso_top + 1, torso_h - 2, cfg["torso"])
	Pix.px(c, arm_x + swing * (1 if flip else -1), torso_top + torso_h - 1, cfg["skin"])
	# --- 工具包（側面掛髖）---
	if bool(cfg.get("bag", false)):
		var bag_x := tx + (torso_w - 1 if not flip else -2)
		Pix.rect(c, bag_x, torso_top + torso_h - 2, 3, 3, Pal.WOOD_LT)
		Pix.px(c, bag_x + 1, torso_top + torso_h - 1, Pal.AMBER)
	if cfg.has("apron"):
		Pix.rect(c, tx + 1, torso_top + 2, torso_w - 2, torso_h - 1, cfg["apron"])
	# --- 頭（側臉：單眼、鼻尖）---
	var head_w := 7
	var hx := 4 if not flip else 5
	Pix.rect(c, hx, head_top, head_w, head_h - 1, cfg["skin"])
	var back_hair_x := hx + (head_w - 3 if not flip else 0)
	Pix.rect(c, back_hair_x, head_top, 3, head_h - 2, cfg["hair"])
	Pix.hline(c, hx, head_top, head_w, cfg["hair"])
	Pix.hline(c, hx, head_top + 1, head_w, cfg["hair"])
	var eye_x := hx + (1 if not flip else head_w - 2)
	var eye_y := head_top + head_h - 4
	if bool(cfg.get("glasses", false)):
		Pix.px(c, eye_x + (1 if not flip else -1), eye_y, Pal.MIST_LT)
	Pix.px(c, eye_x, eye_y, Pal.INK)
	var nose_x := hx + (-1 if not flip else head_w)
	Pix.px(c, nose_x, eye_y + 1, cfg["skin"])
	_hat(c, cfg, dir, hx, head_top, head_w)


static func _leg(c: Image, cfg: Dictionary, x: int, top: int, w: int, h: int, lifted: bool) -> void:
	var height := h - (1 if lifted else 0)
	if height <= 0:
		return
	Pix.rect(c, x, top, w, height - 1, cfg["legs"])
	Pix.rect(c, x, top + height - 1, w, 1, cfg["boots"])


static func _hat(c: Image, cfg: Dictionary, dir: int, hx: int, head_top: int, head_w: int) -> void:
	match String(cfg.get("hat", "")):
		"cap":
			Pix.rect(c, hx, head_top, head_w, 2, cfg["hat_color"])
			Pix.hline(c, hx, head_top, head_w, Color(cfg["hat_color"]).lightened(0.15))
			if dir == Dir.DOWN:
				Pix.hline(c, hx, head_top + 2, head_w, cfg["hat_dark"])
			elif dir == Dir.LEFT:
				Pix.hline(c, hx - 2, head_top + 2, 4, cfg["hat_dark"])
			elif dir == Dir.RIGHT:
				Pix.hline(c, hx + head_w - 2, head_top + 2, 4, cfg["hat_dark"])
		"straw":
			Pix.hline(c, hx - 2, head_top + 2, head_w + 4, cfg["hat_dark"])
			Pix.hline(c, hx - 2, head_top + 1, head_w + 4, cfg["hat_color"])
			Pix.rect(c, hx + 1, head_top - 1, head_w - 2, 2, cfg["hat_color"])
			Pix.px(c, hx + 2, head_top - 1, Pal.SAND)
		"bun":
			if dir != Dir.DOWN:
				var bun_x := 7 if dir == Dir.UP else (4 if dir == Dir.LEFT else 10)
				Pix.rect(c, bun_x, head_top - 1, 3, 2, cfg["hat_color"])
		"clip":
			if dir != Dir.UP:
				Pix.px(c, hx + (1 if dir != Dir.RIGHT else head_w - 2), head_top + 1, cfg["hat_color"])
		_:
			pass
