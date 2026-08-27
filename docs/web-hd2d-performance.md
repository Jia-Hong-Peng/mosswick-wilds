# Web HD-2D 效能與實機驗收紀錄

版本：v0.4.0（潮森群島・御三家認養日）
建置：Godot 4.7.1（本機匯出）；CI 部署使用 4.7.2 官方模板。
渲染：Compatibility／WebGL 2.0／Single-threaded Web Export。

## 建置大小（本機 build/web）

| 檔案 | 大小 |
|---|---|
| index.wasm | 37.7 MB（未壓縮；GitHub Pages 以 gzip 傳輸，實際下載約 10 MB 級） |
| index.pck | 2.78 MB |
| index.js | 0.27 MB |
| 其餘（HTML／icon／worklet） | < 0.1 MB |

初始下載目標 30 MB：以傳輸（壓縮後）大小計達標；未壓縮 wasm 為引擎固定成本，
遊戲資產（pck）僅 2.78 MB。

## 場景預算（實作值）

| 項目 | 預算 | 實際 |
|---|---|---|
| 同時動態燈 | 2–3 | 世界 ≤3 盞 OmniLight（其餘為光暈面片假光）＋1 方向光 |
| 帶即時陰影的燈 | 0–1 | 僅方向光（Web High）；Web Low 全關，改 blob 陰影 |
| 世界地形 Draw Call | — | 地形＋建築＋盒體道具合併為 **1 個 ArrayMesh**；立牌／角色為 Sprite3D |
| 透明層 | <6 | 水面 1＋淺水 1＋霧片 2–3＋光暈若干（同屏可見 ≤6） |
| 粒子 | 分級 | 煙／爆點 High 10–16、Low 5–8；CPUParticles3D |
| 貼圖 | ≤2048、Atlas 優先 | 地形共用 256×96 圖集；角色圖 192×192；全部 Nearest、無 Mipmap |

## Web High／Low

| 項目 | High | Low |
|---|---|---|
| 方向光陰影 | 開（2048） | 關（blob 陰影） |
| 假移軸柔焦 | 開（5-tap 帶狀） | 關（僅暗角） |
| God Ray／霧片 | 2 道／3 片 | 0 道／2 片 |
| 粒子數 | 100% | 50% |
| 水面 | 兩層噪聲 | 單層噪聲 |

兩檔皆不刪除玩法資訊（角色、道路、圍欄互動、前兆橫幅、安撫提示完整保留）。
Low Profile 預設在觸控裝置啟用；標題選單可手動切換「畫質：高／低」。

## 驗收結果

### 引擎內（原生，1280×720）
- `--tour`（芽翼鼯・草系解法）：63 秒完整通關（認養→同行→危機戰 8 回合→安撫→結局→伏筆→結尾選單）。
- `--tour-fire`（燼角羌）：危機戰 3 回合通關。
- `--tour-water`（潮冠鷺）：危機戰 5 回合通關。
- `--tour-continue`：Continue 正確恢復御三家、章節旗標與隊伍。
- 測試：12 套件、2009 asserts、0 failures。

### Chromium Desktop（本機 Web build，localhost）
- 啟動成功：`Godot Engine v4.7.1` ／ `OpenGL ES 3.0 (WebGL 2.0)` ／ Compatibility ／ single-threaded。
- Console：無 Shader Error、無 WebGL Error（僅視窗隱藏時的 zero-size framebuffer 警告，屬宿主視窗行為）。
- 畫面截圖／FPS 取樣：**尚待人工裝置驗收**（本次自動化環境瀏覽器窗格無法顯示合成畫面；
  rAF 於隱藏分頁被節流，無法誠實取樣）。

### 其他目標
| 項目 | 結果 |
|---|---|
| Firefox Desktop | 尚待人工裝置驗收 |
| Chromium Mobile Emulation | 尚待人工裝置驗收 |
| 實際手機瀏覽器 | 尚待人工裝置驗收 |
| Safari | 尚待人工裝置驗收 |
| 音訊啟動（使用者手勢後） | 尚待人工裝置驗收（Godot Web 標準行為：首次輸入後啟動） |
| 觸控操作 | 觸控層已依 640×360 佈局（引擎內驗證）；實機尚待人工驗收 |
| 重新整理後 Continue | 存檔寫入 IndexedDB（user://）；引擎內驗證通過，實機尚待人工驗收 |

> 標註「尚待人工裝置驗收」的項目為誠實未驗證項；不得視為通過。
