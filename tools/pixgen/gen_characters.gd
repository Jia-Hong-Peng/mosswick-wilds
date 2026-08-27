class_name GenCharacters
extends RefCounted
## 角色表產生器（2.5D 版）：32×48 視覺、16px 佔地。
## 表格 192×192：6 欄（idle、走1–4、替代姿勢）× 4 列（下、上、左、右）。
## 相對 v0.3 的 16×24：全 rig 2×＋加入中間調與側光（art-bible §5、hd2d §6）。

const W := 32
const H := 48
const GROUND := 47

enum Pose { IDLE, W1, W2, W3, W4, ALT }
enum Dir { DOWN, UP, LEFT, RIGHT }


static func generate() -> void:
	_gen("res://assets/characters/player.png", _player_cfg())
	_gen("res://assets/characters/npc_kui.png", _kui_cfg())
	_gen("res://assets/characters/npc_rei.png", _rei_cfg())
	_gen("res://assets/characters/npc_haibo.png", _haibo_cfg())
	_gen("res://assets/characters/npc_xiaoman.png", _xiaoman_cfg())


## 認養師葵姨：頭巾＋圍裙、健朗的身形
static func _kui_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK,
		"hair": Pal.WOOD_DK, "hat": "kerchief", "hat_color": Pal.AMBER, "hat_dark": Pal.AMBER_DK,
		"torso": Pal.MOSS, "torso_lt": Pal.LEAF, "collar": Pal.PAPER,
		"legs": Pal.WOOD, "boots": Pal.WOOD_DK,
		"bag": false, "apron": Pal.SAND, "stout": true,
		"torso_w": 18, "leg_h": 8, "head_h": 15,
	}


static func _player_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK,
		"hair": Pal.WOOD_DK, "hat": "cap", "hat_color": Pal.CORAL, "hat_dark": Pal.BRICK_DK,
		"torso": Pal.SEA_DK, "torso_lt": Pal.SEA, "collar": Pal.FOG,
		"legs": Pal.NIGHT, "boots": Pal.WOOD_DK,
		"bag": true, "torso_w": 16, "leg_h": 10, "head_h": 16,
	}


static func _rei_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK,
		"hair": Pal.NIGHT, "hat": "bun", "hat_color": Pal.NIGHT, "hat_dark": Pal.INK,
		"torso": Pal.STEEL, "torso_lt": Pal.MIST, "collar": Pal.FOG,
		"legs": Pal.SLATE, "boots": Pal.INK,
		"bag": false, "coat": true, "scarf": Pal.FOG,
		"torso_w": 14, "leg_h": 8, "head_h": 16, "glasses": true,
	}


static func _haibo_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN_DK, "skin_dk": Pal.WOOD_LT,
		"hair": Pal.GRAY, "hat": "straw", "hat_color": Pal.SAND_LT, "hat_dark": Pal.SAND_DK,
		"torso": Pal.PAPER, "torso_lt": Pal.FOAM, "collar": Pal.PAPER_DIM,
		"legs": Pal.MIST_DK, "boots": Pal.WOOD,
		"bag": false, "apron": Pal.BRICK, "stout": true,
		"torso_w": 20, "leg_h": 8, "head_h": 14,
	}


static func _xiaoman_cfg() -> Dictionary:
	return {
		"skin": Pal.SKIN, "skin_dk": Pal.SKIN_DK,
		"hair": Pal.NIGHT, "hat": "clip", "hat_color": Pal.CORAL, "hat_dark": Pal.CORAL,
		"torso": Pal.SEA_LT, "torso_lt": Pal.FOAM, "collar": Pal.FOAM,
		"legs": Pal.SLATE, "boots": Pal.AMBER,
		"bag": false, "stripes": true, "kid": true,
		"torso_w": 12, "leg_h": 6, "head_h": 14,
	}


