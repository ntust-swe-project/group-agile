# Story 004 證據：危機出現、完整度下降、危機標示

補拍於 2026-11-12（#33，PR #26 merge 之後才看得到 HUD 與 `day_started`）。Godot 4.7.2，`main` 加上 #33 的數值。

| 檔案 | 對應驗收 | 畫面重點 |
| --- | --- | --- |
| `01-crisis-and-integrity-drop.png` | AC6 | 第 1 天 Storage 出現 `BREACH`，Ava 從 Dorm 趕去（`>`），左上角 Integrity 99 / 100 |
| `02-breach-and-fault-markers.png` | AC10、#24 標示規則 | 第 8 天 Engine `BREACH`（橘色實線框）與 Lab `FAULT`（藍色虛線框）同時出現；文字標籤＋不同外框，灰階也分得出；房間中性色、房名保留 |

## 怎麼拍的

用一個不進 repo 的臨時探針場景：把 `src/main.tscn` 實例化，`Engine.time_scale = 5` 加快等待，監聽 `Events` 訊號：

- 01：有危機進行中且完整度 ≤ 99 時截圖
- 02：同時有 `breach` 與 `malfunction` 進行中時截圖

截圖用 `get_viewport().get_texture().get_image().save_png()`，在 `RenderingServer.frame_post_draw` 之後。視窗以 `--resolution 1920x1080` 開啟，螢幕放不下時系統會縮成 1886×1061，比例不變。

## 自己看

```
godot --path .
```

第 1 天的第一個危機會在 15 秒內出現；第 5 天之後比較常看到兩種危機同時出現。
