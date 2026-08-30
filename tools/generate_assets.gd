extends SceneTree
## 素材總產生器：依 docs/art-bible.md 與 docs/palette.md 產生全部原創像素素材。
##
##   godot --headless --path . --script res://tools/generate_assets.gd
##
## 輸出 PNG 均已提交版控；只有調整產生器後才需要重跑。

func _initialize() -> void:
	GenTiles.generate()
	GenCharacters.generate()
	GenCreatures.generate()
	GenPortraits.generate()
	GenUi.generate()
	GenBackgrounds.generate()
	Gen3D.generate()
	GenProtagonist.generate()  # 官方設定圖 → 主角立繪（覆蓋 pixgen 版）
	GenCreaturesHd.generate()  # 高解析戰鬥立繪／表情集（覆蓋 pixgen 版）
	# 色盤圖搬到 docs/（docs 不在 res:// 掃描外，直接寫）
	var src := ProjectSettings.globalize_path("res://docs_src/palette.png")
	var dst := ProjectSettings.globalize_path("res://docs/palette.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs"))
	if FileAccess.file_exists(src):
		DirAccess.copy_absolute(src, dst)
		DirAccess.remove_absolute(src)
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://docs_src"))
		print("wrote res://docs/palette.png")
	print("All assets generated.")
	quit(0)
