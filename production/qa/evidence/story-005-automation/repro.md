# Story 005 證據：自動修復模組標示與建造面板

拍於 2026-11-12，合併 `origin/main`（PR #37 危機數據、#38 雙層側視站體、#39 結果畫面）之後。Godot 4.7.2，視窗 1920×1080。舊的 `01-auto-markers-and-panel.png` 是合併前的單層版面，已取代。

| 檔案 | 對應驗收 | 畫面重點 |
| --- | --- | --- |
| `01-upper-and-lower-modules.png` | 標示在有模組的房間上、`AUTO` 標籤、外框樣式 | Bridge、Engine（上層）與 Lab（下層）有模組：`AUTO` 標籤在各自房間內上方中央，外框是緊貼房間的細雙線綠框；沒有模組的房間（Dorm、Storage、Garden）沒有標示；建造面板顯示點數，已建的按鈕標 `(built)` 並停用 |
| `02-modules-with-fault-and-breach.png` | 模組房間同時有危機、破洞不被模組處理 | Lab（下層）`AUTO`＋`FAULT`（藍色虛線）；Bridge `AUTO`＋`BREACH`（橘色粗實線）；Engine 同時 `AUTO`＋`FAULT`＋`BREACH`。三種標籤互不重疊，也沒有蓋到房名、殖民者、HUD、建造面板 |
| `02-modules-with-fault-and-breach-grayscale.png` | #24：灰階下仍分得出 | 同上轉灰階：靠文字 `AUTO`／`FAULT`／`BREACH`，外框為細雙線、虛線、粗實線三種 |
| `03-result-screen-over-build-panel.png` | 結算畫面出現時 | 建造面板與 `AUTO` 標示都在結算畫面的遮罩底下變暗；遮罩吃掉滑鼠，且 `can_build` 在 `game_ended` 之後回傳 `false` |
| `04-panel-all-rooms-built.png` | 建造面板最壞情況 | 六個房間全建好，按鈕排成 2 列 × 3 欄，整個面板在畫面內，位於站體上方 |
| `05-module-repair-before.png` | 模組自動修復（修前） | 只有 Lab 蓋了模組，Lab 同時有 `AUTO` 與 `FAULT`，任務清單顯示 `Malfunction @ Lab: waiting`；殖民者停在 Bridge（已凍結，不會去修） |
| `06-module-repair-after.png` | 模組自動修復（修後） | 同一個畫面，`FAULT` 標籤與藍色虛線框消失、任務清單變成 `Tasks (0)`，`AUTO` 仍在；殖民者全程沒動，所以是模組修好的。從故障出現到修好約 5 秒（實測 4.6 s ＋ 截圖前的 0.4 s） |

## 版面決定

兩層房間只隔 10 px，所以標示不能畫在房間外太遠：

- `AUTO` 標籤放在房間內、上緣中央（離上緣 36 px，與 BREACH／FAULT 標籤同一個上邊距）。房名在左、危機標籤在右上往下疊，中間剛好空出一塊；殖民者在地板上，離得很遠。
- 細雙線外框緊貼房間，離邊 2.5 與 4.5 px，各自落在 10 px 層間縫隙的自己那一半，不會進到別的房間。

## 怎麼拍的

用一個不進 repo 的臨時探針腳本（`SceneTree` 腳本）：實例化 `src/main.tscn`，凍結 `DayCycle`、`CrisisDirector`、`AutoRepair` 的 `_process` 讓畫面固定（05、06 改成只凍結 `DayCycle`、`CrisisDirector`、`Colonists`、`TaskBoard`，讓 `AutoRepair` 用真實時間計時，只有模組能修好故障），`build_points.add()` 加點後呼叫 `AutoRepair.build()`，再用 `CrisisDirector._fire()` 放入指定房間的危機；03 發 `Events.game_ended`。截圖用 `get_viewport().get_texture().get_image().save_png()`，在 `RenderingServer.frame_post_draw` 之後；灰階用 `Image.convert(Image.FORMAT_L8)`。

## 自己看

```
godot --path .
```

撐過一天拿 1 點，點面板上的 `AUTO <房名>` 按鈕蓋模組；有模組的房間發生設備故障後約 5 秒會被自動修好（殖民者可以搶先）。

## 沒有截圖的部分

殖民者「搶先修好」那條路徑（殖民者在 5 秒內先完成任務、模組取消）沒有截圖，由 `tests/unit/core/auto_repair_test.gd` 的 `test_colonist_finishing_first_prevents_double_completion` 涵蓋。
