extends SceneTree
## Generates every original placeholder pixel-art asset (consistent palette,
## 16x16 tile density). Re-run after tweaking; output PNGs are committed so
## the project opens without running this tool.
##
##   godot --headless --path . --script res://tools/generate_placeholders.gd

## Tile order must match WorldScene.TILE_ORDER: G T P W R B F I D S M
const TILE_ORDER := "GTPWRBFIDSM"

const COL_GRASS := Color("79b356")
const COL_GRASS_DARK := Color("69a34a")
const COL_TUFT := Color("3f7d3b")
const COL_PATH := Color("d8b978")
const COL_PATH_DARK := Color("c2a05e")
const COL_WATER := Color("4d7fce")
const COL_WATER_LIGHT := Color("7ba7e0")
const COL_TRUNK := Color("7a5230")
const COL_CROWN := Color("2f6b33")
const COL_CROWN_LIGHT := Color("3f8542")
const COL_WALL := Color("b38a66")
const COL_WALL_DARK := Color("96714f")
const COL_FLOOR := Color("caa36f")
const COL_FLOOR_DARK := Color("b58e5c")
const COL_IWALL := Color("9a8b7a")
const COL_IWALL_DARK := Color("7f7060")
const COL_DOOR := Color("5d3d28")
const COL_BOARD := Color("a9805a")
const COL_INK := Color("4a3320")
const COL_MAT := Color("b45140")
const COL_MAT_DARK := Color("8e3a2c")
const COL_SKIN := Color("e8c49a")
const COL_LEGS := Color("3a3a4a")
const COL_EYE := Color("22222a")


func _initialize() -> void:
	_gen_tileset()
	_gen_character("res://assets/characters/player.png", Color("2f6f4f"), Color("6b4a2f"))
	_gen_character("res://assets/characters/npc_bram.png", Color("3a5f9e"), Color("2e2a26"))
	_gen_character("res://assets/characters/npc_alder.png", Color("d8d8d0"), Color("8f8f8f"))
	_gen_character("res://assets/characters/npc_ida.png", Color("7a4f8e"), Color("e5e0da"))
	_gen_peatpaw()
	_gen_cindermoth()
	_gen_drippole()
	_gen_ui()
	_gen_icon()
	print("Placeholder assets generated.")
	quit(0)


func _img(width: int, height: int) -> Image:
	return Image.create_empty(width, height, false, Image.FORMAT_RGBA8)