static func _gen(path: String, cfg: Dictionary) -> void:
	var sheet := Pix.img(W * 6, H * 4)
	for dir in range(4):
		for col in range(6):
			var frame := Pix.img(W, H)
			_draw_frame(frame, cfg, dir, col)
			Pix.outline_sprite(frame)
			Pix.blit(sheet, frame, col * W, dir * H)
	Pix.save(sheet, path)


static func _pose_params(col: int) -> Dictionary:
	match col:
		1: return {"lift": 1, "bob": 1, "swing": 2}
		2: return {"lift": 0, "bob": 0, "swing": 0}
		3: return {"lift": 2, "bob": 1, "swing": -2}
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
	var torso_h := 12 if not kid else 10
	var head_h := int(cfg["head_h"])
	var torso_top := GROUND + 1 - leg_h - torso_h - bob
	var head_top := torso_top - head_h + 2
	if dir == Dir.LEFT or dir == Dir.RIGHT:
		_draw_side(c, cfg, dir, torso_top, head_top, leg_h, torso_h, head_h, lift, swing, bob, alt)
	else:
		_draw_front(c, cfg, dir, torso_top, head_top, leg_h, torso_h, head_h, lift, swing, bob, alt)


# ---------- 正面／背面 ----------

static func _draw_front(c: Image, cfg: Dictionary, dir: int, torso_top: int, head_top: int, leg_h: int, torso_h: int, head_h: int, lift: int, swing: int, bob: int, alt: bool) -> void:
	var torso_w := int(cfg["torso_w"])
	var tx := 16 - torso_w / 2
	var facing_down := dir == Dir.DOWN
	var torso: Color = cfg["torso"]
	var torso_lt: Color = cfg["torso_lt"]
	var torso_dk := Color(torso).darkened(0.25)
	# --- 腿 ---
	var leg_top := torso_top + torso_h
	var lw := 4
	var lx := tx + 2
	var rx := tx + torso_w - 2 - lw
	_leg(c, cfg, lx, leg_top, lw, leg_h + bob, lift == 1)
	_leg(c, cfg, rx, leg_top, lw, leg_h + bob, lift == 2)
	# --- 軀幹（左亮右影三階） ---
	Pix.rect(c, tx, torso_top, torso_w, torso_h, torso)
	Pix.rect(c, tx, torso_top, 3, torso_h, torso_lt)
	Pix.rect(c, tx + torso_w - 2, torso_top, 2, torso_h, torso_dk)
	Pix.hline(c, tx, torso_top + torso_h - 1, torso_w, torso_dk)
	if bool(cfg.get("stripes", false)):
		for y in range(torso_top + 2, torso_top + torso_h, 4):
			Pix.hline(c, tx + 1, y, torso_w - 2, Pal.FOAM)
			Pix.hline(c, tx + 1, y + 1, torso_w - 2, Pal.FOAM)
	if bool(cfg.get("coat", false)):
		Pix.rect(c, tx, leg_top, torso_w, 4, torso)
		Pix.rect(c, tx, leg_top + 3, torso_w, 1, torso_dk)
		Pix.vline(c, tx + torso_w / 2, torso_top + 2, torso_h + 3, torso_lt if facing_down else torso)
	if cfg.has("apron") and facing_down:
		Pix.rect(c, tx + 2, torso_top + 4, torso_w - 4, torso_h - 4, cfg["apron"])
		Pix.hline(c, tx + 3, torso_top + 5, torso_w - 6, Pal.BRICK_LT)
		Pix.hline(c, tx + 3, torso_top + torso_h - 2, torso_w - 6, Pal.BRICK_DK)
	if cfg.has("scarf"):
		Pix.rect(c, tx, torso_top, torso_w, 3, cfg["scarf"])
		Pix.rect(c, tx + torso_w - 3, torso_top + 2, 2, 4, cfg["scarf"])
	elif facing_down:
		Pix.rect(c, tx + 2, torso_top, torso_w - 4, 2, cfg["collar"])
	# --- 手臂（前後擺相位相反、非鏡射） ---
	var arm_h := torso_h - 2
	Pix.rect(c, tx - 2, torso_top + 2 + maxi(0, swing), 2, arm_h - absi(swing), torso)
	Pix.px(c, tx - 2, torso_top + 2 + maxi(0, swing), torso_lt)
	Pix.rect(c, tx + torso_w, torso_top + 2 + maxi(0, -swing), 2, arm_h - absi(swing), torso_dk)
	Pix.rect(c, tx - 2, torso_top + arm_h + maxi(0, swing), 2, 2, cfg["skin"])
	Pix.rect(c, tx + torso_w, torso_top + arm_h + maxi(0, -swing), 2, 2, cfg["skin"])
	if alt and facing_down:
		Pix.rect(c, tx + 3, torso_top + torso_h - 3, 3, 2, cfg["skin"])
		Pix.rect(c, tx + torso_w - 6, torso_top + torso_h - 3, 3, 2, cfg["skin"])
	# --- 工具包 ---
	if bool(cfg.get("bag", false)):
		if facing_down:
			Pix.rect(c, tx + torso_w - 2, torso_top + torso_h - 5, 6, 6, Pal.WOOD_LT)
			Pix.rect(c, tx + torso_w - 2, torso_top + torso_h - 5, 6, 2, Pal.WOOD)
			Pix.rect(c, tx + torso_w, torso_top + torso_h - 2, 2, 2, Pal.AMBER)
			for i in range(torso_w - 4):
				Pix.px(c, tx + 2 + i, torso_top + 2 + i / 2, Pal.WOOD_DK)
		else:
			Pix.rect(c, 10, torso_top + 2, 12, 8, Pal.WOOD_LT)
			Pix.rect(c, 10, torso_top + 2, 12, 2, Pal.WOOD)
			Pix.rect(c, 15, torso_top + 6, 2, 2, Pal.AMBER)
	# --- 頭 ---
	var head_w := 16
	var hx := 8
	Pix.rect(c, hx, head_top, head_w, head_h - 2, cfg["skin"])
	Pix.rect(c, hx, head_top + head_h - 4, head_w, 2, cfg["skin_dk"])
	if facing_down:
		Pix.rect(c, hx, head_top, head_w, 4, cfg["hair"])
		Pix.rect(c, hx, head_top + 4, 2, 3, cfg["hair"])
		Pix.rect(c, hx + head_w - 2, head_top + 4, 2, 3, cfg["hair"])
		Pix.px(c, hx + 2, head_top + 1, Color(cfg["hair"]).lightened(0.2))
		var eye_y := head_top + head_h - 8
		if bool(cfg.get("glasses", false)):
			Pix.rect(c, hx + 2, eye_y - 1, 5, 4, Pal.MIST_LT)
			Pix.rect(c, hx + 9, eye_y - 1, 5, 4, Pal.MIST_LT)
		Pix.rect(c, hx + 3, eye_y, 2, 3, Pal.INK)
		Pix.rect(c, hx + 11, eye_y, 2, 3, Pal.INK)
		Pix.px(c, hx + 3, eye_y, Pal.FOAM)
		Pix.px(c, hx + 11, eye_y, Pal.FOAM)
		Pix.px(c, hx + 2, head_top + head_h - 4, cfg["skin_dk"])
		Pix.px(c, hx + head_w - 3, head_top + head_h - 4, cfg["skin_dk"])
	else:
		Pix.rect(c, hx, head_top, head_w, head_h - 4, cfg["hair"])
		Pix.rect(c, hx + 3, head_top + 2, 4, 3, Color(cfg["hair"]).lightened(0.15))
	_hat(c, cfg, dir, hx, head_top, head_w)


