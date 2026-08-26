class_name Pal
extends RefCounted
## 全域 40 色色盤（docs/palette.md 的程式對照表）。
## 所有產生素材只能使用這裡的顏色；透明度允許 20/35/60% 三檔。

const INK := Color("131c26")
const NIGHT := Color("1d2b3a")
const SLATE := Color("2a3b4d")
const STEEL := Color("3d5266")
const MIST_DK := Color("4a6670")
const MIST := Color("6b8a8d")
const MIST_LT := Color("9db8b0")
const FOG := Color("c6d6c8")
const SEA_DK := Color("1f4a63")
const SEA := Color("2e6b8a")
const SEA_LT := Color("4a9bb5")
const SEA_PALE := Color("7fc4cc")
const FOAM := Color("dceee6")
const MOSS_DK := Color("24402e")
const MOSS := Color("3a5f3f")
const LEAF := Color("5d8a53")
const LEAF_LT := Color("8fb56e")
const SPROUT := Color("c2d488")
const SAND_DK := Color("b09a6e")
const SAND := Color("d4c08e")
const SAND_LT := Color("e8dcae")
const WOOD_DK := Color("4a3527")
const WOOD := Color("6e5138")
const WOOD_LT := Color("96744e")
const BRICK_DK := Color("6e3a30")
const BRICK := Color("9c5646")
const BRICK_LT := Color("c27f62")
const RUST_DK := Color("5c4a42")
const RUST := Color("8a6e5c")
const RUST_LT := Color("b09480")
const CORAL := Color("e07a5f")
const CORAL_LT := Color("f0a884")
const AMBER_DK := Color("b58a3a")
const AMBER := Color("e0b45a")
const AMBER_LT := Color("f2d68a")
const SKIN := Color("ecc9a0")
const SKIN_DK := Color("c49a72")
const PAPER := Color("e8e2d0")
const PAPER_DIM := Color("cfc7b2")
const GRAY := Color("8c8a80")
const GLITCH := Color("9c4f88")
const GLITCH_LT := Color("d178b8")

## palette.png 的排列順序（名稱, 顏色）
const ORDER: Array = [
	["INK", INK], ["NIGHT", NIGHT], ["SLATE", SLATE], ["STEEL", STEEL],
	["MIST_DK", MIST_DK], ["MIST", MIST], ["MIST_LT", MIST_LT], ["FOG", FOG],
	["SEA_DK", SEA_DK], ["SEA", SEA], ["SEA_LT", SEA_LT], ["SEA_PALE", SEA_PALE],
	["FOAM", FOAM], ["MOSS_DK", MOSS_DK], ["MOSS", MOSS], ["LEAF", LEAF],
	["LEAF_LT", LEAF_LT], ["SPROUT", SPROUT], ["SAND_DK", SAND_DK], ["SAND", SAND],
	["SAND_LT", SAND_LT], ["WOOD_DK", WOOD_DK], ["WOOD", WOOD], ["WOOD_LT", WOOD_LT],
	["BRICK_DK", BRICK_DK], ["BRICK", BRICK], ["BRICK_LT", BRICK_LT],
	["RUST_DK", RUST_DK], ["RUST", RUST], ["RUST_LT", RUST_LT],
	["CORAL", CORAL], ["CORAL_LT", CORAL_LT], ["AMBER_DK", AMBER_DK],
	["AMBER", AMBER], ["AMBER_LT", AMBER_LT], ["SKIN", SKIN], ["SKIN_DK", SKIN_DK],
	["PAPER", PAPER], ["PAPER_DIM", PAPER_DIM], ["GRAY", GRAY],
	["GLITCH", GLITCH], ["GLITCH_LT", GLITCH_LT],
]


static func alpha(base: Color, level: float) -> Color:
	return Color(base.r, base.g, base.b, level)
