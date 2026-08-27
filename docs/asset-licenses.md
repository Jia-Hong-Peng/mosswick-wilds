# 素材授權清單

原則：不使用來源不明或授權不明素材；程式生成素材版權隨專案。

## 第三方素材

| 名稱 | 作者 | 來源 | 授權 | 修改情形 |
|---|---|---|---|---|
| Fusion Pixel Font 12px Proportional（zh_hant） | TakWolf 等（縫合 Ark Pixel／Cubic 11／Galmuri 等上游） | github.com/TakWolf/fusion-pixel-font（release 2026.08.11） | SIL OFL 1.1（授權檔：`assets/fonts/OFL-fusion-pixel.txt`） | 未修改，改名為 `fusion-pixel-12px-tc.ttf` |

## 專案自產素材（版權隨本專案）

- 全部像素圖（tileset／角色／迴靈／UI／背景／圖示）：由
  `tools/generate_assets.gd`＋`tools/pixgen/*` 程式生成，
  色盤與規則見 `docs/palette.md`、`docs/art-bible.md`。
- 全部音效：`scripts/core/audio_manager.gd` 於執行期以方波／濾波噪音合成
  （腳步-草/淺水/硬地、確認、取消、對話、道具、開門、遭遇、攻擊、命中、
  治療、收錄擲出/成功/失敗），無任何外部音檔。

## 引擎

Godot Engine（MIT License）。

## 主角官方設定圖

- `docs/character/protagonist-model-sheet.png`：使用者提供之**原創**主角概念設定圖（依本專案原創性規範產出：無紅白帽、無球形徽記、非任何既有訓練家之可辨識設計）。
- 用途：(1) 主角視覺定案參考（世界 Sprite 依其重繪）；(2) 底部三個表情頭像經 `tools/pixgen/gen_protagonist.gd` 裁切、縮放並**量化回全域色盤**後，作為對話立繪 `assets/portraits/player_*.png`。
- 設定圖僅入 docs（.gdignore，不進遊戲 pck）；進入遊戲的只有量化後的像素立繪。