# ---------- 側面 ----------

static func _draw_side(c: Image, cfg: Dictionary, dir: int, torso_top: int, head_top: int, leg_h: int, torso_h: int, head_h: int, lift: int, swing: int, bob: int, alt: bool) -> void:
	var torso_w := maxi(10, int(cfg["torso_w"]) - 4)
	var tx := 16 - torso_w / 2
	var flip := dir == Dir.RIGHT
	var torso: Color = cfg["torso"]
	var torso_lt: Color = cfg["torso_lt"]
	var torso_dk := Color(torso).darkened(0.25)
	# --- 腿（剪刀步） ---
	var leg_top := torso_top + torso_h
	var spread := 0
	if lift == 1:
		spread = 4
	elif lift == 2:
		spread = -4
	var front_x := 16 - 2 + spread / 2
	var back_x := front_x - 5 if spread != 0 else front_x - 5
	_leg(c, cfg, back_x, leg_top, 4, leg_h + bob - (2 if spread != 0 else 0), false)
	_leg(c, cfg, front_x, leg_top, 4, leg_h + bob, false)
	# --- 軀幹 ---
	Pix.rect(c, tx, torso_top, torso_w, torso_h, torso)
	if not flip:
		Pix.rect(c, tx, torso_top, 3, torso_h, torso_lt)
		Pix.rect(c, tx + torso_w - 2, torso_top, 2, torso_h, torso_dk)
	else:
		Pix.rect(c, tx + torso_w - 3, torso_top, 3, torso_h, torso_lt)
		Pix.rect(c, tx, torso_top, 2, torso_h, torso_dk)
	if bool(cfg.get("stripes", false)):
		for y in range(torso_top + 2, torso_top + torso_h, 4):
			Pix.hline(c, tx + 1, y, torso_w - 2, Pal.FOAM)
	if bool(cfg.get("coat", false)):
		Pix.rect(c, tx, leg_top, torso_w, 4, torso)
		Pix.rect(c, tx, leg_top + 3, torso_w, 1, torso_dk)
	if cfg.has("scarf"):
		Pix.rect(c, tx, torso_top, torso_w, 3, cfg["scarf"])
	if cfg.has("apron"):
		Pix.rect(c, tx + 2, torso_top + 4, torso_w - 4, torso_h - 2, cfg["apron"])
	# --- 單臂（擺動） ---
	var arm_x := 16 + (2 if flip else -4)
	Pix.rect(c, arm_x, torso_top + 2, 3, torso_h - 4, torso)
	Pix.px(c, arm_x, torso_top + 2, torso_lt)
	Pix.rect(c, arm_x + swing * (1 if flip else -1) / 2, torso_top + torso_h - 3, 3, 2, cfg["skin"])
	# --- 工具包（掛髖） ---
	if bool(cfg.get("bag", false)):
		var bag_x := tx + (torso_w - 2 if not flip else -4)
		Pix.rect(c, bag_x, torso_top + torso_h - 4, 6, 6, Pal.WOOD_LT)
		Pix.rect(c, bag_x, torso_top + torso_h - 4, 6, 2, Pal.WOOD)
		Pix.rect(c, bag_x + 2, torso_top + torso_h, 2, 1, Pal.AMBER)
	# --- 頭（側臉） ---
	var head_w := 14
	var hx := 9 if not flip else 9
	Pix.rect(c, hx, head_top, head_w, head_h - 2, cfg["skin"])
	Pix.rect(c, hx, head_top + head_h - 4, head_w, 2, cfg["skin_dk"])
	var back_hair_x := hx + (head_w - 6 if not flip else 0)
	Pix.rect(c, back_hair_x, head_top, 6, head_h - 4, cfg["hair"])
	Pix.rect(c, hx, head_top, head_w, 4, cfg["hair"])
	var eye_x := hx + (2 if not flip else head_w - 4)
	var eye_y := head_top + head_h - 8
	if bool(cfg.get("glasses", false)):
		Pix.rect(c, eye_x - 1 + (0 if not flip else -1), eye_y - 1, 5, 4, Pal.MIST_LT)
	Pix.rect(c, eye_x, eye_y, 2, 3, Pal.INK)
	Pix.px(c, eye_x, eye_y, Pal.FOAM)
	var nose_x := hx + (-1 if not flip else head_w)
	Pix.rect(c, nose_x, eye_y + 2, 1, 2, cfg["skin"])
	_hat(c, cfg, dir, hx, head_top, head_w)


