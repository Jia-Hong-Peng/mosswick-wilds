class_name Gen3D
extends RefCounted
## 2.5D 立體劇場專用貼圖：樹立牌、光暈、God Ray、水面噪聲、
## 遠景剪影帶、天空漸層。全部 Web/Compatibility 可用的預烘焙資產。


static func generate() -> void:
	_tree("res://assets/world3d/tree_a.png", 5)   # 內部繪 16×32，存檔前 Scale2x
	_tree("res://assets/world3d/tree_b.png", 9)
	_halo("res://assets/world3d/light_halo.png")
	_godray("res://assets/world3d/godray.png")
	_water_noise("res://assets/world3d/water_noise.png", 77)
	_far_hills("res://assets/world3d/far_hills.png")
	_far_sea("res://assets/world3d/far_sea.png")
	_blur_foliage("res://assets/world3d/foreground_leaves.png")


## 樹立牌：樹幹＋樹冠合成一張 16×32
static func _tree(path: String, seed_value: int) -> void:
	var c := Pix.img(16, 32)
	# 樹幹（下半）
	Pix.rect(c, 6, 20, 4, 11, Pal.WOOD)
	Pix.vline(c, 6, 20, 11, Pal.WOOD_LT)
	Pix.vline(c, 9, 20, 11, Pal.WOOD_DK)
	Pix.rect(c, 4, 29, 2, 2, Pal.WOOD_DK)
	Pix.rect(c, 10, 29, 3, 2, Pal.WOOD_DK)
	# 樹冠（上半，兩球堆疊）
	Pix.ellipse(c, 8, 12, 7.5, 8.5, Pal.MOSS_DK)
	Pix.ellipse(c, 8, 11, 6.5, 7.5, Pal.MOSS)
	Pix.ellipse(c, 6, 8, 4, 4, Pal.LEAF)
	var r := Pix.rng(seed_value)
	for i in range(8):
		Pix.px(c, r.randi_range(3, 12), r.randi_range(4, 16), Pal.LEAF_LT)
	Pix.px(c, 5, 5, Pal.SPROUT)
	Pix.dither(c, 4, 15, 9, 4, Pal.MOSS, Pal.MOSS_DK)
	Pix.outline_sprite(c)
	Pix.save(Pix.scale2x(c), path)


## 光暈：柔和放射漸層（Alpha Blend 面片用）
static func _halo(path: String) -> void:
	var size := 48
	var c := Pix.img(size, size)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - 23.5, y - 23.5).length() / 24.0
			if d < 1.0:
				var a := clampf((1.0 - d) * (1.0 - d) * 0.55, 0.0, 0.55)
				c.set_pixel(x, y, Color(Pal.AMBER_LT.r, Pal.AMBER_LT.g, Pal.AMBER_LT.b, a))
	c.save_png(ProjectSettings.globalize_path(path))
	print("wrote " + path)


## 預烘焙 God Ray：斜向漸層光束
static func _godray(path: String) -> void:
	var w := 64
	var h := 128
	var c := Pix.img(w, h)
	for y in range(h):
		for x in range(w):
			var center := absf(float(x) - float(w) / 2.0) / (float(w) / 2.0)
			var fade := 1.0 - float(y) / float(h)
			var a := clampf((1.0 - center) * fade * 0.22, 0.0, 0.22)
			c.set_pixel(x, y, Color(Pal.FOG.r, Pal.FOG.g, Pal.FOG.b, a))
	c.save_png(ProjectSettings.globalize_path(path))
	print("wrote " + path)


## 可平鋪水面噪聲（value noise、64×64）
static func _water_noise(path: String, seed_value: int) -> void:
	var size := 64
	var grid := 8
	var r := Pix.rng(seed_value)
	var values: Array[float] = []
	for i in range(grid * grid):
		values.append(r.randf())
	var c := Pix.img(size, size)
	for y in range(size):
		for x in range(size):
			var gx := float(x) / float(size) * grid
			var gy := float(y) / float(size) * grid
			var x0 := int(gx) % grid
			var y0 := int(gy) % grid
			var x1 := (x0 + 1) % grid
			var y1 := (y0 + 1) % grid
			var fx := gx - floorf(gx)
			var fy := gy - floorf(gy)
			fx = fx * fx * (3.0 - 2.0 * fx)
			fy = fy * fy * (3.0 - 2.0 * fy)
			var v := lerpf(
				lerpf(values[y0 * grid + x0], values[y0 * grid + x1], fx),
				lerpf(values[y1 * grid + x0], values[y1 * grid + x1], fx), fy)
			c.set_pixel(x, y, Color(v, v, v, 1.0))
	c.save_png(ProjectSettings.globalize_path(path))
	print("wrote " + path)


## 遠景山影帶（平鋪、低對比）
static func _far_hills(path: String) -> void:
	var w := 256
	var h := 64
	var c := Pix.img(w, h)
	for layer in range(2):
		var base_y := 26 + layer * 14
		var color := Pal.MIST_DK if layer == 1 else Pal.MIST
		var r := Pix.rng(90 + layer)
		var height := 0.0
		for x in range(w):
			if x % 16 == 0:
				height = r.randf_range(4.0, 20.0 - layer * 6.0)
			var top := base_y - int(height * (0.5 + 0.5 * sin(float(x) * 0.05 + layer)))
			for y in range(maxi(top, 0), h):
				if layer == 0 or c.get_pixel(x, y).a < 0.5:
					c.set_pixel(x, y, color)
	# 頂部霧化
	for y in range(h):
		for x in range(w):
			var px := c.get_pixel(x, y)
			if px.a > 0.5 and y < 34:
				c.set_pixel(x, y, px.lerp(Pal.FOG, 0.35))
	c.save_png(ProjectSettings.globalize_path(path))
	print("wrote " + path)


## 遠景海面帶
static func _far_sea(path: String) -> void:
	var w := 256
	var h := 48
	var c := Pix.img(w, h)
	for y in range(h):
		var t := float(y) / float(h)
		var base := Pal.MIST_LT.lerp(Pal.SEA, t)
		for x in range(w):
			c.set_pixel(x, y, base)
	var r := Pix.rng(95)
	for i in range(60):
		var x := r.randi_range(0, w - 10)
		var y := r.randi_range(10, h - 4)
		Pix.hline(c, x, y, r.randi_range(3, 8), Pal.SEA_LT if y < 30 else Pal.SEA_PALE)
	c.save_png(ProjectSettings.globalize_path(path))
	print("wrote " + path)


## 前景遮擋：預模糊葉影（重模糊前景的「預模糊 Sprite」）
static func _blur_foliage(path: String) -> void:
	var w := 128
	var h := 96
	var sharp := Pix.img(w, h)
	var r := Pix.rng(88)
	for i in range(26):
		var cx := r.randf_range(10, w - 10)
		var cy := r.randf_range(10, h - 10)
		var rad := r.randf_range(8, 20)
		Pix.ellipse(sharp, cx, cy, rad, rad * 0.8, Pal.MOSS_DK if i % 2 == 0 else Pal.MOSS)
	# 盒狀模糊 ×3 → 預模糊
	for pass_i in range(3):
		var blurred := Pix.img(w, h)
		for y in range(h):
			for x in range(w):
				var sum := Color(0, 0, 0, 0)
				var count := 0
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var sx := clampi(x + dx, 0, w - 1)
						var sy := clampi(y + dy, 0, h - 1)
						sum += sharp.get_pixel(sx, sy)
						count += 1
				blurred.set_pixel(x, y, sum / float(count))
		sharp = blurred
	sharp.save_png(ProjectSettings.globalize_path(path))
	print("wrote " + path)
