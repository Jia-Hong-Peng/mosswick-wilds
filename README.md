# 潮森群島 Tidegrove Isles — 第一章：第一位旅伴

原創 **2.5D 像素立體劇場**（Original Pixel Diorama Visual Style）伴獸認養 RPG 的
**3–5 分鐘完整關卡 DEMO**。
潮芽伴獸之家的認養日早晨：三隻幼獸在各自的角落看著你——
謹慎的**芽翼鼯**（草）、好勝的**燼角羌**（火）、好奇的**潮冠鷺**（水）。
別急著挑最強的；先看看，哪一隻願意跟你走。
認養、同行、然後和牠一起面對第一場危機：一隻被港口施工巨響嚇壞、
撞破圍欄的**岩背獾**。你不能打倒牠——壓下牠的恐慌，然後**安撫**牠。

**線上遊玩：https://jia-hong-peng.github.io/mosswick-wilds/**

![Title](docs/screenshots/hd2d-after/title.png)

| 認養日開場（葵姨） | 認養互動（芽翼鼯） |
|---|---|
| ![Opening](docs/screenshots/hd2d-after/opening_kui.png) | ![Adopt](docs/screenshots/hd2d-after/adopt_interact.png) |

| 危機戰（前兆判讀＋安撫窗口） | 章節完成 |
|---|---|
| ![Crisis](docs/screenshots/hd2d-after/soothe_window.png) | ![Done](docs/screenshots/hd2d-after/chapter_card.png) |

## DEMO 流程（首玩約 3.5–5 分鐘）

```text
0:00 開場運鏡：港口晨光 → 三個活動區 → 章節卡「第一章：第一位旅伴」（可跳過）
0:20 認養日：與三隻幼獸各自互動（蹲低等牠／接住試探／倒影引回）→ 認養確認
     → 認養證 → 旅伴牌 → 暱稱（可保留原名）→ 專屬演出 → 自動存檔
1:30 第一次同行：夥伴實際跟隨（三隻個性不同）→ 與夥伴互動 → 葵姨交付旅行包
2:00 危機：岩背獾撞破圍欄衝進庭院——牠不是敵人，牠只是嚇壞了
2:30 危機戰（60–90 秒、3–8 有效回合）：判讀前兆（噴氣／縮甲／衝撞）
     → 三系各有解法（纏芽拖慢＋葉幕硬吃／燼角衝破防速攻／霧步閃避連擊）
     → 恐慌壓到底線後「安撫」收尾（純攻擊不可能獲勝）
4:00 岩背獾回歸山林 → 葵姨：「不只是你選了牠，牠也選了你」→ 走向港口道
     → 章節完成＋認養結果＋三種結尾動畫 → 公告板伏筆（一雙不同顏色的眼睛）
```

## 操作

```text
方向鍵 / WASD : 移動　　Z / Enter : 確認・互動（面向夥伴＝呼喚牠）
X / Escape    : 取消・跳過演出　　M : 旅行手冊
```

觸控裝置自動顯示螢幕按鍵（十字鍵／確認／取消／選單）。
標題選單含音量、「減少閃爍／減少震動」輔助選項與「畫質：高／低」。

## 視覺：原創 2.5D 像素立體劇場

2D 像素角色 × 3D 立體場景。Compatibility Renderer／WebGL 2.0 限定實作：
正交無旋轉攝影機（俯角 36°）、地形＋建築＋道具合併單一 ArrayMesh（頂點色烘焙明暗）、
Sprite3D 立牌角色（Nearest／Alpha Scissor／腳底 blob 陰影）、
1 方向光＋≤3 局部暖光（其餘假光光暈）、分層霧面片、捲動噪聲水面（無 SSR）、
輕量單通道帶狀柔焦（假移軸）＋暗角。詳見
`docs/hd2d-reference-analysis.md`／`docs/web-shader-inventory.md`／`docs/web-hd2d-performance.md`。

## 技術

| 項目 | 值 |
|---|---|
| Engine | Godot **4.7.2 Stable**（CI 釘死；本機 4.7.1 驗證） |
| 規格 | typed GDScript・Compatibility・640×360（UI 320×180 ×2）・Nearest・16px texel |
| 御三家 | 資料驅動（`data/starters/starters.json`）：互動、跟隨個性、戰鬥定位、結尾動畫 |
| 字型 | Fusion Pixel 12px 繁中（OFL） |
| 音訊 | 全程序化合成：環境音狀態機＋危機戰雙層音樂＋SFX（含三隻叫聲、認養樂句） |
| 存檔 | user:// JSON・原子寫入・Schema **v4**（舊版回聲存檔安全重置，不崩潰）・認養／通關自動存檔 |

## 驗證指令

```powershell
$godot = 'D:\Tools\Godot\4.7.1-stable-standard\Godot_v4.7.1-stable_win64_console.exe'
& $godot --headless --path . --import                              # Headless 驗證
& $godot --headless --path . --script res://tests/run_tests.gd     # 2009 asserts
& $godot --headless --path . --export-release "Web" build/web/index.html
& $godot --path . --resolution 1280x720 -- --tour                  # 認養芽翼鼯完整通關（草系解法）
& $godot --path . --resolution 1280x720 -- --tour-fire             # 認養燼角羌（爆發解法）
& $godot --path . --resolution 1280x720 -- --tour-water            # 認養潮冠鷺（速度解法）
& $godot --path . --resolution 1280x720 -- --tour-continue         # Continue 恢復驗證
```

測試涵蓋：危機戰規則（前兆序列一致／恐慌 30% 下限／安撫時機閘門／
三系策略路線 3–10 回合必勝／破防・閃避・減速機制／敗北）、
認養流程（互動旗標／確認二擇／世界動作訊號／旅行包發放／夥伴互動變體／伏筆變體）、
存檔 v1→v4 遷移鏈（回聲版存檔安全返回新遊戲開場、無殭屍旗標）、
資料引用完整性（1372 項：立繪／FX／動作白名單／地圖圖例／素材檔案存在）等。

## 專案架構重點

```text
scripts/domain/crisis_battle_service.gd  危機戰規則（純邏輯、前兆制、恐慌下限、安撫收尾）
scripts/world/world_scene.gd             開場運鏡／認養儀式導演／結局三變化／伏筆
scripts/world3d/{stage_builder,follower_3d,camera_rig,screen_grade}.gd
scripts/battle/{crisis_battle_scene,battle_stage_3d}.gd
data/starters/starters.json              御三家資料驅動定義
data/maps/haven.json                     潮芽伴獸之家（三層網格＋elevation）
tools/pixgen/*                           全素材產生器（含御三家六表情立繪與世界行走圖）
```

## 已知限制（誠實清單）

- 全素材為**程式生成設計稿**（工藝低於手繪；剪影與性格辨識已達成，替換規則見 asset-manifest）。
- 通關時間為自動化 bot 實測（51–63 秒）換算的人類估計，未做真人試玩取樣。
- Web 版於 Chromium 驗證啟動與 Console 無錯；畫面級／FPS／Firefox／Safari／
  行動實機驗收標註於 `docs/web-hd2d-performance.md`（尚待人工裝置驗收）。
- 危機戰指令清單開啟時會暫時遮住岩背獾本體（版面取捨；前兆／事件演出時完整可見）。

## Roadmap

1. 第二章：公告板上那雙不同顏色的眼睛（失蹤伴獸線）；往霧杉島的航線。
2. 伴獸成長與進化潛力；照護玩法（毛刷／食盆實際使用）。
3. 專業美術重繪；真人試玩取樣與節奏調校；手機實機驗證。
