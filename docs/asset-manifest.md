# Asset Manifest（素材清冊與狀態）

狀態定義：
- ✅ **正式**：符合 art-bible，可長期使用。
- 🟨 **設計稿**：程式生成、遵守色盤與規格，可出貨，但建議日後由專業像素美術
  以同尺寸同路徑重繪（替換即生效，不動程式）。

| 素材 | 路徑 | 規格 | 狀態 |
|---|---|---|---|
| 世界圖集（90 tile，含水面/高草/泡沫/旗幟/亮點動畫） | `assets/tilesets/overworld.png` | 16 欄×6 列、16px、佈局＝`TileCatalog` | 🟨 |
| 玩家（觀測員） | `assets/characters/player.png` | 96×96：6 欄（idle/走1–4/替代）×4 向、16×24 | 🟨 |
| 沈芮／阿海伯／小滿 | `assets/characters/npc_*.png` | 同上 | 🟨 |
| 苔角獸 前(2幀)/背/受擊/圖示/迷你 | `assets/creatures/mosshorn_*.png` | 64×64／32／16 | 🟨 |
| 潮翼 同上 | `assets/creatures/tidewing_*.png` | 同上 | 🟨 |
| 磁殼仔 同上 | `assets/creatures/magshell_*.png` | 同上 | 🟨 |
| 標題背景 | `assets/ui/title_bg.png` | 320×180 三層構圖 | 🟨 |
| 戰鬥背景（古道／村落） | `assets/battle/bg_*.png` | 320×180，含站位基座 | 🟨 |
| 觸控按鍵（normal+pressed） | `assets/ui/arrow_*.png`、`btn_*.png` | 18–26px 儀器風 | 🟨 |
| 屬性圖示（林/潮/訊/中性） | `assets/ui/elem_*.png` | 12×12 | 🟨 |
| 道具圖示（青草膏/共鳴匣） | `assets/ui/item_*.png` | 16×16 | 🟨 |
| 立繪（玩家×5／沈芮×4／阿海伯×4 表情） | `assets/portraits/*.png` | 40×48 胸像、參數化眉眼口 | 🟨 |
| 頭目失衡體（Idle×2/充能/攻擊/虛弱） | `assets/creatures/magshell_{unbalanced,charge,attack,weak}.png` | 64×64 | 🟨 |
| 迴靈姿勢幀（前搖/攻擊/虛弱/安定 ×3 隻） | `assets/creatures/*_{antic,attack,weak,calm}.png` | 64×64 | 🟨 |
| 觀測線索（潮痕/電波/波紋 ×2 幀） | `assets/ui/clue_*.png` | 16×16 | 🟨 |
| 戰鬥 VFX（防禦弧/逆頻箭/共鳴環） | `assets/ui/{guard_arc,jam_bolt,resonance_ring}.png` | — | 🟨 |
| 觀測站戰鬥背景 | `assets/battle/bg_station.png` | 320×180 | 🟨 |
| 觀測觸控鍵（normal+pressed） | `assets/ui/btn_observe*.png` | 22px | 🟨 |
| 穩定回聲圖示 | `assets/ui/item_stable_echo.png` | 16×16 | 🟨 |
| 接觸陰影／霧片 | `assets/ui/contact_shadow.png`、`fog_blob.png` | — | ✅ |
| 遊戲圖示 | `assets/ui/icon.png` | 128×128 | 🟨 |
| 字型 | `assets/fonts/fusion-pixel-12px-tc.ttf` | 12px 繁中像素字型（OFL） | ✅ |
| 色盤圖 | `docs/palette.png` | 40 色 | ✅ |
| 音效 | 程式合成（AudioManager） | 14 類 | 🟨（日後可換錄製音效） |

## 重生成方式

```powershell
& $godot --headless --path . --script res://tools/generate_assets.gd
```

## 替換規則（給美術）

1. 同路徑、同尺寸、同表格佈局直接覆蓋即可，程式零改動。
2. 色盤限制 40 色（docs/palette.md）；Nearest、無 mipmaps、透明背景。
3. 角色腳底貼齊畫布底；迴靈基準線 y=56（64px 畫布）。
4. 圖集佈局以 `scripts/world/tile_catalog.gd` 為準（動畫幀在右側連續格）。
