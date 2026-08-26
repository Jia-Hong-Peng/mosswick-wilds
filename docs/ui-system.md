# UI Design System — 觀測手冊

方向：**復古觀測儀器 × 潮霧群島手冊 × 現代清晰度**。
實作：`scripts/ui/ui_theme.gd`（樣式工廠，全部 UI 共用；禁止 Godot 預設外觀）。

## 色票（引用全域色盤 docs/palette.md）

| 用途 | 色 |
|---|---|
| 紙面底 | PAPER `#e8e2d0`（禁止大面積純白） |
| 紙面陰影／分隔 | PAPER_DIM `#cfc7b2` |
| 框線 | STEEL `#3d5266`（深藍綠，2px，直角） |
| 主文字 | NIGHT `#1d2b3a` |
| 章節標題 | SEA_DK `#1f4a63` |
| 焦點／重點 | CORAL `#e07a5f`（左側 3px 粗邊＋20% 底） |
| 停用 | GRAY `#8c8a80` |
| 儀器面板（HUD） | NIGHT 92% 底＋MIST_DK 框 |
| 名牌強調 | AMBER_DK 框＋AMBER_LT 字 |

## 間距系統

基準 8px（`UiTheme.SPACE`）；面板內距 6px、列內距 3/6px、元素間距 2–4px。
面板陰影固定 (2,2) 2px INK 35%——像素風的硬陰影，不用柔邊。

## 元件

| 元件 | 規格 |
|---|---|
| Panel（紙面） | `panel_style()`：PAPER 底、STEEL 2px 直角框、硬陰影 |
| Panel（儀器） | `dark_panel_style()`：NIGHT 92%、MIST_DK 1px 框 |
| 選單列 | `make_row()`：可帶 16px 圖示＋文字；四態見下 |
| HP 條 | `make_hp_bar()`：INK 底、STEEL 框、依比例填色（LEAF→AMBER→CORAL），變化時 0.3s 平滑 |
| Item Row | 圖示（道具 16px pixel icon）＋名稱 ×數量 |
| Party Row | 迴靈 20px 圖示＋名稱/Lv/HP 數值＋HP 條 |
| Dialogue Box | 紙面板 312×50 底部；說話者名牌浮左上（儀器色）；▼ 續頁符 CORAL |
| Choice/Modal | 紙面板浮動於右上；結算面板置中（── 調查紀錄 ──） |
| Tooltip | 技能聚焦時於訊息列顯示「威力・命中％・描述」 |
| Touch Control | 儀器按鍵材質（`assets/ui/arrow_*.png`、`btn_*.png`＋觀測鍵 `btn_observe`），有 normal/pressed 兩態、82% 透明度、觸控裝置自動顯示 |
| 立繪 | 40×48 胸像，左右槽位；說話者高亮＋3px 進場位移、非說話者 55% 壓暗；名牌跟隨說話側 |
| 前兆橫幅 | 頭目戰左上儀器色帶：異常前兆＝GLITCH_LT 字、紊亂窗口＝AMBER_LT 字；顯示不需確認鍵，維持節奏 |
| 訊號強度條 | 頭目專用：GLITCH_LT 填色＋FOAM 下限刻度（攻擊打不破的 30% 線可視化） |
| 章節卡／黑幕 | 紙面卡置中＋INK 45% 壓暗；伏筆黑幕上訊號燈以 CORAL 節拍閃爍 |

## 狀態（Focus / Pressed / Disabled）

`row_style(state)` 四態，鍵盤游標與觸控相同視覺：

- **normal**：透明底、NIGHT 字
- **focus**：CORAL 20% 底＋CORAL 框（左 3px）＋INK 字 —— 鍵盤與觸控都以此辨識焦點
- **pressed**：CORAL 35% 底（觸控按鍵另有 pressed 材質）
- **disabled**：GRAY 字、無框（如無存檔時的「繼續觀測」）

## 字型

Fusion Pixel 12px Proportional（繁中，OFL 授權）；全 UI 統一 12px、
關閉抗鋸齒與 subpixel（`project.godot [gui]`），任何縮放皆整數渲染，
像素風與可讀性兼得。標題例外允許 18–24px。

## 禁止

純白大面積背景、Godot 預設 Button、過度圓角、照抄既有遊戲選單、
文字被裁切、無焦點狀態的可選元素。
