# 統計

每天或每個里程碑由角色 C 更新。來源為各 `log-*.md`。

**這次截至**：2026-11-12，`main` @ `447772a`（PR #39 merge 後），只算已 merge 進 `main` 的列。
本 PR 自己新增的 eden2289 第 22、23 筆留到下次更新再算。

| 項目 | yichieh-chen | anitaaa17 | eden2289 | 合計 |
| --- | --- | --- | --- | --- |
| 紀錄筆數 | 39 | 5 | 21 | 65 |
| 接受 | 23 | 3 | 12 | 38 |
| 修正後接受 | 13 | 0 | 6 | 19 |
| 部分接受 | 3 | 2 | 3 | 8 |
| 拒絕 | 0 | 0 | 0 | 0 |
| `API` 筆數 | 0 | 0 | 0 | 0 |
| `INV` 筆數(含 `DUP`) | 0 | 0 | 0 | 0 |
| 累計工時 | 18.75h | 2.25h | 6.5h | 27.5h |

- 修正或部分採用（`修正後接受`＋`部分接受`）共 27 筆，占 42%；完全原樣採用 38 筆，占 58%。
- 工時含 review 與修正 AI 產出的時間（規範第 3 節）。

## 怎麼算的

- 每個 `log-*.md` 中以 `| 數字 |` 開頭的列算一筆；結果欄照字面計數；標記欄出現 `API`／`INV`／`DUP` 就各算一次；工時欄的數字加總。
- 三個檔共 65 列，欄位數都是 8，工時都有填，沒有格式錯誤的列。

## 交叉核對（規範第 6 節）

用 `git log main` 找有 `Co-Authored-By`／`Assisted-by` 的 commit，對照各人的 ai-log：

| 帳號 | `main` 上的 AI commit | 對應 |
| --- | --- | --- |
| yichieh-chen（commit 作者名 `EJChen`） | 52 / 68 | 沒有逐一比對；抽查 S03、S06、#33 與各次 review 都有對應列 |
| anitaaa17 | 8 / 11 | 都對應到第 1～5 筆（S01 實作、code review、完整度時序修正與 ai-log 本身） |
| eden2289 | 32 / 32 | 都對應到第 1～21 筆 |

- 沒有 AI footer 的 commit 是 merge commit 與手動操作（例如 `Merge pull request`），不需要記。
- 筆數差距大（39／5／21）主要是工作量分配，不是漏記：EJ 兼 PO（拆 story、看板、提案流程、review），anitaaa17 的 S05 還沒 merge。

## `API`／`INV` 為什麼都是 0

- **`API`**：沒有 AI 給出 4.7 不存在或過時的 API。最接近的是 yichieh-chen 第 26 筆：`draw_dashed_line` 等繪圖 API 沒收在 repo 的 `docs/engine-reference/`，標了 `unverified`；但 4.7 線上文件查得到，依規範不算 `API`。
- **`INV`**：依 PR #5 定案的標準，「把 VISION 方向具體化」不算 `INV`，各列理由都有寫「AI 具體化 §x」。曾經討論過、最後沒標的候選：
  - eden2289 第 3 筆：brief 與 story 的 ⚠ 機制是否算 `INV`，交給 PO 判定，最後沒標。
  - yichieh-chen 第 18 筆：AI 自己提醒「正式美術在 VISION §6 範圍外」。美術提案 #22～#25 源自 eden 的美術回饋，由 PO 依提案流程判定收成 story 007～009，所以沒標 `INV`。
- 這個結果本身就是可以比較的證據：在「先寫 VISION、再用 `/brainstorm`、`/create-stories` 照 VISION 拆」的流程下，AI 沒有偷加 VISION 以外的機制。

## 拒絕或修正 AI 的例子(報告用,挑 2~3 個)

1. **AI 誤讀 VISION，被人對照原文改正**（eden2289 第 12 筆，部分接受）：評估美術方向時，Claude 起初說 Meshy 不適合，且以為地圖必須俯視；對照 VISION 後發現沒有規定視角，改成側視＋Meshy 預渲染（提案 #25，後來成為 story 008、009）。
2. **AI 的工程建議與專案設定衝突**（eden2289 第 8 筆，部分接受）：Godot 專家 agent 說 `.godot/global_script_class_cache.cfg` 不該 commit；對照 `.gitignore`，這個檔本來就有被追蹤，團隊也一直 commit 它。這條建議不收，其餘 review 建議照收。
3. **AI 產出要看畫面才抓得到的錯**（eden2289 第 21 筆，修正後接受）：S08 初版程式的樓梯被房間底色蓋住，殖民者走樓梯看起來像浮在空中；測試全過，是看截圖才發現。同一筆裡，AI 把預設字型授權寫成 MIT，改成 OFL 1.1。

**其他可選**：
- yichieh-chen 第 26 筆：Godot 自動改寫 `project.godot`，刪了註解與 vulkan 設定，已還原、不採用。
- yichieh-chen 第 33 筆：整合試跑時 AI 以為完整度沒扣血，追查後是 AI 自己的輸出過濾條件寫錯。