static func _leg(c: Image, cfg: Dictionary, x: int, top: int, w: int, h: int, lifted: bool) -> void:
	var height := h - (2 if lifted else 0)
	if height <= 0:
		return
	Pix.rect(c, x, top, w, height - 2, cfg["legs"])
	Pix.px(c, x, top, Color(cfg["legs"]).lightened(0.15))
	Pix.rect(c, x, top + height - 2, w, 2, cfg["boots"])


static func _hat(c: Image, cfg: Dictionary, dir: int, hx: int, head_top: int, head_w: int) -> void:
	match String(cfg.get("hat", "")):
		"cap":
			Pix.rect(c, hx, head_top - 1, head_w, 4, cfg["hat_color"])
			Pix.hline(c, hx, head_top - 1, head_w, Color(cfg["hat_color"]).lightened(0.15))
			Pix.hline(c, hx + 1, head_top, 5, Color(cfg["hat_color"]).lightened(0.15))
			if dir == Dir.DOWN:
				Pix.rect(c, hx - 1, head_top + 3, head_w + 2, 2, cfg["hat_dark"])
			elif dir == Dir.LEFT:
				Pix.rect(c, hx - 4, head_top + 3, 8, 2, cfg["hat_dark"])
			elif dir == Dir.RIGHT:
				Pix.rect(c, hx + head_w - 4, head_top + 3, 8, 2, cfg["hat_dark"])
		"straw":
			Pix.rect(c, hx - 4, head_top + 3, head_w + 8, 2, cfg["hat_dark"])
			Pix.rect(c, hx - 4, head_top + 1, head_w + 8, 2, cfg["hat_color"])
			Pix.rect(c, hx + 2, head_top - 3, head_w - 4, 4, cfg["hat_color"])
			Pix.hline(c, hx + 3, head_top - 3, head_w - 6, Pal.SAND)
			Pix.hline(c, hx + 2, head_top, head_w - 4, Pal.SAND_DK)
		"bun":
			if dir != Dir.DOWN:
				var bun_x := 14 if dir == Dir.UP else (8 if dir == Dir.LEFT else 20)
				Pix.rect(c, bun_x, head_top - 2, 6, 4, cfg["hat_color"])
				Pix.px(c, bun_x + 1, head_top - 2, Color(cfg["hat_color"]).lightened(0.2))
		"clip":
			if dir != Dir.UP:
				Pix.rect(c, hx + (2 if dir != Dir.RIGHT else head_w - 4), head_top + 2, 2, 2, cfg["hat_color"])
		"kerchief":
			# 頭巾：包頂＋腦後小結
			Pix.rect(c, hx, head_top - 2, head_w, 5, cfg["hat_color"])
			Pix.hline(c, hx, head_top - 2, head_w, Color(cfg["hat_color"]).lightened(0.15))
			Pix.hline(c, hx, head_top + 2, head_w, cfg["hat_dark"])
			if dir == Dir.UP:
				Pix.rect(c, hx + head_w / 2 - 1, head_top + 3, 3, 3, cfg["hat_dark"])
			elif dir == Dir.LEFT:
				Pix.rect(c, hx + head_w - 2, head_top + 2, 2, 3, cfg["hat_dark"])
			elif dir == Dir.RIGHT:
				Pix.rect(c, hx, head_top + 2, 2, 3, cfg["hat_dark"])
		_:
			pass
