class_name Pix
extends RefCounted
## 像素繪圖工具箱：所有素材產生器共用。座標皆為像素、整數網格。


static func img(width: int, height: int) -> Image:
	return Image.create_empty(width, height, false, Image.FORMAT_RGBA8)


static func save(image: Image, res_path: String) -> void:
	var global_path := ProjectSettings.globalize_path(res_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	if image.save_png(global_path) != OK:
		push_error("Failed to save " + res_path)
	else:
		print("wrote " + res_path)


## 像素藝術感知 2× 放大（EPX/Scale2x）：保留硬邊、平滑階梯狀斜線。
## 程序像素全是精準色，等值比較即可。
static func scale2x(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var p := src.get_pixel(x, y)
			var a := src.get_pixel(x, maxi(0, y - 1))
			var b := src.get_pixel(mini(w - 1, x + 1), y)
			var c := src.get_pixel(maxi(0, x - 1), y)
			var d := src.get_pixel(x, mini(h - 1, y + 1))
			var e0 := p
			var e1 := p
			var e2 := p
			var e3 := p
			if c == a and c != d and a != b:
				e0 = a
			if a == b and a != c and b != d:
				e1 = b
			if d == c and d != b and c != a:
				e2 = c
			if b == d and b != a and d != c:
				e3 = d
			out.set_pixel(x * 2, y * 2, e0)
			out.set_pixel(x * 2 + 1, y * 2, e1)
			out.set_pixel(x * 2, y * 2 + 1, e2)
			out.set_pixel(x * 2 + 1, y * 2 + 1, e3)
	return out


static func rng(seed_value: int) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


static func px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


## 半透明混色（用於陰影與霧）
static func blend(image: Image, x: int, y: int, color: Color, amount: float) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var base := image.get_pixel(x, y)
	if base.a <= 0.01:
		image.set_pixel(x, y, Color(color.r, color.g, color.b, amount))
	else:
		image.set_pixel(x, y, base.lerp(color, amount))


static func rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(image, xx, yy, color)


static func hline(image: Image, x: int, y: int, w: int, color: Color) -> void:
	rect(image, x, y, w, 1, color)


static func vline(image: Image, x: int, y: int, h: int, color: Color) -> void:
	rect(image, x, y, 1, h, color)


static func outline_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	hline(image, x, y, w, color)
	hline(image, x, y + h - 1, w, color)
	vline(image, x, y, h, color)
	vline(image, x + w - 1, y, h, color)


static func ellipse(image: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (float(xx) - cx) / rx
			var dy := (float(yy) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(image, xx, yy, color)


## 兩色棋盤 dither（唯一允許的漸層手法）
static func dither(image: Image, x: int, y: int, w: int, h: int, color_a: Color, color_b: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(image, xx, yy, color_a if (xx + yy) % 2 == 0 else color_b)


## 決定性隨機斑點（材質破碎感）
static func speckle(image: Image, x: int, y: int, w: int, h: int, color: Color, count: int, seed_value: int) -> void:
	var generator := rng(seed_value)
	for i in range(count):
		px(image, x + generator.randi_range(0, w - 1), y + generator.randi_range(0, h - 1), color)


## 接觸陰影（立物腳下）
static func contact_shadow(image: Image, cx: float, cy: float, rx: float, ry: float, amount: float = 0.35) -> void:
	for yy in range(int(cy - ry), int(cy + ry) + 1):
		for xx in range(int(cx - rx), int(cx + rx) + 1):
			var dx := (float(xx) - cx) / rx
			var dy := (float(yy) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				blend(image, xx, yy, Pal.INK, amount)


## 自動外描邊：透明像素若鄰接不透明像素 → 描 INK
static func outline_sprite(image: Image, color: Color = Pal.INK) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var edges: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a > 0.5:
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and image.get_pixel(nx, ny).a > 0.5:
					edges.append(Vector2i(x, y))
					break
	for cell in edges:
		image.set_pixel(cell.x, cell.y, color)


## 將 src 疊到 dst（跳過透明像素）
static func blit(dst: Image, src: Image, dx: int, dy: int) -> void:
	for y in range(src.get_height()):
		for x in range(src.get_width()):
			var color := src.get_pixel(x, y)
			if color.a > 0.05:
				if color.a < 0.95:
					blend(dst, dx + x, dy + y, color, color.a)
				else:
					px(dst, dx + x, dy + y, color)


static func flipped_h(src: Image) -> Image:
	var out := src.duplicate() as Image
	out.flip_x()
	return out
