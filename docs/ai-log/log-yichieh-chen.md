# AI 使用紀錄 — yichieh-chen

> 結果:`接受` / `修正後接受` / `部分接受` / `拒絕`　標記:`API` / `INV` / `DUP`(可空白、可並列)

| # | 日期 | 任務 | 問了什麼 | 結果 | 標記 | 理由 | 工時 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 2026-11-10 | #1 團隊流程自動化 | 掃 repo 現況，提出讓組員與新 session 照 Issue #1 流程走的做法 | 接受 | | 採用建議：PROCESS.md 當唯一流程來源、CLAUDE.md 匯入、skill 串接 GitHub Issues、CI 檢查；不另寫 CONTRIBUTING.md | 0.5h |
| 2 | 2026-11-10 | #1 團隊流程自動化 | 實作看板、認領、完成檢查、守門 hook、四個 skill 與 process-check（PR #4） | 修正後接受 | | 要求加上：session 要看得到專案狀態與自己手上的卡、不照流程時要擋下；settings.json 由 AI 修改前需人同意 | 1h |
| 3 | 2026-11-10 | #1 團隊流程自動化 | 補上 settings.json 的 hook 註冊 | 修正後接受 | | 同意由 AI 修改權限設定，但要求加越權測試：權限被放寬或腳本做了 allowlist 外的事時 CI 不能通過 | 0.5h |
| 4 | 2026-11-10 | #1 MVP 初版 | 用 CCGS `/brainstorm` 依 VISION 提 3 個概念（A 房間圖、B 值班面板、C 簡化 A），填一頁 brief（`design/game-brief.md`） | 修正後接受 |  | 選 C，但要求 C 預先建立插槽（移動集中處理），之後可擴充成 A。6 房間、疲勞、建造點、自動修復、每日加量與保底為 AI 具體化 §3、§4.3、§6，不標 INV | 0.5h |
| 5 | 2026-11-10 | #1 拆 story | 用 CCGS `/create-stories` 把 brief 的 5 項 MVP 拆成 5 張 story 與驗收條件（`production/epics/orbit-shift/`） | 接受 |  | 驗收條件的細節（同優先序挑最近、疲勞離開時釋放任務等）為 AI 具體化 §3.1～§3.3、§7，不標 INV | 0.5h |
| 6 | 2026-11-11 | #1 整合約定 | 請 AI 補主場景與共用訊號，讓各 story 能平行開工又接得起來（`EPIC.md`「整合約定」與 5 張 story 的驗收） | 接受 |  | 多人開發有一個可以共同測試的主場景，整合會比較快；屬實作架構，不新增需求 | 0.25h |
| 9 | 2026-11-11 | #1 開工順序 | review 還沒過，問能否先跑 `/publish-stories` 開暫訂 issue 與看板，有問題再拒絕 PR、修看板；並請 AI 評估目前是否符合 Agile、要不要先做架構設計 | 接受 |  | AI 兩次反對先開 issue：凌晨沒人會認領省不到時間、review 改了 story 會跟 issue 不同步（違反 docs/ 唯一來源）、跳過 review 關卡。改採 AI 建議：先做 001 的整合骨架，PR #5 merge 後緊接著 merge，002、004 就能對著訊號開工。Agile 評估（前期偏重、試玩回饋太晚、review 成為瓶頸）留到 Retro 討論 | 1h |
| 10 | 2026-11-11 | #1 001 整合骨架 | 請 AI 建 `Events` autoload（8 個共用訊號）、`src/main.tscn` 預留 8 個系統節點、`EPIC.md` 資料夾慣例與測試；初版未走 `/dev-story` 與 engine specialist，再請 AI 用 engine-programmer 重做、godot-gdscript-specialist 檢查（加 `main.gd` 注入、`CrisisKind` 常數、消除 4.7.2 unused_signal 警告） | 接受 |  | 註：重做時從上層資料夾啟動，CCGS agent 類型與 hook 未自動載入，specialist 由一般 agent 讀定義檔扮演，hook 改為手動執行；之後在雲端用原生 engine-programmer 與 godot-gdscript-specialist 重新審查 | 1.5h |
| 11 | 2026-11-11 | #1 骨架說明 | 請 AI 畫骨架說明圖（`src` 分類、Events 用途）並把細節寫成說明文件（節點、訊號表、注入、CrisisKind、測試） | 修正後接受 |  | 初版圖放了測試與 story 編號，組員看不懂；要求測試與細節移到文件，圖只講 `src` 分類與 Events 用途，標籤改用功能名稱 | 0.5h |
| 12 | 2026-11-11 | #1 PR #8 base | 問 PR #8 要不要改 base 到 PR #5 的 branch，等 #5 merge 後自動回 `main` | 接受 |  | 維持 `main`：改 base 會讓 CI 與 process-check 不跑、repo 沒開自動刪 branch 所以不會自動改回；#5 merge 後 diff 自然只剩骨架。改在 PR 說明加只看骨架的比較連結 | 0.5h |
