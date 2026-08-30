# 素材授權清單

原則：不使用來源不明或授權不明素材；程式生成素材版權隨專案。

## 第三方素材

| 名稱 | 作者 | 來源 | 授權 | 修改情形 |
|---|---|---|---|---|
| Fusion Pixel Font 12px Proportional（zh_hant） | TakWolf 等（縫合 Ark Pixel／Cubic 11／Galmuri 等上游） | github.com/TakWolf/fusion-pixel-font（release 2026.08.11） | SIL OFL 1.1（授權檔：`assets/fonts/OFL-fusion-pixel.txt`） | 未修改，改名為 `fusion-pixel-12px-tc.ttf` |

## 專案自產素材（版權隨本專案）

- 全部像素圖（tileset／角色／夥伴／UI／背景／圖示）：由
  `tools/generate_assets.gd`＋`tools/pixgen/*` 程式生成，
  色盤與規則見 `docs/palette.md`、`docs/art-bible.md`。
- 全部音效：`scripts/core/audio_manager.gd` 於執行期以方波／濾波噪音合成
  （腳步-草/淺水/硬地、確認、取消、對話、道具、開門、遭遇、攻擊、命中、
  治療、收錄擲出/成功/失敗），無任何外部音檔。

## 引擎

Godot Engine（MIT License）。

## 使用者生成之高解析背景（美術方向 v2）

皆為使用者以圖像生成工具產出之**原創**場景（依本專案規範：無文字、無角色、
無任何品牌視覺、無既有遊戲可辨識設計）。原圖 1672×941 僅入 docs/backgrounds
（.gdignore，不進遊戲 pck）；進入遊戲的是縮放後版本，程式一律
「優先載入手繪版，缺檔退回程式生成版」。

| 原圖（docs/backgrounds/） | 遊戲資產 | 用途 |
|---|---|---|
| title-island-original.png | assets/ui/title_bg_island.png（1280×720） | 標題畫面 |
| battle_courtyard_v2.png | assets/battle/backdrop_haven.png（1536×864） | 院子事件戰背板 |
| battle_coastal_trail_v2.png | assets/battle/backdrop_trail.png（1536×864） | 潮風小徑戰鬥背板 |
| battle_server_room_v2.png | assets/battle/backdrop_station.png（1536×864） | 機房戰鬥背板 |

## 主角官方設定圖

- `docs/character/protagonist-model-sheet.png`：使用者提供之**原創**主角概念設定圖（依本專案原創性規範產出：無紅白帽、無球形徽記、非任何既有訓練家之可辨識設計）。
- 用途：(1) 主角視覺定案參考（世界 Sprite 依其重繪）；(2) 底部三個表情頭像經 `tools/pixgen/gen_protagonist.gd` 裁切、縮放並**量化回全域色盤**後，作為對話立繪 `assets/portraits/player_*.png`。
- 設定圖僅入 docs（.gdignore，不進遊戲 pck）；進入遊戲的只有量化後的像素立繪。
