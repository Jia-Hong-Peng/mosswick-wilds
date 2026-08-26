# AGENTS.md — 潮霧群島 Tidemist Isles

給所有 AI coding agent 與貢獻者的固定規則。修改本專案前先讀完。
世界觀與美術的最終依據：`docs/world-bible.md`、`docs/art-bible.md`、
`docs/palette.md`、`docs/ui-system.md`——內容衝突時以文件為準，要改先改文件。

## 引擎與語言

- 固定使用 **Godot 4.7.2 Stable**（Standard 版，非 mono）。本機若只有 4.7.1，
  可用於開發驗證，但必須在回報中註明版本差異；CI 以 4.7.2 為準。
- 固定使用 **typed GDScript**：所有變數、參數、回傳值都標型別；
  `debug/gdscript/warnings/untyped_declaration` 已開啟，不要關掉。
- 禁用 C#（Godot 4 C# 無法匯出 Web）。禁止依賴執行緒（Web build 需可部署於
  一般靜態網站，`variant/thread_support=false`）。

## 發布目標

- **Web 是主要發布平台**，Windows 次要。任何改動都不得破壞 Web export。
- 完成任務前必須執行 Web Export Smoke Test：
  `godot --headless --path . --export-release "Web" build/web/index.html`

## 測試紀律

- 修改後必須執行相關測試：
  `godot --headless --path . --script res://tests/run_tests.gd`
- 測試失敗（非零 exit code）就不算完成。新系統要附帶對應測試。
- 戰鬥、傷害、遭遇等規則必須可注入固定 RNG seed。

## 架構規則

- **遊戲資料與 UI 分離**：規則寫在 `scripts/domain/`（純 RefCounted，不碰
  scene tree），資料放 `data/*.json`。UI 場景只呈現、不擁有規則。
- 怪獸、招式、道具、遭遇表、地圖、對話一律資料驅動（JSON）。
- Autoload 克制使用：只放真正跨場景的服務（見 `project.godot` [autoload]）。
- 不要讓場景任意改全域 Dictionary；重要狀態透過具名方法操作
  （PartyService.add_member、InventoryService.use_item...）。
- **所有新增系統必須考慮存檔相容性**：改動存檔欄位就要 bump
  `SaveService.SCHEMA_VERSION` 並在 `migrate()` 補上遷移步驟。

## 素材規則

- **不使用受著作權保護的第三方遊戲素材**（名稱、圖像、音樂、資料皆同）。
  尤其不得引用任何 Pokémon／寶可夢內容。
- 所有像素素材關閉 Filtering（default_texture_filter=Nearest、無 mipmaps），
  16px tile 密度、**全域 40 色色盤**（docs/palette.md）以外的顏色禁止使用。
- 素材由 `tools/generate_assets.gd`＋`tools/pixgen/*` 產生；狀態與替換規則
  見 `docs/asset-manifest.md`（同路徑同尺寸覆蓋即生效，不改程式）。
- 圖集佈局唯一依據：`scripts/world/tile_catalog.gd`；改佈局要同步產生器與目錄。
- 中文字型為 Fusion Pixel 12px（SIL OFL，授權檔 `assets/fonts/OFL-fusion-pixel.txt`）；
  只能替換為同樣可自由散布授權的字型；UI 字型關閉 AA 與 subpixel。

## 依賴與版控

- 不任意加入第三方外掛；需要時先提出並取得確認。
- 不提交 `.godot/`、`build/`、暫存檔（見 `.gitignore`）。
- 不提交敏感資訊、Token 或硬編碼 Secret。
