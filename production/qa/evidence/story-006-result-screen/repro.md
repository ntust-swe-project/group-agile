# Story 006 證據：結算畫面

拍攝於 2026-11-12，Godot 4.7.2，branch `feat/17-result-screen`（含 S01～S04、S07 與 #33 之前的 main）。

| 檔案 | 對應驗收 | 畫面重點 |
| --- | --- | --- |
| `01-victory.png` | AC1、AC2、AC3、AC4、AC5 | `VICTORY`、`Days survived: 30 / 30`、剩餘完整度、三名殖民者最後狀態、`Play again` 按鈕 |
| `02-station-lost.png` | AC1、AC2、AC3、AC4、AC5 | `STATION LOST`、`Reason: Integrity depleted`、`Days survived: 10 / 30`（第 11 天輸）、`Integrity: 0 / 100`、殖民者狀態 |

## 怎麼拍的

用一個不進 repo 的臨時探針場景：把 `src/main.tscn` 實例化，監聽 `Events.game_ended`，結算畫面出現 3 幀後用 `get_viewport().get_texture().get_image().save_png()` 截圖。視窗以 `--resolution 1920x1080` 開啟，螢幕放不下時系統縮成 1886×1061。

- **失敗**：`Engine.time_scale = 15`，讓遊戲自然玩到完整度歸零。
- **勝利**：沒有 S05 撐不到 30 天，所以探針在開局後把 `DayCycle.current_day` 直接設成 30，撐完這一天即勝利。因為沒有發出 `day_started(30)`，截圖左上角 HUD 仍顯示 `Day 1 / 30`，這是探針造成的，不是 S06 的問題。

## 再玩一次（AC5）

按鈕連到 `restart()` 與顯示時取得焦點另有單元測試（`test_play_again_button_is_wired_to_restart_and_focused_on_show`）。失敗截圖後，探針對 `PlayAgainButton` 發出 `pressed`：場景重新載入後 `day_started(1)`、`current_day = 1`、時間在跑、完整度 100、結算畫面隱藏。按鈕在結算畫面出現時已取得焦點。

## 自己看

```
godot --path .
```

玩到完整度歸零（目前數值下，不操作約第 10～15 天）就會看到失敗畫面。
