# Web Shader Inventory（自訂 Shader 清單）

本專案固定使用 **Godot Compatibility Renderer（WebGL 2.0）**，
禁用 Forward+／Vulkan 效果／Compute Shader／Volumetric Fog／SSAO／SSIL／SSR／SDFGI／VoxelGI。
自訂 Shader 僅兩支，其餘視覺全部使用 StandardMaterial3D（頂點色烘焙明暗）、
Sprite3D（Alpha Scissor）與 CPUParticles3D。

| Shader | 類型 | 使用場景 | Texture Sample 數 | 迴圈／分支 |
|---|---|---|---|---|
| `shaders/water3d.gdshader` | spatial（specular_disabled） | 世界深水面（港灣／庭院外海）；戰鬥舞台不使用 | 2（High）／1（Low，second_layer=0） | 無迴圈；1 個 uniform 分支 |
| `shaders/screen_grade.gdshader` | canvas_item（hint_screen_texture） | 世界場景全畫面分級：上下柔焦帶（假移軸）、暗角、通關暖調、演出閃光 | 5-tap（High）／1-tap（Low，blur_strength=0） | 固定 5 次取樣展開；無動態分支 |

## Web High／Low 行為

| Shader | Web High | Web Low | Fallback |
|---|---|---|---|
| water3d | 兩層噪聲捲動＋波光＋假 Fresnel | 單層噪聲（second_layer=0），其餘照常 | 若編譯失敗：改掛半透明 StandardMaterial3D（淺水已用同作法） |
| screen_grade | blur_strength=2.0（上下柔焦帶）＋暗角 | blur_strength=0（等同直通）＋暗角 | 若編譯失敗：ScreenGrade 節點整層不加（遊戲資訊不受影響） |

- 兩支 Shader 均不做深度取樣、不依賴多通道後處理、不使用高次數迴圈。
- 柔焦帶以 `smoothstep` 侷限在畫面上緣 26% 與下緣 34%，操作區（角色、道路、
  互動物、前兆橫幅、UI）永遠落在清晰帶內；UI 位於獨立 CanvasLayer，不受分級影響。

## 瀏覽器驗證結果

| 瀏覽器 | 結果 |
|---|---|
| Chromium Desktop | 啟動成功：`OpenGL ES 3.0 (WebGL 2.0)` Compatibility；Console 無 Shader Error（本機 build 驗證） |
| Firefox Desktop | 尚待人工裝置驗收 |
| Safari | 尚待人工裝置驗收 |

（兩支 Shader 皆只用 WebGL 2.0 核心功能——`texture`、`smoothstep`、`mix`、`pow`——無擴充依賴。）
