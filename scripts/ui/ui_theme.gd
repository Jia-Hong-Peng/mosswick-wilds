class_name UiTheme
extends RefCounted
## Design System 樣式工廠（docs/ui-system.md）。
## 方向：復古觀測儀器 × 潮霧群島手冊 × 現代清晰度。
## 紙面米白底、深藍綠框線、珊瑚橘焦點；8px 間距系統；禁用引擎預設外觀。

const SPACE := 8  # 基準間距


## 手冊紙面面板（對話框、選單底板）
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Pal.PAPER
	style.border_color = Pal.STEEL
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(6)
	style.shadow_color = Pal.alpha(Pal.INK, 0.35)
	style.shadow_size = 2
	style.shadow_offset = Vector2(2, 2)
	return style


## 深色儀器面板（HUD、地名浮標）
static func dark_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Pal.alpha(Pal.NIGHT, 0.92)
	style.border_color = Pal.MIST_DK
	style.set_border_width_all(1)
	style.set_content_margin_all(4)
	return style


static func name_tag_style() -> StyleBoxFlat:
	var style := dark_panel_style()
	style.border_color = Pal.AMBER_DK
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	return style


## 選單列四態
static func row_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(3)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	match state:
		"focus":
			style.bg_color = Pal.alpha(Pal.CORAL, 0.2)
			style.border_color = Pal.CORAL
			style.set_border_width_all(1)
			style.border_width_left = 3
		"pressed":
			style.bg_color = Pal.alpha(Pal.CORAL, 0.35)
			style.border_color = Pal.CORAL
			style.set_border_width_all(1)
		"disabled":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
			style.set_border_width_all(1)
		_:
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color(0, 0, 0, 0)
			style.set_border_width_all(1)
	return style


static func text_color(state: String = "normal") -> Color:
	match state:
		"focus":
			return Pal.INK
		"disabled":
			return Pal.GRAY
		"dim":
			return Pal.MIST_DK
		"accent":
			return Pal.CORAL
		"header":
			return Pal.SEA_DK
		_:
			return Pal.NIGHT


## 標準選單列：面板＋左圖示（可選）＋文字。回傳 {panel, label}
static func make_row(text: String, icon: Texture2D = null) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", row_style("normal"))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	if icon != null:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		rect.custom_minimum_size = Vector2(16, 14)
		box.add_child(rect)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", text_color("normal"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(label)
	return {"panel": panel, "label": label}


static func set_row_state(row: Dictionary, state: String) -> void:
	var panel := row["panel"] as PanelContainer
	var label := row["label"] as Label
	panel.add_theme_stylebox_override("panel", row_style(state))
	label.add_theme_color_override("font_color", text_color(state))


## 標題字（手冊章節樣式）
static func style_header(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", text_color("header"))


## HP 條：回傳 {back, fill}，fill 寬度由呼叫端依比例設定
static func make_hp_bar(width: float) -> Dictionary:
	var back := Panel.new()
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Pal.alpha(Pal.INK, 0.85)
	back_style.border_color = Pal.STEEL
	back_style.set_border_width_all(1)
	back.add_theme_stylebox_override("panel", back_style)
	back.custom_minimum_size = Vector2(width, 6)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var fill := ColorRect.new()
	fill.color = Pal.LEAF
	fill.position = Vector2(1, 1)
	fill.size = Vector2(width - 2.0, 4)
	back.add_child(fill)
	return {"back": back, "fill": fill, "width": width - 2.0}


static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Pal.LEAF
	if ratio > 0.2:
		return Pal.AMBER
	return Pal.CORAL