func _save(image: Image, res_path: String) -> void:
	var global_path := ProjectSettings.globalize_path(res_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var err := image.save_png(global_path)
	if err != OK:
		push_error("Failed to save " + res_path)
	else:
		print("wrote " + res_path)


func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < image.get_width() and yy < image.get_height():
				image.set_pixel(xx, yy, color)


func _ellipse(image: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
			if xx < 0 or yy < 0 or xx >= image.get_width() or yy >= image.get_height():
				continue
			var dx := (float(xx) - cx) / rx
			var dy := (float(yy) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				image.set_pixel(xx, yy, color)


func _px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


func _gen_tileset() -> void:
	var image := _img(16 * TILE_ORDER.length(), 16)
	for i in range(TILE_ORDER.length()):
		_draw_tile(image, i * 16, TILE_ORDER[i])
	_save(image, "res://assets/tilesets/overworld.png")


func _draw_tile(image: Image, ox: int, symbol: String) -> void:
	match symbol:
		"G":
			_rect(image, ox, 0, 16, 16, COL_GRASS)
			for p: Vector2i in [Vector2i(3, 4), Vector2i(11, 2), Vector2i(7, 9), Vector2i(13, 12), Vector2i(2, 13)]:
				_px(image, ox + p.x, p.y, COL_GRASS_DARK)
		"T":
			_rect(image, ox, 0, 16, 16, COL_GRASS_DARK)
			for x: int in [2, 5, 8, 11, 14]:
				_rect(image, ox + x, 3, 1, 11, COL_TUFT)
				_rect(image, ox + x - 1, 6, 1, 8, COL_TUFT)
		"P":
			_rect(image, ox, 0, 16, 16, COL_PATH)
			for p: Vector2i in [Vector2i(4, 3), Vector2i(10, 6), Vector2i(6, 11), Vector2i(13, 13), Vector2i(1, 8)]:
				_px(image, ox + p.x, p.y, COL_PATH_DARK)
		"W":
			_rect(image, ox, 0, 16, 16, COL_WATER)
			_rect(image, ox + 2, 4, 6, 1, COL_WATER_LIGHT)
			_rect(image, ox + 9, 10, 5, 1, COL_WATER_LIGHT)
		"R":
			_rect(image, ox, 0, 16, 16, COL_GRASS)
			_rect(image, ox + 6, 10, 4, 6, COL_TRUNK)
			_ellipse(image, float(ox) + 8.0, 6.0, 7.0, 5.5, COL_CROWN)
			_ellipse(image, float(ox) + 6.5, 4.5, 3.0, 2.2, COL_CROWN_LIGHT)
		"B":
			_rect(image, ox, 0, 16, 16, COL_WALL)
			for y: int in [0, 5, 10, 15]:
				_rect(image, ox, y, 16, 1, COL_WALL_DARK)
			_rect(image, ox + 5, 1, 1, 4, COL_WALL_DARK)
			_rect(image, ox + 11, 6, 1, 4, COL_WALL_DARK)
		"F":
			_rect(image, ox, 0, 16, 16, COL_FLOOR)
			for y: int in [3, 7, 11, 15]:
				_rect(image, ox, y, 16, 1, COL_FLOOR_DARK)
			_px(image, ox + 4, 1, COL_FLOOR_DARK)
			_px(image, ox + 12, 9, COL_FLOOR_DARK)
		"I":
			_rect(image, ox, 0, 16, 16, COL_IWALL)
			for y: int in [0, 4, 8, 12]:
				_rect(image, ox, y, 16, 1, COL_IWALL_DARK)
			_rect(image, ox + 7, 1, 1, 3, COL_IWALL_DARK)
			_rect(image, ox + 3, 9, 1, 3, COL_IWALL_DARK)
		"D":
			_rect(image, ox, 0, 16, 16, COL_WALL)
			_rect(image, ox + 3, 3, 10, 13, COL_TRUNK)
			_rect(image, ox + 4, 4, 8, 12, COL_DOOR)
			_px(image, ox + 11, 10, Color("e8c46a"))
		"S":
			_rect(image, ox, 0, 16, 16, COL_GRASS)
			_rect(image, ox + 7, 9, 2, 6, COL_TRUNK)
			_rect(image, ox + 3, 3, 10, 6, COL_BOARD)
			_rect(image, ox + 4, 5, 8, 1, COL_INK)
			_rect(image, ox + 4, 7, 6, 1, COL_INK)
		"M":
			_rect(image, ox, 0, 16, 16, COL_FLOOR)
			_rect(image, ox + 2, 2, 12, 12, COL_MAT_DARK)
			_rect(image, ox + 3, 3, 10, 10, COL_MAT)
			_rect(image, ox + 5, 5, 6, 6, COL_MAT_DARK)
		_:
			_rect(image, ox, 0, 16, 16, Color.BLACK)


## 2 cols (stand, step) x 4 rows (down, up, left, right), 16x16 each.
func _gen_character(res_path: String, tunic: Color, hair: Color) -> void:
	var image := _img(32, 64)
	for row in range(4):
		for frame in range(2):
			_draw_char_frame(image, frame * 16, row * 16, row, frame == 1, tunic, hair)
	_save(image, res_path)


func _draw_char_frame(image: Image, ox: int, oy: int, dir_row: int, stepping: bool, tunic: Color, hair: Color) -> void:
	var tunic_dark := tunic.darkened(0.25)
	# Legs.
	var left_off := 1 if stepping else 0
	var right_off := 0 if stepping else 0
	_rect(image, ox + 5, oy + 12 - left_off, 2, 3 + left_off, COL_LEGS)
	_rect(image, ox + 9, oy + 12 - right_off, 2, 3 + right_off, COL_LEGS)
	# Body and arms.
	_rect(image, ox + 4, oy + 8, 8, 5, tunic)
	_rect(image, ox + 3, oy + 8, 1, 4, tunic_dark)
	_rect(image, ox + 12, oy + 8, 1, 4, tunic_dark)
	# Head.
	_rect(image, ox + 4, oy + 2, 8, 6, COL_SKIN)
	match dir_row:
		0:  # down
			_rect(image, ox + 4, oy + 1, 8, 2, hair)
			_px(image, ox + 6, oy + 5, COL_EYE)
			_px(image, ox + 9, oy + 5, COL_EYE)
		1:  # up
			_rect(image, ox + 4, oy + 1, 8, 5, hair)
		2:  # left
			_rect(image, ox + 4, oy + 1, 8, 2, hair)
			_rect(image, ox + 10, oy + 3, 2, 4, hair)
			_px(image, ox + 5, oy + 5, COL_EYE)
		3:  # right
			_rect(image, ox + 4, oy + 1, 8, 2, hair)
			_rect(image, ox + 4, oy + 3, 2, 4, hair)
			_px(image, ox + 10, oy + 5, COL_EYE)


func _gen_peatpaw() -> void:
	var image := _img(32, 32)
	var fur := Color("8a6f47")
	var fur_dark := Color("6d5636")
	var moss := Color("5d8f4a")
	# Body.
	_ellipse(image, 16, 20, 11, 9, fur_dark)
	_ellipse(image, 16, 20, 10, 8, fur)
	# Moss back.
	_ellipse(image, 16, 15, 8, 4, moss)
	_ellipse(image, 12, 14, 3, 2, Color("6fa35a"))
	# Head.
	_ellipse(image, 16, 11, 8, 7, fur_dark)
	_ellipse(image, 16, 11, 7, 6, fur)
	# Ears.
	_rect(image, 8, 3, 4, 4, fur_dark)
	_rect(image, 20, 3, 4, 4, fur_dark)
	_rect(image, 9, 4, 2, 2, moss)
	_rect(image, 21, 4, 2, 2, moss)
	# Face.
	_px(image, 12, 10, COL_EYE)
	_px(image, 19, 10, COL_EYE)
	_rect(image, 15, 12, 2, 2, COL_EYE)
	# Claws.
	for x: int in [8, 11, 20, 23]:
		_px(image, x, 28, Color("e5e0da"))
	_save(image, "res://assets/creatures/peatpaw.png")


func _gen_cindermoth() -> void:
	var image := _img(32, 32)
	var wing := Color("e8863a")
	var wing_dark := Color("c2611f")
	var body := Color("6b6570")
	# Wings.
	_ellipse(image, 9, 15, 8, 11, wing_dark)
	_ellipse(image, 9, 15, 7, 10, wing)
	_ellipse(image, 23, 15, 8, 11, wing_dark)
	_ellipse(image, 23, 15, 7, 10, wing)
	_ellipse(image, 8, 13, 2, 3, Color("f7c04a"))
	_ellipse(image, 24, 13, 2, 3, Color("f7c04a"))
	_px(image, 7, 22, Color("d64f2a"))
	_px(image, 25, 22, Color("d64f2a"))
	# Body.
	_ellipse(image, 16, 17, 4, 9, Color("504a55"))
	_ellipse(image, 16, 17, 3, 8, body)
	# Head and antennae.
	_ellipse(image, 16, 7, 4, 4, body)
	_px(image, 14, 6, Color("f7c04a"))
	_px(image, 18, 6, Color("f7c04a"))
	_rect(image, 12, 2, 1, 3, body)
	_rect(image, 19, 2, 1, 3, body)
	_px(image, 11, 1, wing)
	_px(image, 20, 1, wing)
	_save(image, "res://assets/creatures/cindermoth.png")


func _gen_drippole() -> void:
	var image := _img(32, 32)
	var skin := Color("58a8dc")
	var skin_dark := Color("3f83b8")
	# Tail fin.
	for i in range(6):
		_rect(image, 23 + i, 14 + i, 2, 10 - i * 2, skin_dark)
	# Body (teardrop).
	_ellipse(image, 14, 18, 10, 9, skin_dark)
	_ellipse(image, 14, 18, 9, 8, skin)
	_rect(image, 12, 7, 4, 6, skin)
	_px(image, 13, 5, Color("9fd3ef"))
	_px(image, 14, 4, Color("9fd3ef"))
	# Face.
	_ellipse(image, 10, 16, 3, 3, Color.WHITE)
	_px(image, 10, 16, COL_EYE)
	_px(image, 11, 16, COL_EYE)
	_rect(image, 9, 21, 5, 1, skin_dark)
	# Belly sheen.
	_ellipse(image, 16, 22, 4, 3, Color("7fc0e8"))
	_save(image, "res://assets/creatures/drippole.png")


func _gen_ui() -> void:
	_gen_arrow("res://assets/ui/arrow_up.png", Vector2i.UP)
	_gen_arrow("res://assets/ui/arrow_down.png", Vector2i.DOWN)
	_gen_arrow("res://assets/ui/arrow_left.png", Vector2i.LEFT)
	_gen_arrow("res://assets/ui/arrow_right.png", Vector2i.RIGHT)
	_gen_button("res://assets/ui/btn_confirm.png", 26, Color(0.25, 0.62, 0.35, 0.7))
	_gen_button("res://assets/ui/btn_cancel.png", 22, Color(0.75, 0.31, 0.25, 0.7))
	_gen_button("res://assets/ui/btn_menu.png", 18, Color(0.79, 0.64, 0.25, 0.7))


func _gen_arrow(res_path: String, direction: Vector2i) -> void:
	var size := 20
	var image := _img(size, size)
	_rect(image, 1, 1, size - 2, size - 2, Color(0.08, 0.08, 0.12, 0.55))
	var arrow := Color(1, 1, 1, 0.8)
	for i in range(6):
		var span := 11 - i * 2
		for j in range(span):
			match direction:
				Vector2i.UP:
					_px(image, 4 + i + j, 13 - i, arrow)
				Vector2i.DOWN:
					_px(image, 4 + i + j, 6 + i, arrow)
				Vector2i.LEFT:
					_px(image, 13 - i, 4 + i + j, arrow)
				Vector2i.RIGHT:
					_px(image, 6 + i, 4 + i + j, arrow)
	_save(image, res_path)


func _gen_button(res_path: String, size: int, fill: Color) -> void:
	var image := _img(size, size)
	var half := float(size) / 2.0
	_ellipse(image, half - 0.5, half - 0.5, half - 1.0, half - 1.0, Color(0.08, 0.08, 0.12, 0.55))
	_ellipse(image, half - 0.5, half - 0.5, half - 2.5, half - 2.5, fill)
	_save(image, res_path)


func _gen_icon() -> void:
	var image := _img(128, 128)
	_rect(image, 0, 0, 128, 128, Color("24352a"))
	_ellipse(image, 64, 74, 42, 38, Color("6d5636"))
	_ellipse(image, 64, 74, 38, 34, Color("8a6f47"))
	_ellipse(image, 64, 52, 34, 18, Color("5d8f4a"))
	_rect(image, 30, 14, 16, 18, Color("6d5636"))
	_rect(image, 82, 14, 16, 18, Color("6d5636"))
	_rect(image, 34, 18, 8, 8, Color("5d8f4a"))
	_rect(image, 86, 18, 8, 8, Color("5d8f4a"))
	_ellipse(image, 48, 72, 5, 6, Color("22222a"))
	_ellipse(image, 80, 72, 5, 6, Color("22222a"))
	_ellipse(image, 64, 88, 7, 5, Color("22222a"))
	_save(image, "res://assets/ui/icon.png")
